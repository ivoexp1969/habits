import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../progress_repository.dart';
import '../progress_service.dart' show ProgressMap;
import 'account_linker.dart';
import 'auth_backend.dart';
import 'cloud_migration.dart';
import 'cloud_progress_repository.dart';
import 'cloud_sync_config.dart';
import 'month_listener.dart';

/// data-model-v2 ЕТАП 2 — orchestrates cloud sync, entirely off the startup
/// critical path. [start] is fired AFTER the first frame (from
/// RootNavigation._initBackgroundServices), so the UI always paints from the
/// local cache first and never blocks on Firestore.
///
/// Flow when [CloudSyncV2.enabled]:
///   1. ensure an (anonymous) identity;
///   2. turn on Firestore offline persistence;
///   3. run the idempotent cloud migration (local map → month docs), unless the
///      cloud already has it (second device → adopt cloud, drop local);
///   4. start the month listeners and expose a [CloudProgressRepository].
/// When disabled, or before sign-in / while offline, [activeRepository] stays the
/// passed-in local repo and writes buffer there until a later upload.
class SyncController {
  SyncController._();
  static final SyncController instance = SyncController._();

  ProgressRepository? _cloudRepo;
  MonthListener? _listener;
  bool _started = false;

  /// Which repository the app should read/write right now.
  ProgressRepository activeRepository(ProgressRepository local) =>
      _cloudRepo ?? local;

  /// Pure selection rule (testable): cloud only when the flag is on AND signed
  /// in; otherwise local (which also buffers first-run offline writes).
  static ProgressRepository select({
    required bool enabled,
    required bool signedIn,
    required ProgressRepository local,
    ProgressRepository? cloud,
  }) {
    if (enabled && signedIn && cloud != null) return cloud;
    return local;
  }

  /// Idempotent. Safe to call when disabled (returns immediately) — production
  /// is untouched because [CloudSyncV2.enabled] is false.
  Future<void> start({
    required ProgressMap localMap,
    required DateTime now,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) async {
    if (!CloudSyncV2.enabled || _started) return;
    _started = true;
    try {
      final firestore = db ?? FirebaseFirestore.instance;
      firestore.settings =
          const Settings(persistenceEnabled: true); // offline-first

      final backend = FirebaseAuthBackend(auth ?? FirebaseAuth.instance);
      final uid = await backend.ensureSignedIn();
      if (uid == null) return; // offline before first sign-in → buffer locally

      // Finish an interrupted account link (crash between its steps) before
      // anything reads the cloud, so no merge is lost or doubled.
      await AccountLinker(db: firestore, auth: backend).resumePending();

      final migration = CloudMigration(db: firestore, uid: uid);
      if (await migration.isMigrated()) {
        // Second device (or re-install): cloud is the source of truth. Drop the
        // local pre-cloud schema keys so the UI reads the cloud copy.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('progress_map_v2');
        await prefs.remove('progress_schema_version');
      } else {
        await migration.run(localMap, now);
      }

      _listener = MonthListener(db: firestore, uid: uid)..watch(now);
      _cloudRepo = CloudProgressRepository(db: firestore, uid: uid);
    } catch (_) {
      // Any failure → stay on local; a later start/retry picks it up.
      _started = false;
    }
  }

  Stream<ProgressMap>? get liveMap => _listener?.stream;

  /// Re-point the sync after an in-session identity change (link / merge-switch /
  /// sign-out / delete). Clears the local cache so one identity's data cannot
  /// leak into another, then rebinds the repo + listener to the current uid (the
  /// cloud is the source — a linked/merged uid already holds its data; a fresh
  /// anonymous one is empty). No-op when disabled.
  Future<void> rebindAfterAuth({
    DateTime? now,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) async {
    if (!CloudSyncV2.enabled) return;
    final firestore = db ?? FirebaseFirestore.instance;
    final uid = FirebaseAuthBackend(auth ?? FirebaseAuth.instance).currentUid;

    // The migration guard is per-uid in the cloud (meta/schema), so the old
    // identity's LOCAL flags must not bind the new one.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('progress_map_v2');
    await prefs.remove('progress_schema_version');
    await prefs.remove('progress_migrated_at');
    LocalProgressRepository.instance.resetCache();

    await _listener?.dispose();
    _listener = null;
    if (uid == null) {
      _cloudRepo = null;
      return;
    }
    _listener = MonthListener(db: firestore, uid: uid)..watch(now ?? DateTime.now());
    _cloudRepo = CloudProgressRepository(db: firestore, uid: uid);
  }
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/habit.dart';
import 'account_linker.dart';
import '../diag_log.dart';
import '../habit_service.dart' show HabitService, kPrefsPausedDates;
import 'auth_backend.dart';
import 'cloud_progress_repository.dart';

/// Local definitions carried into a merge alongside the progress map.
class MergeExtras {
  MergeExtras({this.habits = const [], this.paused = const {}, this.achievements = const {}});
  final List<Habit> habits;
  final Set<String> paused;
  final Set<String> achievements;
}

/// data-model-v2 ЕТАП 2 — the ONE entry the sign-in UI must use, so every path
/// keeps the anonymous uid (and its data) instead of creating a fresh, empty
/// account. Email register/login, Google and Apple all flow through here.
///
/// Before EVERY identity change it flushes pending writes
/// ([FirebaseFirestore.waitForPendingWrites], with a timeout) so the anon uid's
/// offline check-ins reach the server first. The merge copy is read from the
/// CLOUD repository of the current uid, so it includes writes still pending in
/// the local cache (offline) — not just what the server has, and never the
/// stale LocalProgressRepository (which the cloud path no longer writes to).
class CloudAccountService {
  CloudAccountService({
    required this.auth,
    required this.linker,
    required this.db,
    this.flushTimeout = const Duration(seconds: 3),
    Future<MergeExtras> Function()? localExtras,
  }) : _localExtras = localExtras;

  final AuthBackend auth;
  final AccountLinker linker;
  final FirebaseFirestore db;
  final Duration flushTimeout;
  final Future<MergeExtras> Function()? _localExtras;

  /// The local habit definitions + paused + achievements to carry into a merge
  /// (so a kill right after the switch cannot lose them). Injectable for tests.
  Future<MergeExtras> _extras() async {
    final provider = _localExtras;
    if (provider != null) return provider();
    final prefs = await SharedPreferences.getInstance();
    Set<String> decode(String? s) {
      if (s == null) return <String>{};
      try {
        final v = jsonDecode(s);
        if (v is List) return v.map((e) => e.toString()).toSet();
      } catch (_) {}
      return <String>{};
    }

    return MergeExtras(
      habits: await HabitService.loadHabits(),
      paused: decode(prefs.getString(kPrefsPausedDates)),
      achievements: decode(prefs.getString('achievements')),
    );
  }

  /// Flush buffered writes to the server before an identity change. On timeout
  /// (offline) the writes stay in the local cache — the merge copy below still
  /// reads them from there, so nothing is lost.
  Future<void> _flushPending() async {
    try {
      await db.waitForPendingWrites().timeout(flushTimeout);
    } catch (_) {/* offline / unsupported → cache read below covers it */}
  }

  Future<Map<String, Map<String, int>>> _currentUidMap() async {
    final uid = auth.currentUid;
    if (uid == null) return const {};
    // Reads Firestore's local cache first → includes pending offline writes.
    return CloudProgressRepository(db: db, uid: uid).load();
  }

  /// Register or sign in with [cred]:
  ///   * anonymous + credential free  → LINK (same uid, data kept) → `linked`;
  ///   * anonymous + credential in use → switch to the existing account and
  ///     merge this device's data (crash-safe, idempotent) → `merged`, or
  ///     `switchedEmptyAnon` when the anon had nothing to merge;
  ///   * not anonymous (flag off / already a real account) → plain sign-in.
  Future<CloudAuthResult> linkOrSignIn(AuthCredential cred,
      {bool verifyEmail = false}) async {
    if (auth.isAnonymous) {
      await _flushPending();
      final map = await _currentUidMap(); // incl. pending offline check-ins
      final wasEmpty = map.isEmpty;
      final extras = await _extras();
      final bundle = MergeBundle(
          map: map,
          habits: extras.habits,
          paused: extras.paused,
          achievements: extras.achievements);
      await DiagLog.auth(
          'linkOrSignIn: anon=${auth.currentUid} copy=${map.length} days / '
          '${extras.habits.length} habits${wasEmpty ? ' (EMPTY progress)' : ''}');
      final res = await linker.linkOrMerge(cred, bundle);
      switch (res) {
        case LinkResult.linked:
          if (verifyEmail) await auth.sendEmailVerification();
          return CloudAuthResult.linked;
        case LinkResult.mergedAndSwitched:
          return wasEmpty
              ? CloudAuthResult.switchedEmptyAnon
              : CloudAuthResult.merged;
        case LinkResult.error:
          return CloudAuthResult.error;
      }
    }
    final uid = await auth.signInWith(cred);
    return uid != null ? CloudAuthResult.signedIn : CloudAuthResult.error;
  }

  /// Sign out of a REAL account → a fresh EMPTY anonymous profile; the real
  /// profile keeps its data in the cloud, so signing back in restores it.
  ///
  /// NEVER signs out an ANONYMOUS user: an anonymous account cannot be signed
  /// back into, so signing it out would orphan its data forever (this was the
  /// cause of the lost-check-ins bug). For an anonymous user this is a no-op —
  /// the UI must offer "Вход / Регистрация" (link), not "Изход".
  Future<void> signOutToNewAnon() async {
    if (auth.isAnonymous) {
      await DiagLog.auth('signOut: NO-OP (anon ${auth.currentUid}) — never '
          'orphan an anon');
      return; // guard: an anon has nothing to sign out of
    }
    await DiagLog.auth('signOut: ${auth.currentUid} → new anon');
    await _flushPending();
    await auth.signOut();
    await auth.ensureSignedIn();
  }

  /// Delete the profile: the Firestore subtree FIRST (Firestore does not cascade
  /// to subcollections), then the Auth user, then back to a fresh anonymous one.
  Future<void> deleteProfile() async {
    await DiagLog.auth('deleteProfile: ${auth.currentUid} '
        '(anon=${auth.isAnonymous})');
    await _flushPending();
    final uid = auth.currentUid;
    if (uid != null) await linker.deleteUserData(uid);
    await auth.deleteCurrentUser();
    await auth.ensureSignedIn();
  }
}

enum CloudAuthResult { linked, merged, switchedEmptyAnon, signedIn, error }

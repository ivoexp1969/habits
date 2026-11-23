import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/habit.dart';
import '../habit_service.dart' show dateKeyFromDate;
import '../progress_service.dart' show ProgressMap;
import 'firestore_schema.dart';
import 'habit_cloud_codec.dart';
import 'month_codec.dart';

/// data-model-v2 ЕТАП 2 — one-time push of the local by-date map into Firestore.
///
/// Idempotent and atomic: a single transaction reads `users/{uid}/meta/schema`
/// and, only if it is below version 2, writes every month document and flips the
/// flag LAST. So two devices racing, or a crash mid-run, converge to the same
/// result — whoever sets the flag first wins, the other sees it and becomes a
/// no-op.
///
/// A SECOND device that finds the flag already set must DISCARD its local
/// pre-cloud progress and adopt the cloud as the source of truth (see
/// [isMigrated]; the caller clears the local map + schema keys).
///
/// The source map is chosen by the caller: a fresh local install passes its own
/// `progress_map_v2`; a user who had the OLD cloud blob passes the map derived
/// from it via LegacyHabitData + ProgressMigration.seedMap (same code path as the
/// local migration), so profile users keep their history.
class CloudMigration {
  CloudMigration({required this.db, required this.uid});

  final FirebaseFirestore db;
  final String uid;

  DocumentReference<Map<String, dynamic>> get _metaRef =>
      db.doc(FirestoreSchema.metaSchemaPath(uid));

  /// True when the cloud already holds a v2 schema for this uid.
  Future<bool> isMigrated() async {
    final snap = await _metaRef.get();
    return ((snap.data()?['version'] as num?)?.toInt() ?? 1) >=
        FirestoreSchema.schemaVersion;
  }

  /// Transactionally writes [localMap] into per-month docs and sets the schema
  /// flag, unless the cloud is already migrated. Returns what happened.
  Future<CloudMigrationResult> run(
    ProgressMap localMap,
    DateTime now, {
    List<Habit> habits = const [],
    Set<String> pausedDates = const {},
    Set<String> achievements = const {},
    int xpBaseline = 0,
  }) async {
    return db.runTransaction<CloudMigrationResult>((tx) async {
      final meta = await tx.get(_metaRef);
      final version = (meta.data()?['version'] as num?)?.toInt() ?? 1;
      if (version >= FirestoreSchema.schemaVersion) {
        return CloudMigrationResult.alreadyMigrated;
      }
      // progress (per-month docs)
      final months = MonthCodec.splitByMonth(localMap);
      months.forEach((monthKey, doc) {
        tx.set(db.doc(FirestoreSchema.monthDocPath(uid, monthKey)), doc,
            SetOptions(merge: true));
      });
      // habit definitions (so a new device can render)
      for (var i = 0; i < habits.length; i++) {
        tx.set(db.doc(FirestoreSchema.habitDocPath(uid, habits[i].id)),
            HabitCloudCodec.toDoc(habits[i], order: i, updatedAt: now));
      }
      // user doc: pausedDates / achievements (sets) + xpBaseline
      tx.set(db.doc(FirestoreSchema.userPath(uid)), {
        if (pausedDates.isNotEmpty) 'pausedDates': pausedDates.toList(),
        if (achievements.isNotEmpty) 'achievements': achievements.toList(),
        'xpBaseline': xpBaseline,
      }, SetOptions(merge: true));
      // schema flag LAST
      tx.set(_metaRef, {
        'version': FirestoreSchema.schemaVersion,
        'migratedAt': dateKeyFromDate(now),
      });
      return CloudMigrationResult.migrated;
    });
  }
}

enum CloudMigrationResult { migrated, alreadyMigrated }

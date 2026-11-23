import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/habit.dart';
import 'firestore_schema.dart';
import 'habit_cloud_codec.dart';
import 'misc_cloud_sync.dart';

/// data-model-v2 ЕТАП 2 — syncs the NON-progress collections for a uid:
///   * users/{uid}/habits/{id}  — habit definitions (create/edit/order/soft-delete)
///   * users/{uid}              — pausedDates, achievements, profile, xpBaseline
/// Progress (months/) is handled by CloudProgressRepository + MonthListener.
///
/// Writers push on each local mutation; the watch* streams feed the other
/// devices' changes back into the UI. Last-Writer-Wins is by the per-doc
/// `updatedAt` (habits) / `profileUpdatedAt`; pausedDates and achievements are
/// sets (arrayUnion/arrayRemove) so concurrent additions on two devices both
/// stick.
class CloudDocsSync {
  CloudDocsSync({required this.db, required this.uid})
      : _misc = MiscCloudSync(db: db, uid: uid);

  final FirebaseFirestore db;
  final String uid;
  final MiscCloudSync _misc;

  CollectionReference<Map<String, dynamic>> get _habits =>
      db.collection(FirestoreSchema.habitsPath(uid));

  // ---- habits --------------------------------------------------------------
  /// Writes the whole habit list (incl. soft-deleted tombstones) with a fresh
  /// order (list index) + updatedAt, so the other device converges by LWW.
  Future<void> pushHabits(List<Habit> habits) async {
    final batch = db.batch();
    final now = DateTime.now();
    for (var i = 0; i < habits.length; i++) {
      batch.set(_habits.doc(habits[i].id),
          HabitCloudCodec.toDoc(habits[i], order: i, updatedAt: now));
    }
    await batch.commit();
  }

  /// Live habit list, ordered by `order`. Includes soft-deleted habits (the UI
  /// filters them by deletedAt), so a delete on one device removes them here too.
  Stream<List<Habit>> watchHabits() {
    return _habits.snapshots().map((snap) {
      final rows = snap.docs
          .map((d) => (HabitCloudCodec.fromDoc(d.data()),
              HabitCloudCodec.orderOf(d.data())))
          .toList()
        ..sort((a, b) => a.$2.compareTo(b.$2));
      return rows.map((r) => r.$1).toList();
    });
  }

  // ---- paused / achievements (sets) ---------------------------------------
  Future<void> setPaused(String dayKey, bool paused) =>
      _misc.setPaused(dayKey, paused);

  Future<void> unlockAchievement(String id) => _misc.unlockAchievement(id);

  Future<void> writeProfile(Map<String, dynamic> fields, DateTime updatedAt) =>
      _misc.writeProfile(fields, updatedAt);

  Future<void> setXpBaseline(int xp) => _misc.setXpBaseline(xp);

  /// Live set of paused day-keys from the user doc.
  Stream<Set<String>> watchPaused() => db
      .doc(FirestoreSchema.userPath(uid))
      .snapshots()
      .map((d) => ((d.data()?['pausedDates'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet());

  /// Live set of unlocked achievement ids from the user doc.
  Stream<Set<String>> watchAchievements() => db
      .doc(FirestoreSchema.userPath(uid))
      .snapshots()
      .map((d) => ((d.data()?['achievements'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet());
}

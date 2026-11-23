import 'dart:convert';

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

  // Content (sans updatedAt) of each habit as WE last pushed it. A habit is
  // written only when its content changed, so a save triggered by something else
  // (e.g. a check-in) never re-stamps every habit with a fresh updatedAt and
  // clobbers another device's concurrent edit (that would be habit-level LWW the
  // wrong way round). Empty on a fresh uid → the first push sends everything.
  final Map<String, String> _pushedContent = {};

  CollectionReference<Map<String, dynamic>> get _habits =>
      db.collection(FirestoreSchema.habitsPath(uid));

  // ---- habits --------------------------------------------------------------
  static String _contentOf(Habit h, int order) =>
      jsonEncode({...h.toJson(), 'order': order});

  /// Writes ONLY the habits whose content (fields + order + deletedAt) changed
  /// since this instance last pushed them — with a fresh updatedAt. Soft-deleted
  /// habits ride along as tombstones. Returns the ids actually written.
  Future<Set<String>> pushHabits(List<Habit> habits) async {
    final batch = db.batch();
    final now = DateTime.now();
    final written = <String>{};
    for (var i = 0; i < habits.length; i++) {
      final h = habits[i];
      final content = _contentOf(h, i);
      if (_pushedContent[h.id] == content) continue; // unchanged → don't touch
      batch.set(_habits.doc(h.id),
          HabitCloudCodec.toDoc(h, order: i, updatedAt: now));
      _pushedContent[h.id] = content;
      written.add(h.id);
    }
    if (written.isNotEmpty) await batch.commit();
    return written;
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
      final habits = <Habit>[];
      for (var i = 0; i < rows.length; i++) {
        habits.add(rows[i].$1);
        // Remember the cloud version as "already pushed", so receiving another
        // device's edit doesn't make us re-push (and re-stamp) it.
        _pushedContent[rows[i].$1.id] = _contentOf(rows[i].$1, i);
      }
      return habits;
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

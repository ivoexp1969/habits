import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_schema.dart';

/// data-model-v2 ЕТАП 2 — the small "misc" collections that live on the user
/// document users/{uid}: paused days, unlocked achievements, profile/settings
/// (LWW), and the XP baseline. Progress + habit defs live elsewhere (months/,
/// habits/).
///
/// * pausedDates / achievements are SETS → arrayUnion / arrayRemove, so two
///   devices adding different entries both stick (order-independent, no
///   last-writer-wins loss).
/// * profile / settings are scalar fields → Last-Writer-Wins by updatedAt.
/// * XP = xpBaseline (snapshot stored here) + what the by-date map earns since
///   (computed by the caller with XpService, see Фаза D).
class MiscCloudSync {
  MiscCloudSync({required this.db, required this.uid});

  final FirebaseFirestore db;
  final String uid;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      db.doc(FirestoreSchema.userPath(uid));

  Future<void> setPaused(String dayKey, bool paused) {
    return _userDoc.set({
      'pausedDates':
          paused ? FieldValue.arrayUnion([dayKey]) : FieldValue.arrayRemove([dayKey])
    }, SetOptions(merge: true));
  }

  Future<void> unlockAchievement(String id) {
    return _userDoc.set({
      'achievements': FieldValue.arrayUnion([id])
    }, SetOptions(merge: true));
  }

  /// Writes profile/settings fields with a fresh LWW timestamp. The reader uses
  /// [lwwRemoteWins] to decide whether an incoming snapshot replaces local.
  Future<void> writeProfile(Map<String, dynamic> fields, DateTime updatedAt) {
    return _userDoc.set({
      ...fields,
      'profileUpdatedAt': updatedAt.toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> setXpBaseline(int xpBaseline) {
    return _userDoc.set({'xpBaseline': xpBaseline}, SetOptions(merge: true));
  }

  /// Total XP = stored baseline + XP earned from the map since migration.
  static int xpTotal(int xpBaseline, int earnedFromMap) =>
      xpBaseline + earnedFromMap;

  /// LWW for the profile block: true when the remote snapshot is newer.
  static bool lwwRemoteWins(
      Map<String, dynamic> local, Map<String, dynamic> remote) {
    final lu = _ts(local['profileUpdatedAt']);
    final ru = _ts(remote['profileUpdatedAt']);
    if (ru == null) return false;
    if (lu == null) return true;
    return ru.isAfter(lu);
  }

  static DateTime? _ts(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}

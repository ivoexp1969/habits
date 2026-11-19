import '../../models/habit.dart';

/// data-model-v2 ЕТАП 2 — a habit definition document
/// (users/{uid}/habits/{id}). The definition is the existing Habit JSON plus:
///   order     — explicit list position (local list index is not synced)
///   updatedAt — ISO timestamp for Last-Writer-Wins conflict resolution
///   deletedAt — already on Habit (soft delete); a deleted habit syncs as a
///               tombstone so other devices hide it too.
class HabitCloudCodec {
  static Map<String, dynamic> toDoc(Habit h,
      {required int order, required DateTime updatedAt}) {
    return {
      ...h.toJson(),
      'order': order,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static Habit fromDoc(Map<String, dynamic> doc) => Habit.fromJson(doc);

  static int orderOf(Map<String, dynamic> doc) =>
      (doc['order'] as num?)?.toInt() ?? 0;

  static DateTime? updatedAtOf(Map<String, dynamic> doc) =>
      doc['updatedAt'] is String ? DateTime.tryParse(doc['updatedAt'] as String) : null;

  /// Last-Writer-Wins: true when [remote] should overwrite [local]. A document
  /// with no timestamp loses to one that has it; equal timestamps keep local
  /// (no needless write).
  static bool remoteWins(
      Map<String, dynamic> local, Map<String, dynamic> remote) {
    final lu = updatedAtOf(local);
    final ru = updatedAtOf(remote);
    if (ru == null) return false;
    if (lu == null) return true;
    return ru.isAfter(lu);
  }
}

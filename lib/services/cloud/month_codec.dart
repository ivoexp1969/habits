import 'firestore_schema.dart';

/// Pure conversion between a month document `{ "dd": { habitId: count } }` and
/// a slice of the by-date ProgressMap `{ "yyyy-MM-dd": { habitId: count } }`.
/// No Firestore types — the repository wraps these with FieldValue writes.
class MonthCodec {
  /// Month document → ProgressMap slice (full "yyyy-MM-dd" keys so it merges
  /// straight into the in-memory map). Drops 0 / malformed entries.
  static Map<String, Map<String, int>> decode(
      String monthKey, Map<String, dynamic> doc) {
    final out = <String, Map<String, int>>{};
    doc.forEach((ddField, v) {
      if (v is! Map) return;
      if (ddField.length != 2 || int.tryParse(ddField) == null) return; // skip non-day fields
      final inner = <String, int>{};
      Map<String, dynamic>.from(v).forEach((id, c) {
        final n = c is num ? c.toInt() : 0;
        if (n > 0) inner[id] = n;
      });
      if (inner.isNotEmpty) {
        out[FirestoreSchema.dayKeyOf(monthKey, ddField)] = inner;
      }
    });
    return out;
  }

  /// A ProgressMap slice (any "yyyy-MM-dd" keys) → one month's document shape,
  /// keeping ONLY the days that fall in [monthKey]. Used by the migration's
  /// transactional set and by full re-writes.
  static Map<String, dynamic> encode(
      String monthKey, Map<String, Map<String, int>> slice) {
    final doc = <String, dynamic>{};
    slice.forEach((dayKey, counts) {
      if (FirestoreSchema.monthKeyForDayKey(dayKey) != monthKey) return;
      final dd = dayKey.substring(8); // 'yyyy-MM-dd' → 'dd'
      final inner = <String, int>{};
      counts.forEach((id, c) {
        if (c > 0) inner[id] = c;
      });
      if (inner.isNotEmpty) doc[dd] = inner;
    });
    return doc;
  }

  /// Splits a whole ProgressMap into per-month document shapes
  /// ({ "yyyy-MM": { "dd": { id: count } } }) for the migration writer.
  static Map<String, Map<String, dynamic>> splitByMonth(
      Map<String, Map<String, int>> map) {
    final months = <String, Map<String, dynamic>>{};
    for (final dayKey in map.keys) {
      final mk = FirestoreSchema.monthKeyForDayKey(dayKey);
      months.putIfAbsent(mk, () => <String, dynamic>{});
    }
    for (final mk in months.keys) {
      months[mk] = encode(mk, map);
    }
    return months;
  }
}

/// data-model-v2 ЕТАП 2 — Firestore layout (pure helpers, no Firestore import so
/// they unit-test without a backend).
///
/// Progress is stored one document PER MONTH to keep writes small and reads
/// bounded:
///   users/{uid}/months/{yyyy-MM}   →  { "dd": { habitId: count } }
/// A check-in is a single `FieldValue.increment(±1)` on `dd.habitId`. The app
/// listens to the current month + the adjacent one (so a day-rollover across a
/// month boundary, and the "yesterday" widget read, both stay covered).
///
/// Other collections:
///   users/{uid}/habits/{id}        →  habit definition (LWW per doc)
///   users/{uid}/meta/schema        →  { version: 2 }  (migration guard)
///   users/{uid}                    →  profile / settings / xpBaseline (LWW)
class FirestoreSchema {
  static const int schemaVersion = 2;

  // ---- collection / document paths ----------------------------------------
  static String userPath(String uid) => 'users/$uid';
  static String monthsPath(String uid) => 'users/$uid/months';
  static String monthDocPath(String uid, String monthKey) =>
      'users/$uid/months/$monthKey';
  static String habitsPath(String uid) => 'users/$uid/habits';
  static String habitDocPath(String uid, String id) => 'users/$uid/habits/$id';
  static String metaSchemaPath(String uid) => 'users/$uid/meta/schema';

  // ---- key helpers ---------------------------------------------------------
  /// "yyyy-MM" for [d].
  static String monthKeyOf(DateTime d) =>
      '${_p4(d.year)}-${_p2(d.month)}';

  /// The "dd" field name for [d] inside its month document.
  static String dayFieldOf(DateTime d) => _p2(d.day);

  /// "yyyy-MM" that the "yyyy-MM-dd" [dayKey] belongs to.
  static String monthKeyForDayKey(String dayKey) {
    // 'yyyy-MM-dd' → 'yyyy-MM' (cheap substring; validated by format elsewhere).
    return dayKey.length >= 7 ? dayKey.substring(0, 7) : dayKey;
  }

  /// The full "yyyy-MM-dd" for a [monthKey] ("yyyy-MM") + a "dd" field.
  static String dayKeyOf(String monthKey, String ddField) =>
      '$monthKey-$ddField';

  /// The month key [offset] months away from [monthKey] (−1 = previous).
  static String adjacentMonthKey(String monthKey, int offset) {
    final parts = monthKey.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final shifted = DateTime(y, m + offset, 1);
    return monthKeyOf(shifted);
  }

  /// The month a check-in's Firestore field path targets: 'dd.habitId'.
  static String fieldPath(DateTime day, String habitId) =>
      '${dayFieldOf(day)}.$habitId';

  static String _p2(int n) => n.toString().padLeft(2, '0');
  static String _p4(int n) => n.toString().padLeft(4, '0');
}

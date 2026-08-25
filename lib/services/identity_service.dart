import '../models/habit.dart';

/// "Atomic Habits" identity helpers.
///
/// An identity (e.g. "здрав човек") groups habits that are all votes for the
/// same kind of person. Grouping is done on a NORMALIZED form so that
/// "Здрав човек", "здрав човек" and "  ЗДРАВ ЧОВЕК " all count together.
///
/// Votes are computed LIVE (never stored) from each habit's lifetime
/// [Habit.totalCompletions]. The global `history` map holds only per-day
/// aggregate progress, so it cannot attribute check-ins to a habit/identity —
/// hence the per-habit counter.

/// Canonical key for grouping identities: trim + lowercase.
String normalizeIdentity(String raw) => raw.trim().toLowerCase();

/// Total votes cast for [identity]: the sum of lifetime completions of every
/// habit whose identity matches after normalization. Returns 0 for a blank
/// identity or when nothing matches.
int votesForIdentity(String identity, List<Habit> habits) {
  final key = normalizeIdentity(identity);
  if (key.isEmpty) return 0;
  var total = 0;
  for (final h in habits) {
    final id = h.identity;
    if (id != null && normalizeIdentity(id) == key) {
      total += h.totalCompletions;
    }
  }
  return total;
}

/// The distinct identities present across [habits], deduplicated by normalized
/// form and preserving the first-seen original (trimmed) spelling. Used to
/// suggest identity chips in the create/edit form.
List<String> distinctIdentities(List<Habit> habits) {
  final seen = <String>{};
  final out = <String>[];
  for (final h in habits) {
    final id = h.identity;
    if (id == null) continue;
    final trimmed = id.trim();
    if (trimmed.isEmpty) continue;
    if (seen.add(normalizeIdentity(trimmed))) out.add(trimmed);
  }
  return out;
}

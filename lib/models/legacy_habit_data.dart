/// The OLD per-habit fields (completedTimes / periodKey / parkedPeriodKey /
/// streak / lastCompletedDate / goalCount / goalPeriodKey), parsed straight from
/// a stored habit's JSON. data-model-v2 drops these from [Habit] and all logic;
/// ONLY the migration reads them — both the one-time local migration and the
/// import of an old backup (which must go through the same migration, never be
/// skipped). ЕТАП 2's cloud migration parses the old blob the same way.
class LegacyHabitData {
  const LegacyHabitData({
    required this.id,
    required this.frequencyUnit,
    required this.timesPerDay,
    required this.completedTimes,
    required this.periodKey,
    required this.streak,
    required this.lastCompletedDate,
    required this.goalCount,
    required this.goalPeriodKey,
  });

  final String id;
  final String frequencyUnit;
  final int timesPerDay;
  final int completedTimes;
  final String? periodKey;
  final int streak;
  final String? lastCompletedDate;
  final int goalCount;
  final String? goalPeriodKey;

  factory LegacyHabitData.fromJson(Map<String, dynamic> j) => LegacyHabitData(
        id: j['id'] as String? ?? '',
        frequencyUnit: j['frequencyUnit'] as String? ?? 'day',
        timesPerDay: (j['timesPerDay'] as num?)?.toInt() ?? 1,
        completedTimes: (j['completedTimes'] as num?)?.toInt() ?? 0,
        periodKey: j['periodKey'] as String?,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        lastCompletedDate: j['lastCompletedDate'] as String?,
        goalCount: (j['goalCount'] as num?)?.toInt() ?? 0,
        goalPeriodKey: j['goalPeriodKey'] as String?,
      );
}

import 'package:flutter/material.dart';

class Habit {
  Habit({
    String? id,
    required this.name,
    required this.timesPerDay,
    this.frequencyUnit = 'day',
    this.periodKey,
    this.completedTimes = 0,
    this.color,
    this.icon,
    this.category,
    this.streak = 0,
    this.bestStreak = 0,
    this.lastCompletedDate,
    String? identity,
    this.totalCompletions = 0,
    String? miniVersion,
    this.afterHabitId,
    String? rewardAfter,
    String? location,
    this.intentionMinutes,
    this.goalTarget,
    String? goalPeriod,
    this.goalCount = 0,
    this.goalPeriodKey,
    this.goalRaiseDismissedFor,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        identity = _cleanText(identity),
        miniVersion = _cleanText(miniVersion),
        rewardAfter = _cleanText(rewardAfter),
        location = _cleanText(location),
        goalPeriod = _cleanGoalPeriod(goalPeriod),
        createdAt = createdAt ?? DateTime.now();

  String id;
  String name;
  // Target count of check-ins per [frequencyUnit] period (kept the JSON key
  // 'timesPerDay' for backward compatibility even though it now means
  // "per period"). Old records are daily.
  int timesPerDay;
  // How often the target repeats: 'day' | 'week' | 'month'. Old records default
  // to 'day' so nothing changes for them. Weekly/monthly counters accumulate
  // over the period and only reset when the period rolls over (see periodKey).
  String frequencyUnit;
  // Key of the period the current [completedTimes] belongs to
  // (see periodKeyFor). When a new day reveals a new period the counter is
  // zeroed and this is updated. null on old records → treated as "reset due".
  String? periodKey;
  int completedTimes;
  final Color? color;
  final IconData? icon;
  String? category;
  int streak;
  int bestStreak;
  // Date (yyyy-MM-dd) the habit was last fully completed — used to maintain
  // [streak] across days.
  String? lastCompletedDate;
  // "Atomic Habits" identity this habit is a vote for, e.g. "здрав човек".
  // Stored trimmed; empty/blank is normalized to null. Optional — old records
  // and habits without an identity keep working exactly as before.
  String? identity;
  // Lifetime count of check-ins (increments), never reset on a new day. Used
  // to tally identity "votes" live. `completedTimes` resets daily and cannot
  // provide this, and the global `history` map holds no per-habit data.
  int totalCompletions;
  // "2-minute rule" mini version, e.g. "обувам маратонките". Doing the mini
  // version counts as a normal check-in so the streak survives a hard day.
  // Stored trimmed; blank → null. Optional.
  String? miniVersion;
  // Habit stacking: id (not name) of the anchor habit this one follows. A
  // dangling id (anchor deleted) is treated as "no anchor" at read time — never
  // written back, so nothing breaks. Optional.
  String? afterHabitId;
  // "Atomic Habits" temptation bundling: a small reward the user lets themselves
  // enjoy right after doing the habit, e.g. "епизод от сериала". On a counted
  // check-in it surfaces as brief "Заслужи си: …" feedback. Stored trimmed;
  // blank → null. Optional.
  String? rewardAfter;
  // "Atomic Habits" implementation intention: where the habit will be done, e.g.
  // "в кухнята". Stored trimmed; blank → null. Optional.
  String? location;
  // Implementation intention time as minutes since midnight (0..1439). When set,
  // a daily local notification "[habit] — [location]" is scheduled at this time
  // (see NotificationService.scheduleIntentionReminder). null = no scheduled
  // reminder. Optional.
  int? intentionMinutes;
  // "Atomic Habits" quantitative goal: a target number of check-ins for a
  // period, e.g. 24 (books) per 'year'. Optional and independent of the
  // qualitative identity vote. null = no goal → the habit behaves exactly as
  // before. Only meaningful together (a target with no period defaults to
  // 'year' at write time).
  int? goalTarget;
  // Goal period: 'year' | 'month' | 'ongoing'. 'ongoing' is a lifetime target
  // (progress comes from totalCompletions); 'year'/'month' reset with the
  // calendar and count via goalCount below. null on records without a goal.
  String? goalPeriod;
  // Check-ins accumulated toward a 'year'/'month' goal in the CURRENT period.
  // Mirrors the completedTimes/periodKey mechanism: it belongs to goalPeriodKey
  // and is treated as 0 once the period rolls over. Unused for 'ongoing'
  // (which reads totalCompletions) and for habits without a goal.
  int goalCount;
  // Calendar-period key goalCount belongs to ('YYYY' for year, 'YYYY-MM' for
  // month). null = no counted period yet → next check-in starts a fresh count.
  String? goalPeriodKey;
  // The goalTarget value for which the user last dismissed the "raise your
  // goal" hint. Tied to the VALUE (not a bool) so the hint self-re-arms: raise
  // the goal and, once you exceed the NEW target, it shows again once. null =
  // never dismissed. See showGoalRaiseHint below.
  int? goalRaiseDismissedFor;
  DateTime createdAt;

  // Trims a value and collapses blank strings to null so the stored value is
  // always either meaningful or absent.
  static String? _cleanText(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }

  // Accepts only the three known goal periods; anything else (incl. old/garbage
  // values) collapses to null so a goal is never in an unknown state.
  static String? _cleanGoalPeriod(String? raw) {
    if (raw == 'year' || raw == 'month' || raw == 'ongoing') return raw;
    return null;
  }

  bool get isCompleted => completedTimes >= timesPerDay;

  // A quantitative goal is active only with a positive target.
  bool get hasGoal => goalTarget != null && goalTarget! > 0;

  // Calendar-period key for [now] under this habit's goalPeriod: 'YYYY' for a
  // yearly goal, 'YYYY-MM' for a monthly one. null for 'ongoing' or no goal —
  // those don't reset by calendar.
  String? goalKeyFor(DateTime now) {
    switch (goalPeriod) {
      case 'year':
        return now.year.toString().padLeft(4, '0');
      case 'month':
        return '${now.year.toString().padLeft(4, '0')}'
            '-${now.month.toString().padLeft(2, '0')}';
      default:
        return null;
    }
  }

  // Check-ins counting toward the goal in the current period at [now].
  // 'ongoing' -> lifetime totalCompletions (retroactively accurate). 'year'/
  // 'month' -> goalCount, but only if it belongs to the current period (else
  // the period rolled over -> 0). No goal -> 0.
  int goalCurrentCount(DateTime now) {
    if (!hasGoal) return 0;
    if (goalPeriod == 'ongoing') return totalCompletions;
    return goalPeriodKey == goalKeyFor(now) ? goalCount : 0;
  }

  // Goal progress in 0..1 at [now], or null when there is no goal.
  double? goalProgress(DateTime now) {
    if (!hasGoal) return null;
    return (goalCurrentCount(now) / goalTarget!).clamp(0.0, 1.0);
  }

  // The goal target is met (count has reached or passed it). The card then
  // reads as "target / target ✓ — goal reached"; check-ins are NOT blocked.
  bool goalReached(DateTime now) =>
      hasGoal && goalCurrentCount(now) >= goalTarget!;

  // The goal target is strictly exceeded (over-achievement) — the only case
  // the "raise your goal?" hint considers.
  bool goalExceeded(DateTime now) =>
      hasGoal && goalCurrentCount(now) > goalTarget!;

  // Whether to show the one-time "you passed your goal — raise it?" hint: the
  // goal is exceeded AND the user hasn't already dismissed the hint for THIS
  // target value. Dismiss persists via goalRaiseDismissedFor, so it never
  // re-appears on app re-open for the same target.
  bool showGoalRaiseHint(DateTime now) =>
      goalExceeded(now) && goalRaiseDismissedFor != goalTarget;

  // Records one check-in toward a 'year'/'month' goal, rolling the counter to
  // the current period first (a stale count from a past period resets to 0).
  // No-op for 'ongoing' (derives from totalCompletions) and for habits without
  // such a goal.
  void bumpGoalCount([DateTime? at]) {
    if (goalPeriod != 'year' && goalPeriod != 'month') return;
    final key = goalKeyFor(at ?? DateTime.now());
    if (goalPeriodKey != key) {
      goalPeriodKey = key;
      goalCount = 0;
    }
    goalCount++;
  }

  // Reverses bumpGoalCount for an undo — only when the stored count belongs to
  // the current period; a rolled-over period has nothing to undo.
  void unbumpGoalCount([DateTime? at]) {
    if (goalPeriod != 'year' && goalPeriod != 'month') return;
    if (goalPeriodKey == goalKeyFor(at ?? DateTime.now()) && goalCount > 0) {
      goalCount--;
    }
  }

  double get progress {
    if (timesPerDay <= 0) return 0;
    return (completedTimes / timesPerDay).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'timesPerDay': timesPerDay,
        'frequencyUnit': frequencyUnit,
        'periodKey': periodKey,
        'completedTimes': completedTimes,
        'color': color?.value,
        'icon': icon?.codePoint,
        'category': category,
        'streak': streak,
        'bestStreak': bestStreak,
        'lastCompletedDate': lastCompletedDate,
        'identity': identity,
        'totalCompletions': totalCompletions,
        'miniVersion': miniVersion,
        'afterHabitId': afterHabitId,
        'rewardAfter': rewardAfter,
        'location': location,
        'intentionMinutes': intentionMinutes,
        'goalTarget': goalTarget,
        'goalPeriod': goalPeriod,
        'goalCount': goalCount,
        'goalPeriodKey': goalPeriodKey,
        'goalRaiseDismissedFor': goalRaiseDismissedFor,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Habit.fromJson(Map<String, dynamic> json) {
    final colorValue = json['color'];
    final iconCode = json['icon'];
    return Habit(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      timesPerDay: (json['timesPerDay'] as num?)?.toInt() ?? 1,
      // Old records predate frequency → daily; periodKey null → reset due.
      frequencyUnit: json['frequencyUnit'] as String? ?? 'day',
      periodKey: json['periodKey'] as String?,
      completedTimes: (json['completedTimes'] as num?)?.toInt() ?? 0,
      color: colorValue is int ? Color(colorValue) : null,
      icon: iconCode is int
          ? IconData(iconCode, fontFamily: 'MaterialIcons')
          : null,
      category: json['category'] as String?,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
      lastCompletedDate: json['lastCompletedDate'] as String?,
      // Old records predate these keys → default null / 0 (backward compatible).
      identity: json['identity'] as String?,
      totalCompletions: (json['totalCompletions'] as num?)?.toInt() ?? 0,
      miniVersion: json['miniVersion'] as String?,
      afterHabitId: json['afterHabitId'] as String?,
      rewardAfter: json['rewardAfter'] as String?,
      location: json['location'] as String?,
      intentionMinutes: (json['intentionMinutes'] as num?)?.toInt(),
      // Old records predate the goal keys → null / 0 (backward compatible).
      goalTarget: (json['goalTarget'] as num?)?.toInt(),
      goalPeriod: json['goalPeriod'] as String?,
      goalCount: (json['goalCount'] as num?)?.toInt() ?? 0,
      goalPeriodKey: json['goalPeriodKey'] as String?,
      goalRaiseDismissedFor:
          (json['goalRaiseDismissedFor'] as num?)?.toInt(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

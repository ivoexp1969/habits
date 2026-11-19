import 'package:flutter/material.dart';

class Habit {
  Habit({
    String? id,
    required this.name,
    required this.timesPerDay,
    this.frequencyUnit = 'day',
    this.color,
    this.icon,
    this.category,
    this.bestStreak = 0,
    String? identity,
    this.totalCompletions = 0,
    String? miniVersion,
    this.afterHabitId,
    String? rewardAfter,
    String? location,
    this.intentionMinutes,
    this.goalTarget,
    String? goalPeriod,
    this.goalRaiseDismissedFor,
    DateTime? createdAt,
    this.deletedAt,
    this.streakBaseline,
    this.baselineDate,
    this.goalBaseline,
    this.goalBaselineKey,
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
  // Editable from the add/edit sheet (icon + colour picker). Non-final so an
  // edit mutates them in place and the list redraws immediately; toJson/
  // fromJson are unchanged.
  Color? color;
  IconData? icon;
  String? category;
  // data-model-v2: the live streak is DERIVED from the by-date progress map
  // (ProgressService.habitStreak), not stored here. bestStreak is kept as a
  // high-water mark that the map's best-run extends.
  int bestStreak;
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
  // calendar and count via the by-date map (ProgressService.goalCount +
  // goalBaseline/goalBaselineKey). null on records without a goal.
  String? goalPeriod;
  // The goalTarget value for which the user last dismissed the "raise your
  // goal" hint. Tied to the VALUE (not a bool) so the hint self-re-arms: raise
  // the goal and, once you exceed the NEW target, it shows again once. null =
  // never dismissed.
  int? goalRaiseDismissedFor;
  DateTime createdAt;
  // Soft-delete timestamp (data-model-v2). When set, the habit is hidden from
  // the UI but kept so a PAST day's percentage still counts only the habits that
  // were active on that date (createdAt <= date < deletedAt). null = live.
  DateTime? deletedAt;
  // data-model-v2 migration baselines. The by-date map has no per-habit history
  // from BEFORE the migration (the old app kept only a global day-% archive), so
  // the pre-migration streak / goal count is carried here and extended by the
  // map afterwards. null on records that predate the migration.
  //   streakBaseline — the per-habit streak at migration (its baselineDate day);
  //   baselineDate   — "yyyy-MM-dd" the baseline streak ended on (= old
  //                    lastCompletedDate); the chain continues from here;
  //   goalBaseline   — goalCount at migration IF it belonged to the current goal
  //                    period, else 0 (a new period starts the goal from 0).
  int? streakBaseline;
  String? baselineDate;
  int? goalBaseline;
  String? goalBaselineKey; // the goal period the goalBaseline belongs to

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

  // Whether any "Atomic Habits" field is set. The Circles view marks such a
  // habit with a glowing spark; these are exactly the atomic fields surfaced as
  // extra lines on the standard card (identity / stacking / 2-minute rule /
  // implementation intention / temptation-bundling reward).
  bool get isAtomic =>
      identity != null ||
      afterHabitId != null ||
      miniVersion != null ||
      intentionMinutes != null ||
      rewardAfter != null;

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'timesPerDay': timesPerDay,
        'frequencyUnit': frequencyUnit,
        'color': color?.value,
        'icon': icon?.codePoint,
        'category': category,
        'bestStreak': bestStreak,
        'identity': identity,
        'totalCompletions': totalCompletions,
        'miniVersion': miniVersion,
        'afterHabitId': afterHabitId,
        'rewardAfter': rewardAfter,
        'location': location,
        'intentionMinutes': intentionMinutes,
        'goalTarget': goalTarget,
        'goalPeriod': goalPeriod,
        'goalRaiseDismissedFor': goalRaiseDismissedFor,
        'createdAt': createdAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'streakBaseline': streakBaseline,
        'baselineDate': baselineDate,
        'goalBaseline': goalBaseline,
        'goalBaselineKey': goalBaselineKey,
      };

  factory Habit.fromJson(Map<String, dynamic> json) {
    final colorValue = json['color'];
    final iconCode = json['icon'];
    return Habit(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      timesPerDay: (json['timesPerDay'] as num?)?.toInt() ?? 1,
      // Old records predate frequency → daily.
      frequencyUnit: json['frequencyUnit'] as String? ?? 'day',
      color: colorValue is int ? Color(colorValue) : null,
      icon: iconCode is int
          ? IconData(iconCode, fontFamily: 'MaterialIcons')
          : null,
      category: json['category'] as String?,
      bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
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
      goalRaiseDismissedFor:
          (json['goalRaiseDismissedFor'] as num?)?.toInt(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      // Old records predate soft-delete → null (live, backward compatible).
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : null,
      // Old records predate the data-model-v2 baselines → null.
      streakBaseline: (json['streakBaseline'] as num?)?.toInt(),
      baselineDate: json['baselineDate'] as String?,
      goalBaseline: (json['goalBaseline'] as num?)?.toInt(),
      goalBaselineKey: json['goalBaselineKey'] as String?,
    );
  }
}

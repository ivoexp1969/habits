import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/achievements.dart';
import '../l10n/app_localizations.dart';
import '../services/habit_service.dart';
import '../services/streak_service.dart';
import '../services/theme_service.dart';
import '../services/xp_service.dart';
import '../widgets/music_toggle_button.dart';
import '../widgets/yearly_heatmap.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  /// Reloads stats from storage. Called when this tab becomes visible so it
  /// reflects habits completed since it was last built (IndexedStack keeps
  /// the State alive, so initState does not re-run on tab switch).
  void reload() => _loadStats();

  List<int> _last7Days = List.filled(7, 0);
  Map<String, double> _history = {};
  double _overallSuccess = 0;
  int _longestStreak = 0;
  int _currentStreak = 0;
  int _activeHabits = 0;
  int _xp = 0;
  Set<String> _unlocked = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final successMap = await HabitService.loadHistory();

    final habitsStr = prefs.getString(kPrefsHabits);
    int activeHabits = 0;
    if (habitsStr != null) {
      try {
        final list = await HabitService.loadHabits();
        activeHabits = list.length;
      } catch (_) {}
    }

    final xp = await XpService.getXP();
    final unlocked = await AchievementService.getUnlocked();

    // Streak freeze: one missed day is forgiven unless the user turned it off.
    bool graceEnabled = true;
    final profileStr = prefs.getString(kPrefsProfile);
    if (profileStr != null) {
      try {
        final p = jsonDecode(profileStr) as Map<String, dynamic>;
        graceEnabled = p['streakGraceEnabled'] as bool? ?? true;
      } catch (_) {}
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final last7 = List<int>.filled(7, 0);
    for (int i = 0; i < 7; i++) {
      final day = todayDate.subtract(Duration(days: 6 - i));
      final key = dateKeyFromDate(day);
      last7[i] = (successMap[key] ?? 0.0).round();
    }

    double overall = 0;
    if (successMap.isNotEmpty) {
      overall =
          successMap.values.reduce((a, b) => a + b) / successMap.values.length;
    }

    final int longestStreak =
        StreakService.bestStreak(successMap, allowGrace: graceEnabled);
    final int current =
        StreakService.currentStreak(successMap, allowGrace: graceEnabled);

    setState(() {
      _last7Days = last7;
      _history = successMap;
      _overallSuccess = overall;
      _longestStreak = longestStreak;
      _currentStreak = current;
      _activeHabits = activeHabits;
      _xp = xp;
      _unlocked = unlocked;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.statsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final int maxValue =
        _last7Days.fold<int>(0, (max, v) => v > max ? v : max);
    final levelInfo = XpService.getLevelInfo(_xp);

    // Narrow weekday labels for the actual last-7 days (index 6 = today).
    final today = DateTime.now();
    final dowFmt = DateFormat('EEEEE', l10n.localeName);
    final last7Labels = List.generate(
        7, (i) => dowFmt.format(today.subtract(Duration(days: 6 - i))));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsTitle),
        actions: const [MusicToggleButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // XP / Level card
            _XpLevelCard(info: levelInfo),
            const SizedBox(height: 12),

            // Stat cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: l10n.statOverallSuccess,
                    value: '${_overallSuccess.toStringAsFixed(0)}%',
                    icon: Icons.check_circle,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: l10n.statCurrentStreak,
                    value: l10n.statDays(_currentStreak),
                    icon: Icons.local_fire_department,
                    color: const Color(0xFFF57C00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: l10n.statLongestStreak,
                    value: l10n.statDays(_longestStreak),
                    icon: Icons.emoji_events,
                    color: const Color(0xFFFFD54F),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: l10n.statActiveHabits,
                    value: '$_activeHabits',
                    icon: Icons.auto_awesome,
                    color: const Color(0xFF4DD0E1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 7-day bar chart
            Text(
              l10n.last7Days,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: context.palette.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children:
                            List.generate(_last7Days.length, (index) {
                          final value = _last7Days[index];
                          final heightFactor =
                              maxValue == 0 ? 0.0 : value / maxValue;
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '$value',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: scheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 4),
                                  Flexible(
                                    child: FractionallySizedBox(
                                      heightFactor: heightFactor,
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF7C4DFF),
                                              Color(0xFF00E5FF),
                                            ],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x6600E5FF),
                                              blurRadius: 8,
                                              spreadRadius: -2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final d in last7Labels)
                          Text(d, style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Yearly activity heatmap (GitHub-style)
            Text(
              l10n.heatmapTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: YearlyHeatmap(history: _history),
            ),
            const SizedBox(height: 20),

            // Achievements
            Text(
              l10n.achievementsTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
              children: allAchievements.map((a) {
                final isUnlocked = _unlocked.contains(a.id);
                return _AchievementTile(
                    achievement: a, isUnlocked: isUnlocked);
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── XP / Level card ──────────────────────────────────────────────

class _XpLevelCard extends StatelessWidget {
  const _XpLevelCard({required this.info});
  final LevelInfo info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final hasNext = info.xpNextLevel > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(info.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.levelAndTitle(info.level, levelTitle(l10n, info.level)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      hasNext
                          ? l10n.xpToNextLevel(info.xp, info.xpToNext)
                          : l10n.xpMaxLevel(info.xp),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasNext) ...[
            const SizedBox(height: 10),
            GradientProgressBar(value: info.progress, height: 8),
          ],
        ],
      ),
    );
  }
}

// ── Achievement tile ──────────────────────────────────────────────

class _AchievementTile extends StatelessWidget {
  const _AchievementTile(
      {required this.achievement, required this.isUnlocked});
  final Achievement achievement;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final color = isUnlocked ? achievement.color : scheme.outlineVariant;

    return Tooltip(
      message: achievementDescription(l10n, achievement.id),
      child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked
              ? achievement.color.withValues(alpha: 0.5)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: isUnlocked ? 0.18 : 0.07),
            ),
            child: Icon(achievement.icon,
                size: 20, color: isUnlocked ? color : color.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 5),
          Text(
            achievementTitle(l10n, achievement.id),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isUnlocked ? null : scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: scheme.onSurface),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

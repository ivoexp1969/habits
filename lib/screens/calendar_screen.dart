import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/habit_service.dart';
import '../services/theme_service.dart';
import '../widgets/music_toggle_button.dart';

enum DayStatus { none, full, partial, missed }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, double> _history = {};

  /// Reloads history from storage. Called when this tab becomes visible so it
  /// reflects habits completed since it was last built (IndexedStack keeps
  /// the State alive, so initState does not re-run on tab switch).
  void reload() => _loadHistory();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HabitService.loadHistory();
    setState(() => _history = history);
  }

  void _goToPreviousMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  DayStatus _statusFor(DateTime day) {
    if (day.month != _focusedMonth.month) return DayStatus.none;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final key = dateKeyFromDate(day);
    final success = _history[key] ?? 0.0;

    if (success >= 90) return DayStatus.full;
    if (success > 0) return DayStatus.partial;
    if (day.isBefore(todayDate)) return DayStatus.missed;
    return DayStatus.none;
  }

  Color _statusColor(DayStatus status, ColorScheme scheme) {
    switch (status) {
      case DayStatus.full:
        return const Color(0xFF2E7D32);
      case DayStatus.partial:
        return const Color(0xFFF9A825);
      case DayStatus.missed:
        return const Color(0xFFC62828);
      case DayStatus.none:
        return scheme.outlineVariant;
    }
  }

  String _monthLabel(DateTime date, String localeName) {
    final label = DateFormat.yMMMM(localeName).format(date);
    // Capitalize the first letter (some locales, incl. bg, lowercase months).
    return label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
  }

  /// Narrow single-letter weekday labels, Monday→Sunday, for [localeName].
  List<String> _weekdayNarrow(String localeName) {
    final fmt = DateFormat('EEEEE', localeName);
    // 2024-01-01 is a Monday.
    return List.generate(
        7, (i) => fmt.format(DateTime(2024, 1, 1).add(Duration(days: i))));
  }

  /// Summary stats for [_focusedMonth], computed over elapsed days only
  /// (day 1 → today, or the whole month if it is in the past).
  ({int completedDays, int bestStreak, int avgSuccess}) _monthSummary() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    int completed = 0;
    int bestStreak = 0;
    int streak = 0;
    double sum = 0;
    int elapsed = 0;

    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_focusedMonth.year, _focusedMonth.month, d);
      if (day.isAfter(todayDate)) break;
      elapsed++;
      final success = _history[dateKeyFromDate(day)] ?? 0.0;
      sum += success;
      if (success >= 90) {
        completed++;
        streak++;
        if (streak > bestStreak) bestStreak = streak;
      } else {
        streak = 0;
      }
    }

    return (
      completedDays: completed,
      bestStreak: bestStreak,
      avgSuccess: elapsed == 0 ? 0 : (sum / elapsed).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final firstOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysBefore = (firstOfMonth.weekday + 6) % 7;
    final firstDisplayDay =
        firstOfMonth.subtract(Duration(days: daysBefore));
    // Only render as many full weeks as this month actually needs, so we don't
    // get a trailing row that is entirely next-month days (keeps grid + legend
    // on one screen).
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final cellCount = ((daysBefore + daysInMonth) / 7).ceil() * 7;
    final days = List<DateTime>.generate(
        cellCount, (i) => firstDisplayDay.add(Duration(days: i)));

    final summary = _monthSummary();

    final weekdays = _weekdayNarrow(l10n.localeName);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navCalendar),
        actions: const [MusicToggleButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _goToPreviousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _monthLabel(_focusedMonth, l10n.localeName),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _goToNextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Month summary
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.palette.border),
              ),
              child: Row(
                children: [
                  _SummaryStat(
                    icon: Icons.check_circle_outline,
                    value: '${summary.completedDays}',
                    label: l10n.monthSummaryCompleted,
                    color: _statusColor(DayStatus.full, scheme),
                  ),
                  _SummaryDivider(),
                  _SummaryStat(
                    icon: Icons.local_fire_department,
                    value: '${summary.bestStreak}',
                    label: l10n.monthSummaryBestStreak,
                    color: const Color(0xFFF57C00),
                  ),
                  _SummaryDivider(),
                  _SummaryStat(
                    icon: Icons.percent,
                    value: '${summary.avgSuccess}%',
                    label: l10n.monthSummaryAvg,
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final w in weekdays) _WeekdayLabel(w),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 1,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final date = days[index];
                final status = _statusFor(date);
                final isToday = date.year == todayDate.year &&
                    date.month == todayDate.month &&
                    date.day == todayDate.day;
                final isCurrentMonth = date.month == _focusedMonth.month;
                final color = _statusColor(status, scheme);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isCurrentMonth
                        ? context.palette.card
                        : context.palette.border,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isToday
                          ? scheme.primary
                          : color.withValues(
                              alpha:
                                  status == DayStatus.none ? 0.35 : 0.9),
                      width: isToday ? 1.8 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isCurrentMonth
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                          ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                _LegendDot(
                  color: _statusColor(DayStatus.full, scheme),
                  label: l10n.legendFull,
                ),
                _LegendDot(
                  color: _statusColor(DayStatus.partial, scheme),
                  label: l10n.legendPartial,
                ),
                _LegendDot(
                  color: _statusColor(DayStatus.missed, scheme),
                  label: l10n.legendMissed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: context.palette.border,
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

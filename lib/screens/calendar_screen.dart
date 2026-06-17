import 'package:flutter/material.dart';

import '../services/habit_service.dart';
import '../services/theme_service.dart';

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

  String _monthLabel(DateTime date) {
    const months = [
      'Януари', 'Февруари', 'Март', 'Април', 'Май', 'Юни',
      'Юли', 'Август', 'Септември', 'Октомври', 'Ноември', 'Декември',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final firstOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysBefore = (firstOfMonth.weekday + 6) % 7;
    final firstDisplayDay =
        firstOfMonth.subtract(Duration(days: daysBefore));
    final days = List<DateTime>.generate(
        42, (i) => firstDisplayDay.add(Duration(days: i)));

    return Scaffold(
      appBar: AppBar(title: const Text('Календар')),
      body: Padding(
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
                      _monthLabel(_focusedMonth),
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
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _WeekdayLabel('П'),
                _WeekdayLabel('В'),
                _WeekdayLabel('С'),
                _WeekdayLabel('Ч'),
                _WeekdayLabel('П'),
                _WeekdayLabel('С'),
                _WeekdayLabel('Н'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final date = days[index];
                  final status = _statusFor(date);
                  final isToday = date.year == todayDate.year &&
                      date.month == todayDate.month &&
                      date.day == todayDate.day;
                  final isCurrentMonth =
                      date.month == _focusedMonth.month;
                  final color = _statusColor(status, scheme);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isCurrentMonth
                          ? context.palette.card
                          : context.palette.border,
                      borderRadius: BorderRadius.circular(16),
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
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
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
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                _LegendDot(
                  color: _statusColor(DayStatus.full, scheme),
                  label: 'Напълно завършен',
                ),
                _LegendDot(
                  color: _statusColor(DayStatus.partial, scheme),
                  label: 'Частично',
                ),
                _LegendDot(
                  color: _statusColor(DayStatus.missed, scheme),
                  label: 'Пропуснат',
                ),
              ],
            ),
          ],
        ),
      ),
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

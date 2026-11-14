import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/habit.dart';
import '../services/diag_log.dart';
import '../services/habit_service.dart';
import '../services/widget_service.dart';

/// Hidden diagnostics screen (7 taps on the version row in Settings). Shows the
/// build number and the last 20 logged events (new-day reset, cloud sync) so a
/// morning problem can be read off the device instead of guessed.
class DiagScreen extends StatefulWidget {
  const DiagScreen({super.key});

  @override
  State<DiagScreen> createState() => _DiagScreenState();
}

class _DiagScreenState extends State<DiagScreen> {
  List<String> _events = const [];
  List<Habit> _habits = const [];
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Prefixes an app event's message with [app] (after its timestamp) so the
  // merged list distinguishes app events from the widget's own [widget] ones.
  String _tagApp(String e) {
    final i = e.indexOf('  ');
    if (i < 0) return '[app] $e';
    return '${e.substring(0, i)}  [app] ${e.substring(i + 2)}';
  }

  Future<void> _load() async {
    final appEvents = await DiagLog.recent();
    final widgetEvents = await WidgetService.readWidgetLog();
    // Merge app + widget logs, sort by the leading "yyyy-MM-dd HH:mm:ss" (desc).
    final merged = <String>[
      ...appEvents.map(_tagApp),
      ...widgetEvents,
    ];
    String keyOf(String s) => s.length >= 19 ? s.substring(0, 19) : s;
    merged.sort((a, b) => keyOf(b).compareTo(keyOf(a)));
    final habits = await HabitService.loadHabits();
    var v = '';
    try {
      final info = await PackageInfo.fromPlatform();
      v = '${info.version} (${info.buildNumber})';
    } catch (_) {}
    if (mounted) {
      setState(() {
        _events = merged;
        _habits = habits;
        _version = v;
      });
    }
  }

  String _habitLine(Habit h) {
    final freq = h.frequencyUnit; // day | week | month
    final goal = h.hasGoal ? ' goal=${h.goalTarget}/${h.goalPeriod}' : '';
    return '${h.name}: ${h.completedTimes}/${h.timesPerDay} per $freq  '
        'pk=${h.periodKey}$goal';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Диагностика'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Копирай',
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: '$_version\n${_events.join('\n')}'));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Копирано')));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Изчисти',
            onPressed: () async {
              await DiagLog.clear();
              await WidgetService.clearWidgetLog();
              await _load();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Версия: $_version',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Навици (${_habits.length}):',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ..._habits.map((h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: SelectableText(_habitLine(h),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              )),
          const Divider(),
          Text('Последни ${_events.length} събития (най-новото горе):',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          const Divider(),
          if (_events.isEmpty)
            const Text('Няма записани събития.')
          else
            ..._events.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SelectableText(e,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12)),
                )),
        ],
      ),
    );
  }
}

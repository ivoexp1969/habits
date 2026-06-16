import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/achievements.dart';
import '../data/habit_icon_catalog.dart';
import '../data/habit_templates.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../services/xp_service.dart';
import 'paywall_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Habit> _habits = [];
  double _fabDy = 0.8;

  /// Re-reads habits from storage. Called when the day rolls over
  /// (lazy daily reset) while the app is already running.
  void reload() => _loadHabits();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _timesPerDayController =
      TextEditingController(text: '1');


  Future<void> _refreshSmartReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileStr = prefs.getString(kPrefsProfile);
      bool notificationsEnabled = true;
      bool smartEnabled = true;
      if (profileStr != null) {
        try {
          final data = jsonDecode(profileStr) as Map<String, dynamic>;
          notificationsEnabled = data['notificationsEnabled'] as bool? ?? true;
          smartEnabled = data['smartRemindersEnabled'] as bool? ?? true;
        } catch (_) {}
      }
      if (!notificationsEnabled || !smartEnabled) {
        for (var id = 3100; id <= 3104; id++) {
          await notificationsPlugin.cancel(id);
        }
        return;
      }
      await NotificationService().scheduleSmartRemindersForToday(_habits);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final prefs = await SharedPreferences.getInstance();

    // Migration v2: clear the 3 old auto-generated default habits
    if ((prefs.getInt('habits_ver') ?? 1) < 2) {
      final old = prefs.getString(kPrefsHabits);
      if (old != null) {
        try {
          final list = (jsonDecode(old) as List)
              .map((e) => Habit.fromJson(e as Map<String, dynamic>))
              .toList();
          const defaults = {'Пия вода', 'Чета', 'Спортувам'};
          if (list.length <= 3 &&
              list.every((h) => defaults.contains(h.name))) {
            await prefs.remove(kPrefsHabits);
          }
        } catch (_) {}
      }
      await prefs.setInt('habits_ver', 2);
    }

    // v3: fix "Сон 8ч" typo + remove duplicate habits by name
    if ((prefs.getInt('habits_ver') ?? 1) < 3) {
      final json3 = prefs.getString(kPrefsHabits);
      if (json3 != null) {
        try {
          final list = (jsonDecode(json3) as List)
              .map((e) => Habit.fromJson(e as Map<String, dynamic>))
              .toList();
          for (final h in list) {
            if (h.name == 'Сон 8ч') h.name = 'Сън 8ч';
          }
          final seen = <String>{};
          final deduped = list.where((h) {
            if (seen.contains(h.name)) return false;
            seen.add(h.name);
            return true;
          }).toList();
          await prefs.setString(kPrefsHabits,
              jsonEncode(deduped.map((h) => h.toJson()).toList()));
        } catch (_) {}
      }
      await prefs.setInt('habits_ver', 3);
    }

    // v4: rename habit names for consistency
    if ((prefs.getInt('habits_ver') ?? 1) < 4) {
      final json4 = prefs.getString(kPrefsHabits);
      if (json4 != null) {
        try {
          final list = (jsonDecode(json4) as List)
              .map((e) => Habit.fromJson(e as Map<String, dynamic>))
              .toList();
          const renames = <String, String>{
            'Здравословна храна': 'Правилна храна',
            'Благодарност': 'Намирам радост',
            'Без соц. мрежи': 'Пауза от мрежи',
            'Deep Work': 'Фокусирана работа',
            'Дълбока работа': 'Фокусирана работа',
          };
          for (final h in list) {
            final n = renames[h.name];
            if (n != null) h.name = n;
          }
          await prefs.setString(
              kPrefsHabits, jsonEncode(list.map((h) => h.toJson()).toList()));
        } catch (_) {}
      }
      await prefs.setInt('habits_ver', 4);
    }

    final jsonString = prefs.getString(kPrefsHabits);
    if (jsonString == null) {
      setState(() => _habits = []);
      await _refreshSmartReminders();
      return;
    }
    try {
      final List<dynamic> data = jsonDecode(jsonString) as List<dynamic>;
      setState(() => _habits =
          data.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList());
    } catch (_) {
      setState(() => _habits = []);
    }
    await _refreshSmartReminders();
  }

  double get _dayProgress {
    if (_habits.isEmpty) return 0;
    return _habits.fold<double>(0, (sum, h) => sum + h.progress) /
        _habits.length;
  }

  Future<void> _saveHabits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        kPrefsHabits, jsonEncode(_habits.map((h) => h.toJson()).toList()));
    final key = dateKeyFromDate(DateTime.now());
    final historyStr = prefs.getString(kPrefsHistory);
    Map<String, dynamic> history = {};
    if (historyStr != null) {
      try {
        history = jsonDecode(historyStr) as Map<String, dynamic>;
      } catch (_) {}
    }
    history[key] = _dayProgress * 100;
    await prefs.setString(kPrefsHistory, jsonEncode(history));
  }

  // ── XP + Achievements after increment ───────────────────────────
  Future<void> _onHabitIncremented() async {
    final (newXP, leveledUp) = await XpService.onHabitCompleted();
    bool anyLevelUp = leveledUp;

    if (_habits.every((h) => h.isCompleted)) {
      final (_, bonusLevelUp, given) = await XpService.onPerfectDay();
      if (given) {
        anyLevelUp = anyLevelUp || bonusLevelUp;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🏆 Перфектен ден! +50 XP бонус'),
              backgroundColor: Color(0xFF1A1E24),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }

    if (anyLevelUp && mounted) {
      final info = XpService.getLevelInfo(newXP);
      _showLevelUpDialog(info);
    }

    final history = await HabitService.loadHistory();
    final newAch = await AchievementService.check(habits: _habits, history: history);
    if (newAch.isNotEmpty && mounted) {
      for (final achId in newAch) {
        final ach = allAchievements.firstWhere(
          (a) => a.id == achId,
          orElse: () => allAchievements.first,
        );
        if (!mounted) break;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(ach.icon, color: ach.color, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Постижение: ${ach.title}!')),
              ],
            ),
            backgroundColor: const Color(0xFF1A1E24),
            duration: const Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  void _showLevelUpDialog(LevelInfo info) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111318),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              'Ниво ${info.level}!',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
            Text(
              info.title,
              style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${info.xp} XP',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
        actions: [
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Напред!'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _incrementHabit(Habit habit) {
    setState(() {
      if (habit.completedTimes < habit.timesPerDay) habit.completedTimes++;
    });
    _saveHabits();
    _refreshSmartReminders();
    _onHabitIncremented();
  }

  void _decrementHabit(Habit habit) {
    setState(() {
      if (habit.completedTimes > 0) habit.completedTimes--;
    });
    _saveHabits();
    _refreshSmartReminders();
  }

  int get _completedCount => _habits.where((h) => h.isCompleted).length;

  // ── Templates bottom sheet ──────────────────────────────────────
  void _showTemplates() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.78;
        final bottomPad = MediaQuery.of(ctx).viewPadding.bottom;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            child: _TemplatesSheet(
              bottomPad: bottomPad,
              onAdd: (template) {
                final all = template.buildHabits();
                final toAdd = all
                    .where((h) => !_habits.any((e) => e.name == h.name))
                    .toList();

                // Check paywall BEFORE closing the sheet so it doesn't look
                // like templates vanished. Sheet stays open; paywall slides on top.
                if (!PurchaseService.instance.isPremium &&
                    _habits.length + toAdd.length > kFreeHabitLimit) {
                  Navigator.of(context)
                      .push<bool>(
                        MaterialPageRoute(
                            builder: (_) => const PaywallScreen()),
                      )
                      .then((paid) {
                    if (paid == true && mounted) {
                      Navigator.pop(ctx);
                      setState(() => _habits.addAll(toAdd));
                      _saveHabits();
                      _refreshSmartReminders();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Добавени ${toAdd.length} навика от "${template.name}"'),
                        backgroundColor: const Color(0xFF1A1E24),
                      ));
                      _checkAchievementsAfterAdd();
                    }
                  });
                  return;
                }

                Navigator.pop(ctx);
                if (toAdd.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Навиците от "${template.name}" вече са добавени'),
                      backgroundColor: const Color(0xFF1A1E24),
                    ),
                  );
                  return;
                }
                setState(() => _habits.addAll(toAdd));
                _saveHabits();
                _refreshSmartReminders();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Добавени ${toAdd.length} навика от "${template.name}"'),
                    backgroundColor: const Color(0xFF1A1E24),
                  ),
                );
                _checkAchievementsAfterAdd();
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkAchievementsAfterAdd() async {
    final history = await HabitService.loadHistory();
    final newAch = await AchievementService.check(habits: _habits, history: history);
    if (newAch.isNotEmpty && mounted) {
      for (final achId in newAch) {
        final ach = allAchievements.firstWhere(
          (a) => a.id == achId,
          orElse: () => allAchievements.first,
        );
        if (!mounted) break;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(ach.icon, color: ach.color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Постижение: ${ach.title}!')),
            ]),
            backgroundColor: const Color(0xFF1A1E24),
            duration: const Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  // ── Add / Edit / Delete dialogs ─────────────────────────────────
  Future<void> _showAddHabitDialog() async {
    if (!PurchaseService.instance.isPremium &&
        _habits.length >= kFreeHabitLimit) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }
    _nameController.clear();
    _timesPerDayController.text = '1';
    int selectedIconIndex = 0;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Нов навик'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Име на навика',
                        hintText: 'Напр. Пия вода',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _timesPerDayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Пъти на ден',
                        hintText: '1',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Иконка',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          List.generate(habitIconOptions.length, (index) {
                        final isSelected = index == selectedIconIndex;
                        final opt = habitIconOptions[index];
                        final scheme = Theme.of(context).colorScheme;
                        return GestureDetector(
                          onTap: () => setStateDialog(
                              () => selectedIconIndex = index),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? opt.color.withValues(alpha: 0.2)
                                  : const Color(0xFF111318),
                              border: Border.all(
                                color: isSelected
                                    ? opt.color
                                    : scheme.outlineVariant,
                              ),
                            ),
                            child: Icon(
                              opt.icon,
                              size: 22,
                              color: isSelected
                                  ? opt.color
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отказ'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;
                    final parsed =
                        int.tryParse(_timesPerDayController.text) ?? 1;
                    final times = parsed < 1 ? 1 : parsed;
                    final opt = habitIconOptions[selectedIconIndex];
                    setState(() {
                      _habits.add(Habit(
                        name: name,
                        timesPerDay: times,
                        color: opt.color,
                        icon: opt.icon,
                      ));
                    });
                    _saveHabits();
                    _refreshSmartReminders();
                    _checkAchievementsAfterAdd();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Добави'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditHabitDialog(Habit habit) async {
    _nameController.text = habit.name;
    _timesPerDayController.text = habit.timesPerDay.toString();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Редакция на навик'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Име на навика'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _timesPerDayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Пъти на ден'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отказ'),
            ),
            FilledButton(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;
                final parsed =
                    int.tryParse(_timesPerDayController.text) ?? 1;
                final times = parsed < 1 ? 1 : parsed;
                setState(() {
                  habit.name = name;
                  habit.timesPerDay = times;
                  if (habit.completedTimes > habit.timesPerDay) {
                    habit.completedTimes = habit.timesPerDay;
                  }
                });
                _saveHabits();
                _refreshSmartReminders();
                Navigator.of(context).pop();
              },
              child: const Text('Запази'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteHabit(Habit habit) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Изтриване на навик'),
          content:
              Text('Сигурен ли си, че искаш да изтриеш "${habit.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отказ'),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _habits.remove(habit));
                _saveHabits();
                _refreshSmartReminders();
                Navigator.of(context).pop();
              },
              child: const Text('Изтрий'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timesPerDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = DateTime.now();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        const fabSize = 56.0;
        final availableHeight =
            (constraints.maxHeight - fabSize - 24).clamp(1.0, double.infinity);
        final fabTop = 8 + _fabDy * availableHeight;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Днес'),
            actions: [
              IconButton(
                icon: const Icon(Icons.dashboard_customize_outlined),
                tooltip: 'Шаблони',
                onPressed: _showTemplates,
              ),
            ],
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Днешен прогрес',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$day.$month.$year',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                          value: _dayProgress, minHeight: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_dayProgress * 100).round()}% изпълнение · $_completedCount / ${_habits.length} навика',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _habits.isEmpty
                          ? _EmptyState(onAdd: _showAddHabitDialog, onTemplate: _showTemplates)
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: _habits.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final habit = _habits[index];
                                return HabitRow(
                                  habit: habit,
                                  onIncrement: () => _incrementHabit(habit),
                                  onDecrement: () => _decrementHabit(habit),
                                  onEdit: () => _showEditHabitDialog(habit),
                                  onDelete: () => _confirmDeleteHabit(habit),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                top: fabTop,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final h = availableHeight;
                      final newTop =
                          (_fabDy * h + details.delta.dy).clamp(0.0, h);
                      _fabDy = newTop / h;
                    });
                  },
                  child: FloatingActionButton.extended(
                    onPressed: _showAddHabitDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Навик'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.onTemplate});
  final VoidCallback onAdd;
  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_nature_outlined,
              size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Нямаш навици още',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добави ръчно или избери готов пакет',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onTemplate,
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: const Text('Избери пакет'),
          ),
        ],
      ),
    );
  }
}

// ── Templates bottom sheet ───────────────────────────────────────
class _TemplatesSheet extends StatelessWidget {
  const _TemplatesSheet({required this.onAdd, this.bottomPad = 0});
  final void Function(HabitTemplate) onAdd;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: SizedBox(
              width: 36,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF2A2D36),
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Пакети с навици',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Добавяне на готов набор от навици',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...habitTemplates.map((t) => _TemplateRow(t: t, onAdd: onAdd)),
        ],
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.t, required this.onAdd});
  final HabitTemplate t;
  final void Function(HabitTemplate) onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF18191F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2D36)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: t.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(t.icon, color: t.color, size: 24),
          ),
          title: Text(t.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          subtitle: Text(
            '${t.description} · ${t.buildHabits().length} навика',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.color.withValues(alpha: 0.18),
              foregroundColor: t.color,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => onAdd(t),
            child: const Text('Добави', style: TextStyle(fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

// ── HabitRow ─────────────────────────────────────────────────────
class HabitRow extends StatelessWidget {
  const HabitRow({
    super.key,
    required this.habit,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onDelete,
  });

  final Habit habit;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Widget _dots(Color color) {
    final done = habit.completedTimes;
    final total = habit.timesPerDay;
    if (total > 8) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 4,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.8)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$done/$total',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final filled = i < done;
        return Padding(
          padding: const EdgeInsets.only(right: 5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? color : Colors.transparent,
              border: Border.all(
                color: filled ? color : color.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canIncrement = habit.completedTimes < habit.timesPerDay;
    final canDecrement = habit.completedTimes > 0;
    final baseColor = habit.color ?? colorScheme.primary;
    final p = habit.progress;
    final isCompleted = habit.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111318),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? baseColor.withValues(alpha: 0.55)
              : const Color(0xFF2A2D36),
          width: isCompleted ? 1.5 : 1.0,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: p == 0 ? 0.001 : p,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          baseColor.withValues(alpha: 0.08),
                          baseColor.withValues(alpha: 0.20),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    habit.icon ?? Icons.check_circle,
                    size: 18,
                    color: baseColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        habit.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _dots(baseColor),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: canDecrement ? onDecrement : null,
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 26,
                        height: 34,
                        child: Icon(
                          Icons.remove,
                          size: 15,
                          color: canDecrement
                              ? Colors.white38
                              : Colors.white12,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: canIncrement ? onIncrement : null,
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? baseColor.withValues(alpha: 0.25)
                              : canIncrement
                                  ? baseColor.withValues(alpha: 0.15)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : Icons.add,
                          size: 18,
                          color: isCompleted
                              ? baseColor
                              : canIncrement
                                  ? Colors.white
                                  : Colors.white12,
                        ),
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    else if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Редакция')),
                    PopupMenuItem(value: 'delete', child: Text('Изтриване')),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(2, 8, 2, 8),
                    child: Icon(Icons.more_vert, size: 18, color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

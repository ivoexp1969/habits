import 'dart:convert';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/achievements.dart';
import '../data/habit_icon_catalog.dart';
import '../data/habit_templates.dart';
import '../l10n/app_localizations.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import '../services/identity_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../services/theme_service.dart';
import '../services/xp_service.dart';
import 'paywall_screen.dart';
import '../widgets/music_toggle_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Habit> _habits = [];
  double _fabDy = 0.8;
  final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  /// Re-reads habits from storage. Called when the day rolls over
  /// (lazy daily reset) while the app is already running.
  void reload() => _loadHabits();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _timesPerDayController =
      TextEditingController(text: '1');
  // Optional "Atomic Habits" fields for the add/edit form.
  final TextEditingController _identityController = TextEditingController();
  final TextEditingController _miniController = TextEditingController();


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
        await NotificationService().cancelSmartReminders();
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
          _confetti.play();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).perfectDayBonus),
              duration: const Duration(seconds: 2),
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
                Expanded(
                    child: Text(AppLocalizations.of(context)
                        .achievementUnlocked(
                            achievementTitle(AppLocalizations.of(context), ach.id)))),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  void _showLevelUpDialog(LevelInfo info) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              l10n.levelUpTitle(info.level),
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface),
            ),
            Text(
              levelTitle(l10n, info.level),
              style: TextStyle(
                  fontSize: 18,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.levelXp(info.xp),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
        actions: [
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.levelUpContinue),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _incrementHabit(Habit habit) {
    final wasCompleted = habit.isCompleted;
    var counted = false;
    setState(() {
      if (habit.completedTimes < habit.timesPerDay) {
        habit.completedTimes++;
        habit.totalCompletions++; // lifetime tally for identity votes
        counted = true;
      }
    });
    if (!wasCompleted && habit.isCompleted) _bumpStreak(habit);
    _saveHabits();
    _refreshSmartReminders();
    // "+1 глас за 'identity'" micro-feedback — only when this tap counted and
    // the habit has an identity set.
    if (counted) _showIdentityVoteFeedback(habit);
    _onHabitIncremented();
  }

  void _decrementHabit(Habit habit) {
    final wasCompleted = habit.isCompleted;
    setState(() {
      if (habit.completedTimes > 0) {
        habit.completedTimes--;
        // Mirror the lifetime tally so an undo doesn't inflate votes.
        if (habit.totalCompletions > 0) habit.totalCompletions--;
      }
    });
    // Undo today's streak bump if the habit is no longer complete today.
    if (wasCompleted && !habit.isCompleted) _unbumpStreak(habit);
    _saveHabits();
    _refreshSmartReminders();
  }

  // Brief SnackBar shown when a counted check-in adds a vote to an identity.
  void _showIdentityVoteFeedback(Habit habit) {
    final identity = habit.identity;
    if (identity == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.identityVoteFeedback(identity)),
        duration: const Duration(milliseconds: 1400),
      ));
  }

  // Habit just reached 100% today → extend its streak. Consecutive days
  // increment; a gap resets to 1. Idempotent if already counted today.
  void _bumpStreak(Habit habit) {
    final today = DateTime.now();
    final todayKey = dateKeyFromDate(today);
    final yesterdayKey =
        dateKeyFromDate(today.subtract(const Duration(days: 1)));
    if (habit.lastCompletedDate == todayKey) return;
    setState(() {
      habit.streak =
          habit.lastCompletedDate == yesterdayKey ? habit.streak + 1 : 1;
      if (habit.streak > habit.bestStreak) habit.bestStreak = habit.streak;
      habit.lastCompletedDate = todayKey;
    });
  }

  void _unbumpStreak(Habit habit) {
    final todayKey = dateKeyFromDate(DateTime.now());
    if (habit.lastCompletedDate != todayKey) return;
    setState(() {
      habit.streak = habit.streak > 0 ? habit.streak - 1 : 0;
      // We don't know the prior completion date; clearing it means a later
      // re-complete today starts the chain again from this streak value.
      habit.lastCompletedDate = null;
    });
  }

  int get _completedCount => _habits.where((h) => h.isCompleted).length;

  String _greetingText(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h < 12) return l10n.greetingMorning;
    if (h < 18) return l10n.greetingAfternoon;
    return l10n.greetingEvening;
  }

  // ── Templates bottom sheet ──────────────────────────────────────
  void _showTemplates() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (listCtx) {
        final maxH = MediaQuery.of(listCtx).size.height * 0.78;
        final bottomPad = MediaQuery.of(listCtx).viewPadding.bottom;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            child: _TemplatesSheet(
              bottomPad: bottomPad,
              existingNames: _habits.map((h) => _normName(h.name)).toSet(),
              onOpen: (template) => _showTemplateDetail(listCtx, template),
            ),
          ),
        );
      },
    );
  }

  // Detail sheet for one pack: lists its habits (marking ones already added),
  // then offers Добави / Изход.
  void _showTemplateDetail(BuildContext listCtx, HabitTemplate template) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (detailCtx) {
        final maxH = MediaQuery.of(detailCtx).size.height * 0.82;
        final bottomPad = MediaQuery.of(detailCtx).viewPadding.bottom;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: _TemplateDetailSheet(
            template: template,
            existingNames: _habits.map((h) => h.name).toSet(),
            bottomPad: bottomPad,
            onExit: () => Navigator.pop(detailCtx),
            onAdd: () {
              Navigator.pop(detailCtx);
              Navigator.pop(listCtx);
              _addTemplate(template);
            },
          ),
        );
      },
    );
  }

  // Adds a pack's habits, skipping any already present (dedup by normalized name).
  Future<void> _addTemplate(HabitTemplate template) async {
    final all = template.buildHabits();
    final existing = _habits.map((h) => _normName(h.name)).toSet();
    final toAdd =
        all.where((h) => !existing.contains(_normName(h.name))).toList();

    if (toAdd.isEmpty) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.packAlreadyAdded(templateName(l10n, template.id))),
      ));
      return;
    }

    if (!PurchaseService.instance.isPremium &&
        _habits.length + toAdd.length > kFreeHabitLimit) {
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      if (paid != true) return;
    }

    if (!mounted) return;
    setState(() => _habits.addAll(toAdd));
    _saveHabits();
    _refreshSmartReminders();
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(l10n.packAddedCount(toAdd.length, templateName(l10n, template.id))),
    ));
    _checkAchievementsAfterAdd();
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
              Expanded(
                  child: Text(AppLocalizations.of(context).achievementUnlocked(
                      achievementTitle(AppLocalizations.of(context), ach.id)))),
            ]),
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
    _identityController.clear();
    _miniController.clear();
    int selectedIconIndex = 0;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final l10n = AppLocalizations.of(context);
            return AlertDialog(
              title: Text(l10n.newHabit),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.habitName,
                        hintText: l10n.habitNameHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _timesPerDayController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.timesPerDay,
                        hintText: '1',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.iconLabel,
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
                        return Tooltip(
                          message: habitIconLabel(l10n, opt.labelKey),
                          child: GestureDetector(
                          onTap: () => setStateDialog(
                              () => selectedIconIndex = index),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? opt.color.withValues(alpha: 0.2)
                                  : context.palette.cardAlt,
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
                        ),
                        );
                      }),
                    ),
                    _AdvancedFieldsSection(
                      identityController: _identityController,
                      miniController: _miniController,
                      suggestions: distinctIdentities(_habits),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
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
                        identity: _identityController.text,
                        miniVersion: _miniController.text,
                      ));
                    });
                    _saveHabits();
                    _refreshSmartReminders();
                    _checkAchievementsAfterAdd();
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.add),
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
    _identityController.text = habit.identity ?? '';
    _miniController.text = habit.miniVersion ?? '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.editHabit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.habitName),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _timesPerDayController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.timesPerDay),
                ),
                _AdvancedFieldsSection(
                  identityController: _identityController,
                  miniController: _miniController,
                  suggestions:
                      distinctIdentities(_habits.where((h) => h != habit).toList()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;
                final parsed =
                    int.tryParse(_timesPerDayController.text) ?? 1;
                final times = parsed < 1 ? 1 : parsed;
                final identity = _identityController.text.trim();
                final mini = _miniController.text.trim();
                setState(() {
                  habit.name = name;
                  habit.timesPerDay = times;
                  habit.identity = identity.isEmpty ? null : identity;
                  habit.miniVersion = mini.isEmpty ? null : mini;
                  if (habit.completedTimes > habit.timesPerDay) {
                    habit.completedTimes = habit.timesPerDay;
                  }
                });
                _saveHabits();
                _refreshSmartReminders();
                Navigator.of(context).pop();
              },
              child: Text(l10n.save),
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
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.deleteHabit),
          content: Text(l10n.deleteHabitConfirm(habit.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _habits.remove(habit));
                _saveHabits();
                _refreshSmartReminders();
                Navigator.of(context).pop();
              },
              child: Text(l10n.delete),
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
    _identityController.dispose();
    _miniController.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
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
            title: Text(l10n.homeTitle),
            actions: [
              const MusicToggleButton(),
              IconButton(
                icon: const Icon(Icons.dashboard_customize_outlined),
                tooltip: l10n.templatesTooltip,
                onPressed: _showTemplates,
              ),
            ],
          ),
          body: Stack(
            children: [
              // Celebration confetti — fired on a perfect day (all habits done).
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  maxBlastForce: 18,
                  minBlastForce: 8,
                  gravity: 0.25,
                  colors: const [
                    Color(0xFF00E5FF),
                    Color(0xFF7C4DFF),
                    Color(0xFFFF2D95),
                    Color(0xFFFFC107),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _greetingText(l10n),
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$day.$month.$year',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ShaderMask(
                                shaderCallback: (r) => LinearGradient(
                                  colors: [
                                    scheme.primary,
                                    scheme.secondary,
                                    scheme.tertiary,
                                  ],
                                ).createShader(r),
                                child: Text(
                                  '${(_dayProgress * 100).round()}%',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          GradientProgressBar(value: _dayProgress, height: 12),
                          const SizedBox(height: 8),
                          Text(
                            l10n.habitsCompletedToday(
                                _completedCount, _habits.length),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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
                                  identityVotes: habit.identity != null
                                      ? votesForIdentity(habit.identity!, _habits)
                                      : 0,
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
                    label: Text(l10n.addHabitFab),
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
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_nature_outlined,
              size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            l10n.emptyTitle,
            style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.emptySubtitle,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onTemplate,
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: Text(l10n.choosePack),
          ),
        ],
      ),
    );
  }
}

// Normalizes a habit name for duplicate detection (case/space-insensitive).
String _normName(String s) => s.trim().toLowerCase();

// ── Templates bottom sheet ───────────────────────────────────────
class _TemplatesSheet extends StatelessWidget {
  const _TemplatesSheet({
    required this.onOpen,
    required this.existingNames,
    this.bottomPad = 0,
  });
  final void Function(HabitTemplate) onOpen;
  final Set<String> existingNames;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SizedBox(
              width: 36,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.border,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.packsTitle,
            style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.packsSubtitle,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...habitTemplates.map((t) {
            final habits = t.buildHabits();
            final added = habits
                .where((h) => existingNames.contains(_normName(h.name)))
                .length;
            return _TemplateRow(
              t: t,
              total: habits.length,
              added: added,
              onOpen: () => onOpen(t),
            );
          }),
        ],
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.t,
    required this.total,
    required this.added,
    required this.onOpen,
  });
  final HabitTemplate t;
  final int total;
  final int added;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final l10n = AppLocalizations.of(context);
    final allAdded = added == total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.palette.cardAlt,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.border),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: t.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(t.icon, color: t.color, size: 24),
              ),
              title: Text(templateName(l10n, t.id),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              subtitle: Text(
                allAdded
                    ? l10n.allHabitsAdded(total)
                    : added > 0
                        ? l10n.packSomeAdded(total, added)
                        : l10n.packDescCount(
                            templateDescription(l10n, t.id), total),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: allAdded ? t.color : scheme.onSurfaceVariant,
                    fontSize: 12),
              ),
              trailing: allAdded
                  ? Icon(Icons.check_circle, color: t.color, size: 22)
                  : Icon(Icons.chevron_right,
                      color: scheme.onSurfaceVariant, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Template detail sheet (lists a pack's habits + Add/Exit) ──────
class _TemplateDetailSheet extends StatelessWidget {
  const _TemplateDetailSheet({
    required this.template,
    required this.existingNames,
    required this.onAdd,
    required this.onExit,
    this.bottomPad = 0,
  });
  final HabitTemplate template;
  final Set<String> existingNames;
  final VoidCallback onAdd;
  final VoidCallback onExit;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final l10n = AppLocalizations.of(context);
    final habits = template.buildHabits();
    final toAdd =
        habits.where((h) => !existingNames.contains(_normName(h.name))).length;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SizedBox(
              width: 36,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.border,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: template.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(template.icon, color: template.color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(templateName(l10n, template.id),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    Text(templateDescription(l10n, template.id),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: habits.map((h) {
                  final already = existingNames.contains(_normName(h.name));
                  final c = h.color ?? scheme.primary;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.palette.cardAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(h.icon ?? Icons.check_circle,
                                color: c, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                Text(l10n.timesPerDayShort(h.timesPerDay),
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          if (already)
                            Icon(Icons.check_circle,
                                color: c.withValues(alpha: 0.9), size: 20),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onExit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    side: BorderSide(color: context.palette.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.exitBtn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: toAdd == 0 ? null : onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: template.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    toAdd == 0 ? l10n.allAddedShort : l10n.addN(toAdd),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── HabitRow ─────────────────────────────────────────────────────
// Collapsible "Advanced (Atomic Habits)" section for the add/edit form.
// Progressive disclosure: collapsed by default so the basic form stays clean.
// Holds the optional identity field (+ chips of identities already used on
// other habits, deduplicated by normalized form) and the 2-minute mini version.
class _AdvancedFieldsSection extends StatelessWidget {
  const _AdvancedFieldsSection({
    required this.identityController,
    required this.miniController,
    required this.suggestions,
  });

  final TextEditingController identityController;
  final TextEditingController miniController;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Theme(
      // Hide ExpansionTile's default top/bottom divider lines in the dialog.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          l10n.advancedSection,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [
          TextField(
            controller: identityController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.identityLabel,
              hintText: l10n.identityHint,
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () {
                      identityController.text = s;
                      identityController.selection =
                          TextSelection.collapsed(offset: s.length);
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: miniController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.miniVersionLabel,
              hintText: l10n.miniVersionHint,
            ),
          ),
        ],
      ),
    );
  }
}

class HabitRow extends StatelessWidget {
  const HabitRow({
    super.key,
    required this.habit,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onDelete,
    this.identityVotes = 0,
  });

  final Habit habit;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  // Live-computed votes for this habit's identity (sum across matching habits).
  final int identityVotes;

  // A brighter, MORE saturated variant of [c] used for the vivid fill stop.
  // Shifting lightness up via HSL (instead of mixing toward white) keeps the
  // colour vivid rather than washed-out.
  static Color _vivid(Color c) {
    final h = HSLColor.fromColor(c);
    return h
        .withSaturation((h.saturation + 0.25).clamp(0.0, 1.0))
        .withLightness((h.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final canIncrement = habit.completedTimes < habit.timesPerDay;
    final canDecrement = habit.completedTimes > 0;
    final baseColor = habit.color ?? colorScheme.primary;
    final p = habit.progress;
    final isCompleted = habit.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? baseColor.withValues(alpha: 0.55)
              : context.palette.border,
          width: isCompleted ? 1.5 : 1.0,
        ),
      ),
      child: Stack(
        children: [
          // Whole rectangle always carries the habit's colour …
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // … and a vivid gradient fills it left→right as the habit progresses.
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
                          baseColor.withValues(alpha: 0.55),
                          _vivid(baseColor).withValues(alpha: 0.85),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${habit.completedTimes} / ${habit.timesPerDay}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                          if (habit.streak > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '🔥 ${habit.streak}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF57C00),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // 2-minute rule: an easy tappable option shown only while
                      // the habit is unfinished. Tapping counts as a normal
                      // check-in (same as "+"), keeping the streak alive.
                      if (habit.miniVersion != null && !isCompleted) ...[
                        const SizedBox(height: 5),
                        Tooltip(
                          message: l10n.miniVersionTooltip,
                          child: InkWell(
                            onTap: onIncrement,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: baseColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt, size: 13, color: baseColor),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      habit.miniVersion!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.75),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      // "Гласувал си N пъти за 'identity'" — the habit's identity
                      // detail, shown on the card only when an identity is set.
                      if (habit.identity != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          l10n.identityVotesLine(identityVotes, habit.identity!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface.withValues(alpha: 0.25),
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
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface.withValues(alpha: 0.25),
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
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text(l10n.editMenu)),
                    PopupMenuItem(value: 'delete', child: Text(l10n.deleteMenu)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                    child: Icon(Icons.more_vert, size: 18, color: colorScheme.onSurfaceVariant),
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

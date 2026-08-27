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
import '../services/theme_service.dart';
import '../services/xp_service.dart';
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
  final TextEditingController _rewardController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();


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
    if (!wasCompleted && habit.isCompleted) {
      _bumpStreak(habit);
      // Habit stacking: completing an anchor cues its dependent habits.
      _fireStackReminders(habit);
    }
    _saveHabits();
    _refreshSmartReminders();
    // Micro-feedback for a counted check-in: an identity "vote" and/or the
    // temptation-bundling reward the user set for this habit.
    if (counted) _showCheckInFeedback(habit);
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

  // Resolves the display name of [habit]'s stacking anchor. Returns null when
  // there is no anchor or the referenced habit no longer exists (dangling id).
  String? _anchorNameFor(Habit habit) {
    final aid = habit.afterHabitId;
    if (aid == null) return null;
    for (final h in _habits) {
      if (h.id == aid) return h.name;
    }
    return null;
  }

  // Habit stacking trigger: when [anchor] is completed, fire a local
  // notification cue for every habit stacked after it that isn't done yet.
  void _fireStackReminders(Habit anchor) {
    for (final h in _habits) {
      if (h.afterHabitId == anchor.id && !h.isCompleted) {
        NotificationService().showStackReminder(h, anchor);
      }
    }
  }

  // Brief SnackBar shown on a counted check-in: the identity "vote" line and/or
  // the temptation-bundling reward, whichever the habit has set.
  void _showCheckInFeedback(Habit habit) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final lines = <String>[];
    final identity = habit.identity;
    if (identity != null) lines.add(l10n.identityVoteFeedback(identity));
    final reward = habit.rewardAfter;
    if (reward != null) lines.add(l10n.rewardFeedback(reward));
    if (lines.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(lines.join('\n')),
        duration: const Duration(milliseconds: 1600),
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
    _nameController.clear();
    _timesPerDayController.text = '1';
    _identityController.clear();
    _miniController.clear();
    _rewardController.clear();
    _locationController.clear();
    final afterNotifier = ValueNotifier<String?>(null);
    final intentionNotifier = ValueNotifier<int?>(null);
    final freqUnitNotifier = ValueNotifier<String>('day');
    final l10n = AppLocalizations.of(context);

    await _showHabitSheet(
      title: l10n.newHabit,
      subtitle: l10n.newHabitSubtitle,
      submitLabel: l10n.add,
      showIconPicker: true,
      initialIconIndex: 0,
      initiallyExpandedAtomic: false,
      stackCandidates: _habits,
      identitySuggestions: distinctIdentities(_habits),
      afterNotifier: afterNotifier,
      intentionNotifier: intentionNotifier,
      freqUnitNotifier: freqUnitNotifier,
      onSubmit: (iconIndex) {
        final name = _nameController.text.trim();
        if (name.isEmpty) return false;
        final parsed = int.tryParse(_timesPerDayController.text) ?? 1;
        final times = parsed < 1 ? 1 : parsed;
        final opt = habitIconOptions[iconIndex];
        final unit = freqUnitNotifier.value;
        final newHabit = Habit(
          name: name,
          timesPerDay: times,
          frequencyUnit: unit,
          periodKey: periodKeyFor(unit, DateTime.now()),
          color: opt.color,
          icon: opt.icon,
          identity: _identityController.text,
          miniVersion: _miniController.text,
          afterHabitId: afterNotifier.value,
          rewardAfter: _rewardController.text,
          location: _locationController.text,
          intentionMinutes: intentionNotifier.value,
        );
        setState(() => _habits.add(newHabit));
        _saveHabits();
        _refreshSmartReminders();
        NotificationService().scheduleIntentionReminder(newHabit);
        _checkAchievementsAfterAdd();
        return true;
      },
    );
    afterNotifier.dispose();
    intentionNotifier.dispose();
    freqUnitNotifier.dispose();
  }

  // Shared add/edit form as a BOTTOM SHEET styled after the "new habit" mockup:
  // a paper background with an "essentials" card (icon + name + times/day
  // stepper) on top, then the collapsible "Make it stick" sentence section.
  // Anchors to the bottom, lifts above the keyboard (viewInsets padding),
  // scrolls its body, and pins the action buttons — the whole form is always
  // reachable regardless of the keyboard.
  Future<void> _showHabitSheet({
    required String title,
    String? subtitle,
    required String submitLabel,
    required bool showIconPicker,
    required int initialIconIndex,
    IconData? existingIcon,
    Color? existingColor,
    required bool initiallyExpandedAtomic,
    required List<Habit> stackCandidates,
    required List<String> identitySuggestions,
    required ValueNotifier<String?> afterNotifier,
    required ValueNotifier<int?> intentionNotifier,
    required ValueNotifier<String> freqUnitNotifier,
    required bool Function(int selectedIconIndex) onSubmit,
  }) async {
    int selectedIconIndex = initialIconIndex;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.palette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final l10n = AppLocalizations.of(context);
            final scheme = Theme.of(context).colorScheme;
            final palette = context.palette;
            // Icon/color shown in the essentials square. On add it follows the
            // picked option; on edit it shows the (non-editable) habit icon.
            final opt =
                showIconPicker ? habitIconOptions[selectedIconIndex] : null;
            final dispIcon = opt?.icon ?? existingIcon ?? Icons.check_circle;
            final dispColor =
                opt?.color ?? existingColor ?? palette.accentViolet;
            int timesVal = int.tryParse(_timesPerDayController.text) ?? 1;
            if (timesVal < 1) timesVal = 1;

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle.
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12.5,
                                color:
                                    scheme.onSurfaceVariant.withValues(alpha: .8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Scrollable form body.
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Essentials card ─────────────────────────────
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: palette.card,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: palette.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Icon square (tap to change on add).
                                      _IconSquare(
                                        icon: dispIcon,
                                        color: dispColor,
                                        onTap: showIconPicker
                                            ? () async {
                                                final picked =
                                                    await _pickHabitIcon(
                                                        selectedIconIndex);
                                                if (picked != null) {
                                                  setSheet(() =>
                                                      selectedIconIndex =
                                                          picked);
                                                }
                                              }
                                            : null,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            TextField(
                                              controller: _nameController,
                                              textCapitalization:
                                                  TextCapitalization.sentences,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                                contentPadding:
                                                    EdgeInsets.zero,
                                                hintText: l10n.habitName,
                                              ),
                                            ),
                                            if (showIconPicker)
                                              Text(
                                                l10n.iconChangeHint,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: scheme
                                                      .onSurfaceVariant
                                                      .withValues(alpha: .7),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  // "How often": count stepper + day/week/month
                                  // unit. The label reflects the chosen unit.
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _freqCountLabel(
                                              l10n, freqUnitNotifier.value),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: .4,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      _Stepper(
                                        value: timesVal,
                                        onChanged: (v) {
                                          _timesPerDayController.text =
                                              v.toString();
                                          setSheet(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _FreqUnitSegment(
                                    value: freqUnitNotifier.value,
                                    onChanged: (u) {
                                      freqUnitNotifier.value = u;
                                      setSheet(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            // ── "Make it stick" sentence section ────────────
                            _StickSection(
                              identityController: _identityController,
                              miniController: _miniController,
                              rewardController: _rewardController,
                              locationController: _locationController,
                              intentionMinutes: intentionNotifier,
                              suggestions: identitySuggestions,
                              otherHabits: stackCandidates,
                              afterHabitId: afterNotifier,
                              initiallyExpanded: initiallyExpandedAtomic,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Pinned action buttons (primary = violet CTA).
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(l10n.cancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: palette.accentViolet,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: () {
                                if (onSubmit(selectedIconIndex)) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Text(submitLabel),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Nested bottom sheet: the 24-icon grid. Returns the chosen index (or null if
  // dismissed). Reuses habitIconOptions (icon + coupled color).
  Future<int?> _pickHabitIcon(int current) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.iconLabel,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children:
                      List.generate(habitIconOptions.length, (index) {
                    final isSelected = index == current;
                    final opt = habitIconOptions[index];
                    return Tooltip(
                      message: habitIconLabel(l10n, opt.labelKey),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(index),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? opt.color.withValues(alpha: 0.2)
                                : context.palette.cardAlt,
                            border: Border.all(
                              color: isSelected
                                  ? opt.color
                                  : scheme.outlineVariant,
                              width: isSelected ? 2 : 1,
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
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditHabitDialog(Habit habit,
      {bool expandAtomic = false}) async {
    _nameController.text = habit.name;
    _timesPerDayController.text = habit.timesPerDay.toString();
    _identityController.text = habit.identity ?? '';
    _miniController.text = habit.miniVersion ?? '';
    _rewardController.text = habit.rewardAfter ?? '';
    _locationController.text = habit.location ?? '';
    final afterNotifier = ValueNotifier<String?>(habit.afterHabitId);
    final intentionNotifier = ValueNotifier<int?>(habit.intentionMinutes);
    final freqUnitNotifier = ValueNotifier<String>(habit.frequencyUnit);
    final l10n = AppLocalizations.of(context);
    final others = _habits.where((h) => h != habit).toList();

    await _showHabitSheet(
      title: l10n.editHabit,
      submitLabel: l10n.save,
      // Icon isn't editable (Habit.icon/color are final), so hide the picker
      // but still show the habit's current icon in the essentials square.
      showIconPicker: false,
      initialIconIndex: 0,
      existingIcon: habit.icon,
      existingColor: habit.color,
      initiallyExpandedAtomic: expandAtomic,
      stackCandidates: others,
      identitySuggestions: distinctIdentities(others),
      afterNotifier: afterNotifier,
      intentionNotifier: intentionNotifier,
      freqUnitNotifier: freqUnitNotifier,
      onSubmit: (iconIndex) {
        final name = _nameController.text.trim();
        if (name.isEmpty) return false;
        final parsed = int.tryParse(_timesPerDayController.text) ?? 1;
        final times = parsed < 1 ? 1 : parsed;
        final identity = _identityController.text.trim();
        final mini = _miniController.text.trim();
        final reward = _rewardController.text.trim();
        final location = _locationController.text.trim();
        final unit = freqUnitNotifier.value;
        setState(() {
          habit.name = name;
          habit.timesPerDay = times;
          // Switching the frequency unit starts a fresh period so the counter
          // isn't stranded against a target from the old cadence.
          if (habit.frequencyUnit != unit) {
            habit.frequencyUnit = unit;
            habit.completedTimes = 0;
            habit.periodKey = periodKeyFor(unit, DateTime.now());
          }
          habit.identity = identity.isEmpty ? null : identity;
          habit.miniVersion = mini.isEmpty ? null : mini;
          habit.afterHabitId = afterNotifier.value;
          habit.rewardAfter = reward.isEmpty ? null : reward;
          habit.location = location.isEmpty ? null : location;
          habit.intentionMinutes = intentionNotifier.value;
          if (habit.completedTimes > habit.timesPerDay) {
            habit.completedTimes = habit.timesPerDay;
          }
        });
        _saveHabits();
        _refreshSmartReminders();
        // Re-schedule (or clear) this habit's intention reminder to match the
        // edited time/place.
        NotificationService().scheduleIntentionReminder(habit);
        return true;
      },
    );
    afterNotifier.dispose();
    intentionNotifier.dispose();
    freqUnitNotifier.dispose();
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
                // Drop the deleted habit's implementation-intention reminder.
                NotificationService().cancelIntentionReminder(habit);
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
    _rewardController.dispose();
    _locationController.dispose();
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
                                  onAtomic: () => _showEditHabitDialog(habit,
                                      expandAtomic: true),
                                  onDelete: () => _confirmDeleteHabit(habit),
                                  identityVotes: habit.identity != null
                                      ? votesForIdentity(habit.identity!, _habits)
                                      : 0,
                                  anchorName: _anchorNameFor(habit),
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

// ── "Make it stick" sentence section ─────────────────────────────
// The optional "Atomic Habits" fields, presented as a fill-in-the-blank
// sentence of tappable pills (mockup: navici-create-habit-mockup.html).
// Collapsed by default; each pill opens the appropriate editor (text + chips,
// time picker, or anchor list). Empty pills are dashed "+" placeholders and a
// null value stays valid. No model fields are added here — it only restyles
// the existing controllers/notifiers passed down from the sheet.
class _StickSection extends StatefulWidget {
  const _StickSection({
    required this.identityController,
    required this.miniController,
    required this.rewardController,
    required this.locationController,
    required this.intentionMinutes,
    required this.suggestions,
    required this.otherHabits,
    required this.afterHabitId,
    this.initiallyExpanded = false,
  });

  final TextEditingController identityController;
  final TextEditingController miniController;
  final TextEditingController rewardController;
  final TextEditingController locationController;
  final ValueNotifier<int?> intentionMinutes;
  final List<String> suggestions;
  final List<Habit> otherHabits;
  final ValueNotifier<String?> afterHabitId;
  final bool initiallyExpanded;

  @override
  State<_StickSection> createState() => _StickSectionState();
}

class _StickSectionState extends State<_StickSection> {
  late bool _open = widget.initiallyExpanded;

  void _refresh() {
    if (mounted) setState(() {});
  }

  String? get _anchorName {
    final id = widget.afterHabitId.value;
    if (id == null) return null;
    for (final h in widget.otherHabits) {
      if (h.id == id) return h.name;
    }
    return null;
  }

  // Nested bottom sheet with a text field (+ optional identity chips).
  Future<void> _editText(
    String title,
    TextEditingController controller, {
    String? hint,
    List<String> chips = const [],
  }) async {
    // Bind directly to the caller's controller (owned by HomeScreenState). A
    // throwaway controller disposed right after the await would repeat the
    // ROUND-3 crash (clearComposing on a disposed controller during the sheet's
    // exit). The sheet always commits on close, so there is no cancel to lose.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(hintText: hint),
                      onSubmitted: (_) => Navigator.of(ctx).pop(),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final c in chips)
                            ActionChip(
                              label: Text(c),
                              onPressed: () {
                                controller.text = c;
                                controller.selection =
                                    TextSelection.collapsed(offset: c.length);
                                setLocal(() {});
                              },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.palette.accentViolet,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(l10n.editDone),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    controller.text = controller.text.trim();
    _refresh();
  }

  // Time pill: choose (reuses showTimePicker) or remove.
  Future<void> _editTime() async {
    final l10n = AppLocalizations.of(context);
    final cur = widget.intentionMinutes.value;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(l10n.timePickChoose),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final initial = cur != null
                      ? TimeOfDay(hour: cur ~/ 60, minute: cur % 60)
                      : TimeOfDay.now();
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: initial,
                  );
                  if (picked != null) {
                    widget.intentionMinutes.value =
                        picked.hour * 60 + picked.minute;
                    _refresh();
                  }
                },
              ),
              if (cur != null)
                ListTile(
                  leading: const Icon(Icons.close),
                  title: Text(l10n.timeRemove),
                  onTap: () {
                    widget.intentionMinutes.value = null;
                    Navigator.of(ctx).pop();
                    _refresh();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Anchor pill: pick one of the other habits (keeps ID) or "none".
  Future<void> _editAnchor() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final current = widget.afterHabitId.value;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    l10n.editAnchorTitle,
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                ListTile(
                  title: Text(l10n.stackAfterNone),
                  trailing: current == null
                      ? Icon(Icons.check, color: context.palette.accentViolet)
                      : null,
                  onTap: () {
                    widget.afterHabitId.value = null;
                    Navigator.of(ctx).pop();
                    _refresh();
                  },
                ),
                for (final h in widget.otherHabits)
                  ListTile(
                    title: Text(h.name, overflow: TextOverflow.ellipsis),
                    trailing: current == h.id
                        ? Icon(Icons.check,
                            color: context.palette.accentViolet)
                        : null,
                    onTap: () {
                      widget.afterHabitId.value = h.id;
                      Navigator.of(ctx).pop();
                      _refresh();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final anim =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 250);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.accentGold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.stickTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        l10n.stickSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: anim,
                  child: Icon(Icons.keyboard_arrow_down,
                      color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: anim,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? _sentenceCard(context)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _sentenceCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;

    final identity = widget.identityController.text.trim();
    final place = widget.locationController.text.trim();
    final mini = widget.miniController.text.trim();
    final reward = widget.rewardController.text.trim();
    final mins = widget.intentionMinutes.value;
    final anchor = _anchorName;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line([
              _lead(l10n.sentBecome, scheme),
              _Pill(
                label: identity.isEmpty ? l10n.pillIdentityEmpty : identity,
                kind: _PillKind.gold,
                empty: identity.isEmpty,
                onTap: () => _editText(
                  l10n.editIdentityTitle,
                  widget.identityController,
                  hint: l10n.identityHint,
                  chips: widget.suggestions,
                ),
              ),
            ]),
            _line([
              _lead(l10n.sentWill, scheme),
              // "това" — refers to the habit; deliberately plain, not a pill,
              // so it reads as a sentence and isn't tappable.
              _plain(l10n.pillNameFallback, scheme),
              _plain(l10n.sentInTime, scheme),
              _Pill(
                label: mins != null ? _fmtMinutes(mins) : l10n.pillTimeEmpty,
                kind: _PillKind.violet,
                empty: mins == null,
                onTap: _editTime,
              ),
              _plain(l10n.sentAtPlace, scheme),
              _Pill(
                label: place.isEmpty ? l10n.pillPlaceEmpty : place,
                kind: _PillKind.violet,
                empty: place.isEmpty,
                onTap: () => _editText(
                  l10n.editPlaceTitle,
                  widget.locationController,
                  hint: l10n.intentionPlaceHint,
                ),
              ),
            ]),
            if (widget.otherHabits.isNotEmpty)
              _line([
                _lead(l10n.sentAfter, scheme),
                _Pill(
                  label: anchor ?? l10n.pillAnchorEmpty,
                  kind: _PillKind.violet,
                  empty: anchor == null,
                  onTap: _editAnchor,
                ),
              ]),
            _line([
              _lead(l10n.sentHardDay, scheme),
              _Pill(
                label: mini.isEmpty ? l10n.pillMiniEmpty : mini,
                kind: _PillKind.green,
                empty: mini.isEmpty,
                onTap: () => _editText(
                  l10n.editMiniTitle,
                  widget.miniController,
                  hint: l10n.miniVersionHint,
                ),
              ),
            ]),
            _line([
              _lead(l10n.sentThen, scheme),
              _Pill(
                label: reward.isEmpty ? l10n.pillRewardEmpty : reward,
                kind: _PillKind.violet,
                empty: reward.isEmpty,
                onTap: () => _editText(
                  l10n.editRewardTitle,
                  widget.rewardController,
                  hint: l10n.rewardHint,
                ),
              ),
            ]),
            if (identity.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: palette.accentGoldSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.accentGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.voteBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.voteTagText(identity),
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.accentGold,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              l10n.stickHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: children,
        ),
      );

  Widget _lead(String text, ColorScheme scheme) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: scheme.onSurfaceVariant,
        ),
      );

  Widget _plain(String text, ColorScheme scheme) => Text(
        text,
        style: TextStyle(fontSize: 16, color: scheme.onSurface),
      );
}

enum _PillKind { violet, gold, green }

// A sentence "blank": a filled accent pill when it has a value, or a dashed
// "+" placeholder when empty (a null value stays valid). Tapping opens the
// field's editor.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.kind,
    required this.empty,
    this.onTap,
  });

  final String label;
  final _PillKind kind;
  final bool empty;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final faint = scheme.onSurfaceVariant.withValues(alpha: 0.6);

    if (empty) {
      return GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedRectPainter(color: faint),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            alignment: Alignment.center,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16, color: faint),
                const SizedBox(width: 2),
                Text(label, style: TextStyle(fontSize: 15, color: faint)),
              ],
            ),
          ),
        ),
      );
    }

    late final Color bg;
    late final Color fg;
    switch (kind) {
      case _PillKind.violet:
        bg = palette.accentVioletSoft;
        fg = palette.accentViolet;
        break;
      case _PillKind.gold:
        bg = palette.accentGoldSoft;
        fg = palette.accentGold;
        break;
      case _PillKind.green:
        bg = palette.accentGreenSoft;
        fg = palette.accentGreen;
        break;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: kind == _PillKind.gold
                  ? FontWeight.w700
                  : FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

// The essentials icon in a rounded, soft-tinted square. Tappable on add to open
// the icon picker; static (non-editable) on edit.
class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon, required this.color, this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final square = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, size: 26, color: color),
    );
    if (onTap == null) return square;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: square,
      ),
    );
  }
}

// Compact −/value/+ stepper for timesPerDay (min 1). 44px tap targets.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    Widget btn(IconData ic, VoidCallback? onTap) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              ic,
              size: 20,
              color: onTap == null
                  ? scheme.onSurface.withValues(alpha: 0.25)
                  : scheme.onSurface,
            ),
          ),
        );
    return Material(
      color: palette.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove, value > 1 ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          btn(Icons.add, () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

// Label above the count stepper, worded for the chosen frequency unit.
String _freqCountLabel(AppLocalizations l10n, String unit) {
  switch (unit) {
    case 'week':
      return l10n.freqCountWeek;
    case 'month':
      return l10n.freqCountMonth;
    default:
      return l10n.freqCountDay;
  }
}

// Short period word appended to a habit-row counter for non-daily habits
// (e.g. "2 / 3 седмично"). Empty for daily habits.
String _freqSuffix(AppLocalizations l10n, String unit) {
  switch (unit) {
    case 'week':
      return ' ${l10n.freqWeeklyShort}';
    case 'month':
      return ' ${l10n.freqMonthlyShort}';
    default:
      return '';
  }
}

// Segmented day/week/month picker for a habit's frequency unit, styled like the
// mockup: a muted track with the selected segment raised in the card colour.
class _FreqUnitSegment extends StatelessWidget {
  const _FreqUnitSegment({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final items = <(String, String)>[
      ('day', l10n.freqDay),
      ('week', l10n.freqWeek),
      ('month', l10n.freqMonth),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final (unit, label) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(unit),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unit == value ? palette.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: unit == value
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: unit == value
                          ? palette.accentViolet
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Dashed rounded-rect border for the empty ("+") pills.
class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;
  static const double radius = 11;
  static const double dash = 4;
  static const double gap = 3;
  static const double strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final source = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final remaining = metric.length - d;
        final len = remaining < dash ? remaining : dash;
        dashed.addPath(metric.extractPath(d, d + len), Offset.zero);
        d += dash + gap;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => old.color != color;
}

// Formats minutes-since-midnight as a zero-padded HH:mm clock time.
String _fmtMinutes(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

class HabitRow extends StatelessWidget {
  const HabitRow({
    super.key,
    required this.habit,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onDelete,
    required this.onAtomic,
    this.identityVotes = 0,
    this.anchorName,
  });

  final Habit habit;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  // Opens the edit dialog with the "Atomic Habits" section expanded.
  final VoidCallback onAtomic;
  // Live-computed votes for this habit's identity (sum across matching habits).
  final int identityVotes;
  // Resolved name of the stacking anchor, or null if none / anchor deleted.
  final String? anchorName;

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
                            '${habit.completedTimes} / ${habit.timesPerDay}'
                            '${_freqSuffix(l10n, habit.frequencyUnit)}',
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
                      // "След „anchor“" — habit stacking link (only when the
                      // anchor still exists).
                      if (anchorName != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          l10n.stackAfterCard(anchorName!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // "🎁 Награда: …" — temptation bundling reward, shown on
                      // the card only when a reward is set.
                      if (habit.rewardAfter != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          l10n.rewardCard(habit.rewardAfter!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // "🕒 в HH:mm · място" — implementation intention time
                      // (and place), shown when a time is set.
                      if (habit.intentionMinutes != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          habit.location != null
                              ? l10n.intentionCardPlace(
                                  _fmtMinutes(habit.intentionMinutes!),
                                  habit.location!)
                              : l10n.intentionCard(
                                  _fmtMinutes(habit.intentionMinutes!)),
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
                    else if (value == 'atomic') onAtomic();
                    else if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text(l10n.editMenu)),
                    PopupMenuItem(
                      value: 'atomic',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(l10n.atomicMenu),
                        ],
                      ),
                    ),
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

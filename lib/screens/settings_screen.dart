import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/backup_service.dart';
import '../services/habit_service.dart';
import '../services/music_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../services/theme_service.dart';
import '../widgets/music_toggle_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _displayName = 'Habit User';
  bool _notificationsEnabled = true;
  bool _smartEnabled = true;
  bool _smartSilent = false;
  bool _streakGrace = true;
  TimeOfDay _dailyTime = const TimeOfDay(hour: 20, minute: 0);
  bool _isAdFree = false;

  final _nameCtrl = TextEditingController(text: 'Habit User');

  @override
  void initState() {
    super.initState();
    _load();
    PurchaseService.instance.adFreeNotifier.addListener(_onAdFreeChanged);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(kPrefsProfile);

    String name = _displayName;
    bool notif = true;
    bool smart = true;
    bool silent = false;
    bool grace = true;
    TimeOfDay time = _dailyTime;

    if (jsonStr != null) {
      try {
        final d = jsonDecode(jsonStr) as Map<String, dynamic>;
        name = d['name'] as String? ?? name;
        notif = d['notificationsEnabled'] as bool? ?? notif;
        smart = d['smartRemindersEnabled'] as bool? ?? smart;
        silent = d['smartRemindersSilent'] as bool? ?? silent;
        grace = d['streakGraceEnabled'] as bool? ?? grace;
        final h = (d['hour'] as num?)?.toInt() ?? time.hour;
        final m = (d['minute'] as num?)?.toInt() ?? time.minute;
        time = TimeOfDay(hour: h, minute: m);
      } catch (_) {}
    }

    setState(() {
      _displayName = name;
      _notificationsEnabled = notif;
      _smartEnabled = smart;
      _smartSilent = silent;
      _streakGrace = grace;
      _dailyTime = time;
      _nameCtrl.text = name;
      _isAdFree = PurchaseService.instance.isAdFree;
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kPrefsProfile,
      jsonEncode({
        'name': _displayName,
        'notificationsEnabled': _notificationsEnabled,
        'smartRemindersEnabled': _smartEnabled,
        'smartRemindersSilent': _smartSilent,
        'streakGraceEnabled': _streakGrace,
        'hour': _dailyTime.hour,
        'minute': _dailyTime.minute,
      }),
    );
  }

  Future<void> _editName() async {
    final l10n = AppLocalizations.of(context);
    _nameCtrl.text = _displayName;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.yourName),
        content: TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(labelText: l10n.nickname),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              final t = _nameCtrl.text.trim();
              if (t.isNotEmpty) {
                setState(() => _displayName = t);
                _saveProfile();
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _dailyTime);
    if (picked != null) {
      setState(() => _dailyTime = picked);
      _saveProfile();
    }
  }

  Future<void> _applyNotifications() async {
    if (_notificationsEnabled) {
      await NotificationService().scheduleDailyReminderAt(_dailyTime);
    } else {
      await NotificationService().cancelDailyReminder();
    }
    await _saveProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).remindersUpdated)),
    );
  }

  /// Persists the chosen language, applies it app-wide, and reschedules
  /// notifications so their text switches to the new language too.
  Future<void> _onLanguageChanged(String code) async {
    await saveLocalePreference(code);
    if (_notificationsEnabled) {
      await NotificationService().scheduleDailyReminderAt(_dailyTime);
    }
    final habits = await HabitService.loadHabits();
    await NotificationService().cancelSmartReminders();
    if (_smartEnabled) {
      await NotificationService().scheduleSmartRemindersForToday(habits);
    }
    if (mounted) setState(() {});
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    PurchaseService.instance.adFreeNotifier.removeListener(_onAdFreeChanged);
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onAdFreeChanged() {
    if (mounted) {
      setState(() => _isAdFree = PurchaseService.instance.isAdFree);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        centerTitle: true,
        actions: const [MusicToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _Section(
            label: l10n.sectionProfile,
            child: _profileTile(),
          ),
          _Section(
            label: l10n.sectionAds,
            child: _premiumCard(),
          ),
          _Section(
            label: l10n.sectionAppearance,
            child: _themeSelector(),
          ),
          _Section(
            label: l10n.sectionLanguage,
            child: _languageSelector(),
          ),
          _Section(
            label: l10n.sectionReminders,
            child: _notificationsSection(),
          ),
          _Section(
            label: l10n.sectionStreak,
            child: _streakSection(),
          ),
          _Section(
            label: l10n.sectionMusic,
            child: _musicSection(),
          ),
          _Section(
            label: l10n.sectionData,
            child: _dataSection(),
          ),
          _Section(
            label: l10n.sectionInfo,
            child: _infoSection(),
          ),
        ],
      ),
    );
  }

  // ── Language selector ────────────────────────────────────────────
  Widget _languageSelector() {
    final l10n = AppLocalizations.of(context);
    final current = localeNotifier.value.languageCode;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        segments: [
          ButtonSegment(value: 'bg', label: Text('🇧🇬 ${l10n.languageBulgarian}')),
          ButtonSegment(value: 'en', label: Text('🇬🇧 ${l10n.languageEnglish}')),
        ],
        selected: {current},
        onSelectionChanged: (s) => _onLanguageChanged(s.first),
      ),
    );
  }

  // ── Profile ──────────────────────────────────────────────────────
  Widget _profileTile() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: 0.35),
                scheme.tertiary.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                _isAdFree ? l10n.profileAdFree : l10n.profileFreePlan,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isAdFree
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _editName,
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.editTooltip,
        ),
      ],
    );
  }

  // ── Ads card ─────────────────────────────────────────────────────
  Widget _premiumCard() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final price = PurchaseService.instance.removeAdsPrice;
    if (_isAdFree) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              scheme.secondary.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.adsRemovedTitle,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: scheme.primary),
                  ),
                  Text(
                    l10n.adsRemovedThanks,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('☕', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.adFreeShort,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.adsRemoveSupport,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _removeAds,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              // Show the real store price when it has loaded (e.g. "· 1,99 €").
              price == null
                  ? l10n.removeAdsCoffee
                  : '${l10n.removeAdsCoffee} · $price',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        // Non-consumable purchases must be restorable on a new device /
        // reinstall — Google Play policy requires an explicit way to do it.
        Center(
          child: TextButton(
            onPressed: _restorePurchases,
            child: Text(l10n.restorePurchasesBtn),
          ),
        ),
      ],
    );
  }

  Future<void> _removeAds() async {
    final started = await PurchaseService.instance.buyRemoveAds();
    if (!mounted || started) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).purchaseUnavailable),
      ),
    );
  }

  Future<void> _restorePurchases() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.restoreChecking)));
    // Fire the restore; a recovered purchase arrives on the purchase stream and
    // flips adFreeNotifier, which _onAdFreeChanged already listens to and uses
    // to rebuild this card into the "ads removed" state.
    await PurchaseService.instance.restore();
  }

  // ── Music ────────────────────────────────────────────────────────
  Widget _musicSection() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.musicHint,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.sleepTimer,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: MusicService.instance.sleepMinutes,
          builder: (context, mins, _) => Wrap(
            spacing: 8,
            children: [0, 10, 20, 30].map((m) {
              return ChoiceChip(
                label: Text(m == 0 ? l10n.timerOff : l10n.timerMinutes(m)),
                selected: mins == m,
                onSelected: (_) => MusicService.instance.setSleepTimer(m),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Streak ───────────────────────────────────────────────────────
  Widget _streakSection() {
    final l10n = AppLocalizations.of(context);
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: _streakGrace,
      onChanged: (v) {
        setState(() => _streakGrace = v);
        _saveProfile();
      },
      title: Text(l10n.streakFreeze),
      subtitle: Text(l10n.streakFreezeSub),
    );
  }

  // ── Data (backup / restore) ──────────────────────────────────────
  Widget _dataSection() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dataHint,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _exportBackup,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(l10n.backupBtn),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _importBackup,
            icon: const Icon(Icons.download, size: 18),
            label: Text(l10n.restoreBtn),
          ),
        ),
      ],
    );
  }

  Future<void> _exportBackup() async {
    final l10n = AppLocalizations.of(context);
    try {
      final json = await BackupService.exportJson();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: l10n.saveBackupDialog,
        fileName: BackupService.suggestedFileName(),
        type: FileType.any,
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupSaved)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupError)),
      );
    }
  }

  Future<void> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    // Validate (no writes yet) so we can warn/confirm before replacing data.
    BackupResult parsed;
    try {
      final content = await File(path).readAsString();
      parsed = BackupService.validate(content);
    } catch (_) {
      parsed = const BackupResult(BackupStatus.invalid);
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (parsed.status == BackupStatus.tooNew) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.restoreTooNew)));
      return;
    }
    if (parsed.status != BackupStatus.ok || parsed.data == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.restoreInvalid)));
      return;
    }

    // Explicit confirmation — restoring overwrites all current data.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: Text(l10n.restoreConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.restoreReplace),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await BackupService.apply(parsed.data!);
    if (!mounted) return;
    // Restart the widget tree so every screen reloads from the imported data.
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    messenger.showSnackBar(SnackBar(content: Text(l10n.restoreSuccess)));
  }

  // ── Theme selector ───────────────────────────────────────────────
  Widget _themeSelector() {
    // Read directly — outer ValueListenableBuilder in HabitApp handles rebuilds.
    // Icons are intentionally omitted so all three labels fit on narrow screens.
    final mode = themeNotifier.value;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        segments: [
          ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
          ButtonSegment(value: ThemeMode.system, label: Text(l10n.themeAuto)),
          ButtonSegment(value: ThemeMode.light, label: Text(l10n.themeLight)),
        ],
        selected: {mode},
        onSelectionChanged: (s) {
          saveThemePreference(s.first);
          setState(() {});
        },
      ),
    );
  }

  // ── Notifications ────────────────────────────────────────────────
  Widget _notificationsSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _notificationsEnabled,
          onChanged: (v) {
            setState(() => _notificationsEnabled = v);
            _saveProfile();
          },
          title: Text(l10n.dailyReminder),
          subtitle: Text(l10n.dailyReminderSub),
        ),
        if (_notificationsEnabled)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.reminderTime),
            subtitle: Text(_fmt(_dailyTime)),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: _pickTime,
          ),
        const Divider(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _smartEnabled,
          onChanged: (v) {
            setState(() => _smartEnabled = v);
            _saveProfile();
          },
          title: Text(l10n.smartReminders),
          subtitle: Text(l10n.smartRemindersSub),
        ),
        if (_smartEnabled)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _smartSilent,
            onChanged: (v) {
              setState(() => _smartSilent = v);
              _saveProfile();
            },
            title: Text(l10n.silent),
            subtitle: Text(l10n.silentSub),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _applyNotifications,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(l10n.save),
        ),
      ],
    );
  }

  // ── Info ─────────────────────────────────────────────────────────
  Widget _infoSection() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.version),
            Text('1.1.0',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
        const Divider(height: 20),
        Text(
          l10n.infoTagline,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

}

// ── Section wrapper ───────────────────────────────────────────────
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 5),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.palette.border),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

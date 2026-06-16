import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/habit_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../services/theme_service.dart';
import 'paywall_screen.dart';

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
  TimeOfDay _dailyTime = const TimeOfDay(hour: 20, minute: 0);
  String _language = 'bg';
  bool _isPremium = false;

  final _nameCtrl = TextEditingController(text: 'Habit User');

  static const _languages = [
    ('bg', '🇧🇬 Български'),
    ('en', '🇬🇧 English'),
    ('de', '🇩🇪 Deutsch'),
    ('fr', '🇫🇷 Français'),
    ('it', '🇮🇹 Italiano'),
    ('el', '🇬🇷 Ελληνικά'),
    ('es', '🇪🇸 Español'),
    ('pt', '🇵🇹 Português'),
    ('ru', '🇷🇺 Русский'),
    ('tr', '🇹🇷 Türkçe'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(kPrefsProfile);
    final lang = prefs.getString('language') ?? 'bg';

    String name = _displayName;
    bool notif = true;
    bool smart = true;
    bool silent = false;
    TimeOfDay time = _dailyTime;

    if (jsonStr != null) {
      try {
        final d = jsonDecode(jsonStr) as Map<String, dynamic>;
        name = d['name'] as String? ?? name;
        notif = d['notificationsEnabled'] as bool? ?? notif;
        smart = d['smartRemindersEnabled'] as bool? ?? smart;
        silent = d['smartRemindersSilent'] as bool? ?? silent;
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
      _dailyTime = time;
      _nameCtrl.text = name;
      _language = lang;
      _isPremium = PurchaseService.instance.isPremium;
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
        'hour': _dailyTime.hour,
        'minute': _dailyTime.minute,
      }),
    );
  }

  Future<void> _editName() async {
    _nameCtrl.text = _displayName;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Твоето име'),
        content: TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Псевдоним'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отказ')),
          FilledButton(
            onPressed: () {
              final t = _nameCtrl.text.trim();
              if (t.isNotEmpty) {
                setState(() => _displayName = t);
                _saveProfile();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Запази'),
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
      const SnackBar(content: Text('Напомнянията са обновени.')),
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _openPaywall() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    if (ok == true && mounted) setState(() => _isPremium = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            label: 'Профил',
            child: _profileTile(),
          ),
          _Section(
            label: 'Абонамент',
            child: _premiumCard(),
          ),
          _Section(
            label: 'Визия',
            child: _themeSelector(),
          ),
          _Section(
            label: 'Език',
            child: _languageSelector(),
          ),
          _Section(
            label: 'Напомняния',
            child: _notificationsSection(),
          ),
          _Section(
            label: 'Информация',
            child: _infoSection(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Profile ──────────────────────────────────────────────────────
  Widget _profileTile() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                scheme.primary.withOpacity(0.35),
                scheme.tertiary.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.person, color: Colors.white),
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
                _isPremium ? '✨ Premium' : 'Безплатен план',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isPremium
                          ? const Color(0xFF00E5FF)
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _editName,
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Промени',
        ),
      ],
    );
  }

  // ── Premium card ─────────────────────────────────────────────────
  Widget _premiumCard() {
    if (_isPremium) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00E5FF).withOpacity(0.10),
              const Color(0xFF2979FF).withOpacity(0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
        ),
        child: const Row(
          children: [
            Text('✨', style: TextStyle(fontSize: 22)),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium активен',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00E5FF)),
                  ),
                  Text(
                    'Всички функции са отключени',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
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
        const Row(
          children: [
            Text('💎', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'Habits Premium',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Неограничени навици · Всички шаблони · XP · Статистика',
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _openPaywall,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Вземи Premium',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // ── Theme selector ───────────────────────────────────────────────
  Widget _themeSelector() {
    // Read directly — outer ValueListenableBuilder in HabitApp handles rebuilds
    final mode = themeNotifier.value;
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Тъмна'),
          icon: Icon(Icons.dark_mode_outlined, size: 15),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('Авто'),
          icon: Icon(Icons.brightness_auto_outlined, size: 15),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Светла'),
          icon: Icon(Icons.light_mode_outlined, size: 15),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (s) {
        saveThemePreference(s.first);
        setState(() {});
      },
    );
  }

  // ── Language selector ────────────────────────────────────────────
  Widget _languageSelector() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _language,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: _languages
              .map((l) =>
                  DropdownMenuItem(value: l.$1, child: Text(l.$2)))
              .toList(),
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _language = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('language', v);
            if (v != 'bg' && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Повече езици — очаквайте скоро!')),
              );
            }
          },
        ),
        if (_language != 'bg')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'В момента само Български е наличен.',
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  // ── Notifications ────────────────────────────────────────────────
  Widget _notificationsSection() {
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
          title: const Text('Ежедневно напомняне'),
          subtitle: const Text('Фиксиран час всеки ден'),
        ),
        if (_notificationsEnabled)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Час'),
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
          title: const Text('Smart напомняния'),
          subtitle: const Text(
              'Проследява прогреса — напомня само при нужда (09:00 / 14:00 / 19:30)'),
        ),
        if (_smartEnabled)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _smartSilent,
            onChanged: (v) {
              setState(() => _smartSilent = v);
              _saveProfile();
            },
            title: const Text('Без звук'),
            subtitle: const Text('Smart напомняния — без звук и вибрация'),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _applyNotifications,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Запази'),
        ),
      ],
    );
  }

  // ── Info ─────────────────────────────────────────────────────────
  Widget _infoSection() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Версия'),
            Text('1.0.0',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
        const Divider(height: 20),
        InkWell(
          onTap: _showPromoCodeDialog,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.redeem_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Text('Промо код',
                    style: TextStyle(color: scheme.onSurface)),
                const Spacer(),
                Icon(Icons.chevron_right,
                    size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Habits — tracker за навици с XP, постижения, smart напомняния и Pomodoro.',
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }

  Future<void> _showPromoCodeDialog() async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Промо код'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Въведи код',
            hintText: 'напр. PREMIUM',
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отказ'),
          ),
          FilledButton(
            onPressed: () async {
              final code = ctrl.text.trim().toUpperCase();
              Navigator.pop(ctx);
              await _applyPromoCode(code);
            },
            child: const Text('Активирай'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  Future<void> _applyPromoCode(String code) async {
    const validCodes = {'PREMIUM', 'HABITS2025', 'BETA'};
    if (!mounted) return;
    if (validCodes.contains(code)) {
      await PurchaseService.instance.debugUnlock();
      setState(() => _isPremium = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Premium активиран!'),
          backgroundColor: Color(0xFF1A2E1A),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Невалиден код.')),
      );
    }
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
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111318),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A2D36)),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

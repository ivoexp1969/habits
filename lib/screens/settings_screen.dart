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
  bool _isPremium = false;

  final _nameCtrl = TextEditingController(text: 'Habit User');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(kPrefsProfile);

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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
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
            label: 'Напомняния',
            child: _notificationsSection(),
          ),
          _Section(
            label: 'Информация',
            child: _infoSection(),
          ),
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
                _isPremium ? '✨ Premium' : 'Безплатен план',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isPremium
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
          tooltip: 'Промени',
        ),
      ],
    );
  }

  // ── Premium card ─────────────────────────────────────────────────
  Widget _premiumCard() {
    final scheme = Theme.of(context).colorScheme;
    if (_isPremium) {
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
                    'Premium активен',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: scheme.primary),
                  ),
                  Text(
                    'Всички функции са отключени',
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
            const Text('💎', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'Habits Premium',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: scheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Неограничени навици · Всички шаблони · XP · Статистика',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _openPaywall,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
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
    // Read directly — outer ValueListenableBuilder in HabitApp handles rebuilds.
    // Icons are intentionally omitted so all three labels fit on narrow screens.
    final mode = themeNotifier.value;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        segments: const [
          ButtonSegment(value: ThemeMode.dark, label: Text('Тъмна')),
          ButtonSegment(value: ThemeMode.system, label: Text('Авто')),
          ButtonSegment(value: ThemeMode.light, label: Text('Светла')),
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
        if (!_isPremium) ...[
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
                  Text('Промокод',
                      style: TextStyle(color: scheme.onSurface)),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
        const Divider(height: 20),
        Text(
          'Habits — tracker за навици с XP, постижения и smart напомняния.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  // ── Promo code (lifetime unlock) ─────────────────────────────────
  Future<void> _showPromoCodeDialog() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _PromoCodeDialog(),
    );
    if (code != null && code.isNotEmpty) {
      await _redeemCode(code);
    }
  }

  Future<void> _redeemCode(String code) async {
    final ok = await PurchaseService.instance.redeemPromoCode(code);
    if (!mounted) return;
    if (ok) {
      setState(() => _isPremium = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✨ Lifetime Premium активиран!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Невалиден код.')),
      );
    }
  }
}

// ── Promo code dialog ─────────────────────────────────────────────
// Owns its own TextEditingController so it is disposed only after the
// dialog route fully unmounts. Disposing the controller right after
// `showDialog` returns crashes: the exit animation still drops focus,
// and EditableText.clearComposing then writes to a disposed controller.
class _PromoCodeDialog extends StatefulWidget {
  const _PromoCodeDialog();

  @override
  State<_PromoCodeDialog> createState() => _PromoCodeDialogState();
}

class _PromoCodeDialogState extends State<_PromoCodeDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Промокод'),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          labelText: 'Въведи код',
          hintText: 'напр. XXXX',
        ),
        textCapitalization: TextCapitalization.characters,
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отказ'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Активирай'),
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

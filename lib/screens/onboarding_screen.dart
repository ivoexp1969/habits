import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/habit_templates.dart';
import '../l10n/app_localizations.dart';
import '../services/habit_service.dart';
import '../services/theme_service.dart';
import '../services/xp_service.dart';

const String kPrefsOnboarded = 'onboarded';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  final TextEditingController _nameCtrl = TextEditingController();
  String? _selectedTemplateId;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 3) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish({String? templateId}) async {
    final prefs = await SharedPreferences.getInstance();

    // Save profile name
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) {
      final existing = prefs.getString(kPrefsProfile);
      Map<String, dynamic> profile = {};
      if (existing != null) {
        try {
          profile = jsonDecode(existing) as Map<String, dynamic>;
        } catch (_) {}
      }
      profile['name'] = name;
      await prefs.setString(kPrefsProfile, jsonEncode(profile));
    }

    // Load template habits
    final tid = templateId ?? _selectedTemplateId;
    if (tid != null) {
      final tmpl = habitTemplates.firstWhere(
        (t) => t.id == tid,
        orElse: () => habitTemplates.first,
      );
      final habits = tmpl.buildHabits();
      await prefs.setString(
        kPrefsHabits,
        jsonEncode(habits.map((h) => h.toJson()).toList()),
      );
    }

    await prefs.setBool(kPrefsOnboarded, true);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Dots indicator
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i ? scheme.primary : palette.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _Page1(),
                  _Page2(),
                  _Page3(nameCtrl: _nameCtrl),
                  _Page4(
                    selectedId: _selectedTemplateId,
                    onSelect: (id) => setState(() => _selectedTemplateId = id),
                  ),
                ],
              ),
            ),
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _page < 3
                  ? SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          l10n.next,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _finish(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.onSurfaceVariant,
                              side: BorderSide(color: palette.border),
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(l10n.skip),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _selectedTemplateId != null
                                ? () => _finish()
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              l10n.start,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 1: Welcome ─────────────────────────────────────────────
class _Page1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [scheme.primary, const Color(0xFF7B1FA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome,
                size: 52, color: Colors.white),
          ),
          const SizedBox(height: 36),
          Text(
            'Habits',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.onboardTagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: scheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          _FeatureRow(Icons.track_changes, l10n.onboardFeature1),
          const SizedBox(height: 12),
          _FeatureRow(Icons.local_fire_department, l10n.onboardFeature2),
          const SizedBox(height: 12),
          _FeatureRow(Icons.workspace_premium, l10n.onboardFeature3),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ── Page 2: Progress Preview ─────────────────────────────────────
class _Page2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Text(
            l10n.onboardTrackTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.onboardTrackSub,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 36),
          // Mock progress card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.todayProgress,
                        style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13)),
                    Text('78%',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        )),
                  ],
                ),
                const SizedBox(height: 10),
                const GradientProgressBar(value: 0.78, height: 10),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MiniStat('🔥', '12', l10n.miniStatDays),
                    _MiniStat('⚡', l10n.levelShort(7), levelTitle(l10n, 8)),
                    _MiniStat('🏆', '3/6', l10n.miniStatAchievements),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Mini calendar preview
          _MiniCalendar(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.emoji, this.value, this.label);
  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        Text(label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
      ],
    );
  }
}

class _MiniCalendar extends StatelessWidget {
  final List<Color?> _colors = const [
    Color(0xFF2E7D32), Color(0xFF2E7D32), Color(0xFFF9A825),
    Color(0xFF2E7D32), Color(0xFFC62828), Color(0xFF2E7D32),
    Color(0xFF2E7D32),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (i) {
        final color = _colors[i] ?? Colors.transparent;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.8)),
          ),
          child: Icon(Icons.check, size: 16, color: color),
        );
      }),
    );
  }
}

// ── Page 3: Name ─────────────────────────────────────────────────
class _Page3 extends StatelessWidget {
  const _Page3({required this.nameCtrl});
  final TextEditingController nameCtrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        32,
        32,
        32,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.3),
                  const Color(0xFF7B1FA2).withValues(alpha: 0.5),
                ],
              ),
            ),
            child: const Icon(Icons.person, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.onboardNameTitle,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardNameSub,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: nameCtrl,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: scheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: l10n.yourNameHint,
              hintStyle: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.4)),
              filled: true,
              fillColor: palette.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.canSkip,
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Page 4: Template Selection ────────────────────────────────────
class _Page4 extends StatelessWidget {
  const _Page4({required this.selectedId, required this.onSelect});
  final String? selectedId;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            l10n.onboardPackTitle,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.onboardPackSub,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            // Clamp text scaling so a large system font can't overflow these
            // fixed-ratio cards.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.0,
              child: GridView.builder(
              itemCount: habitTemplates.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (ctx, i) {
                final t = habitTemplates[i];
                final isSelected = t.id == selectedId;
                return GestureDetector(
                  onTap: () => onSelect(t.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? t.color.withValues(alpha: 0.15)
                          : palette.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? t.color : palette.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: t.color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(t.icon, size: 26, color: t.color),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          templateName(l10n, t.id),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          templateDescription(l10n, t.id),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 11),
                        ),
                        const Spacer(),
                        Text(
                          l10n.nHabits(t.buildHabits().length),
                          style: TextStyle(
                            color: t.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ),
          ),
        ],
      ),
    );
  }
}

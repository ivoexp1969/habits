import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

/// Active app language. Mirrors [themeNotifier]: a single source of truth the
/// UI listens to, persisted under the `language` pref. Only `bg` / `en`.
final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('bg'));

/// Loads the saved language, or on first launch picks the device language when
/// it is Bulgarian, otherwise English.
Future<void> loadLocalePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString('language');
  if (stored == 'bg' || stored == 'en') {
    localeNotifier.value = Locale(stored!);
    return;
  }
  final systemCode = ui.PlatformDispatcher.instance.locale.languageCode;
  localeNotifier.value = Locale(systemCode == 'bg' ? 'bg' : 'en');
}

Future<void> saveLocalePreference(String code) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('language', code);
  localeNotifier.value = Locale(code);
}

/// Semantic surface colors shared by the custom (non-Material) containers
/// across the app. Defined once per brightness so every screen adapts when
/// the theme changes. Text colors use `colorScheme.onSurface` (with opacity)
/// and accents use `colorScheme.primary`, so they are NOT duplicated here.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.backgroundAlt,
    required this.card,
    required this.cardAlt,
    required this.surfaceMuted,
    required this.border,
    required this.accentViolet,
    required this.accentVioletSoft,
    required this.accentGold,
    required this.accentGoldSoft,
    required this.accentGreen,
    required this.accentGreenSoft,
  });

  final Color background;
  final Color backgroundAlt;
  final Color card;
  final Color cardAlt;
  final Color surfaceMuted;
  final Color border;
  // "Atomic Habits" sentence accents. Each has a strong tone (text/icon) and a
  // soft tone (pill/tag background). Light values are the brand tokens; dark
  // values are lightened text tones on deep-tinted surfaces so they read on the
  // dark card (#111318). violet = default, gold = identity, green = vote/mini.
  final Color accentViolet;
  final Color accentVioletSoft;
  final Color accentGold;
  final Color accentGoldSoft;
  final Color accentGreen;
  final Color accentGreenSoft;

  static const dark = AppPalette(
    background: Color(0xFF050608),
    backgroundAlt: Color(0xFF090B10),
    card: Color(0xFF111318),
    cardAlt: Color(0xFF18191F),
    surfaceMuted: Color(0xFF1A1E24),
    border: Color(0xFF2A2D36),
    accentViolet: Color(0xFFB9A9F0),
    accentVioletSoft: Color(0xFF262041),
    accentGold: Color(0xFFE1B052),
    accentGoldSoft: Color(0xFF302713),
    accentGreen: Color(0xFF55CE9C),
    accentGreenSoft: Color(0xFF15291F),
  );

  static const light = AppPalette(
    background: Color(0xFFF7F5F0),
    backgroundAlt: Color(0xFFE7ECF3),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF6F8FB),
    surfaceMuted: Color(0xFFEAEEF4),
    border: Color(0xFFECE8F1),
    accentViolet: Color(0xFF5A4A9F),
    accentVioletSoft: Color(0xFFEFEAFB),
    accentGold: Color(0xFFA97511),
    accentGoldSoft: Color(0xFFFBF0D8),
    accentGreen: Color(0xFF2F9E77),
    accentGreenSoft: Color(0xFFE4F4EC),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? backgroundAlt,
    Color? card,
    Color? cardAlt,
    Color? surfaceMuted,
    Color? border,
    Color? accentViolet,
    Color? accentVioletSoft,
    Color? accentGold,
    Color? accentGoldSoft,
    Color? accentGreen,
    Color? accentGreenSoft,
  }) {
    return AppPalette(
      background: background ?? this.background,
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      card: card ?? this.card,
      cardAlt: cardAlt ?? this.cardAlt,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      accentViolet: accentViolet ?? this.accentViolet,
      accentVioletSoft: accentVioletSoft ?? this.accentVioletSoft,
      accentGold: accentGold ?? this.accentGold,
      accentGoldSoft: accentGoldSoft ?? this.accentGoldSoft,
      accentGreen: accentGreen ?? this.accentGreen,
      accentGreenSoft: accentGreenSoft ?? this.accentGreenSoft,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      backgroundAlt: Color.lerp(backgroundAlt, other.backgroundAlt, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardAlt: Color.lerp(cardAlt, other.cardAlt, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accentViolet: Color.lerp(accentViolet, other.accentViolet, t)!,
      accentVioletSoft:
          Color.lerp(accentVioletSoft, other.accentVioletSoft, t)!,
      accentGold: Color.lerp(accentGold, other.accentGold, t)!,
      accentGoldSoft: Color.lerp(accentGoldSoft, other.accentGoldSoft, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      accentGreenSoft: Color.lerp(accentGreenSoft, other.accentGreenSoft, t)!,
    );
  }
}

/// Shorthand: `context.palette.card`, `context.scheme.primary`.
extension ThemeAccess on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
  ColorScheme get scheme => Theme.of(this).colorScheme;
}

/// Vibrant multi-color progress bar used across the app instead of the flat
/// Material `LinearProgressIndicator`. The fill animates and uses fixed
/// fully-saturated brand colors (cyan→purple→pink) with a strong glow, so it
/// stays punchy in BOTH light and dark themes (the light ColorScheme's
/// secondary/tertiary are pale M3 pastels, hence the fixed palette).
class GradientProgressBar extends StatelessWidget {
  const GradientProgressBar({
    super.key,
    required this.value,
    this.height = 12,
    this.colors,
  });

  /// Fully-saturated brand gradient — intentionally theme-independent.
  static const brandColors = [
    Color(0xFF00E5FF), // cyan
    Color(0xFF7C4DFF), // purple
    Color(0xFFFF2D95), // hot pink
  ];

  final double value;
  final double height;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = colors ?? brandColors;
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(
            height: height,
            color: scheme.onSurface.withValues(alpha: 0.10),
          ),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            widthFactor: v == 0 ? 0.0001 : v,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(colors: c),
                boxShadow: [
                  BoxShadow(
                    color: c.first.withValues(alpha: 0.7),
                    blurRadius: 12,
                    spreadRadius: -1,
                  ),
                  BoxShadow(
                    color: c.last.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: -1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString('theme_mode') ?? 'dark';
  themeNotifier.value = switch (stored) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}

Future<void> saveThemePreference(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
    _ => 'dark',
  });
  themeNotifier.value = mode;
}

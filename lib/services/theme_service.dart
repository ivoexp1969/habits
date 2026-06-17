import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

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
  });

  final Color background;
  final Color backgroundAlt;
  final Color card;
  final Color cardAlt;
  final Color surfaceMuted;
  final Color border;

  static const dark = AppPalette(
    background: Color(0xFF050608),
    backgroundAlt: Color(0xFF090B10),
    card: Color(0xFF111318),
    cardAlt: Color(0xFF18191F),
    surfaceMuted: Color(0xFF1A1E24),
    border: Color(0xFF2A2D36),
  );

  static const light = AppPalette(
    background: Color(0xFFF2F4F8),
    backgroundAlt: Color(0xFFE7ECF3),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF6F8FB),
    surfaceMuted: Color(0xFFEAEEF4),
    border: Color(0xFFD7DCE5),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? backgroundAlt,
    Color? card,
    Color? cardAlt,
    Color? surfaceMuted,
    Color? border,
  }) {
    return AppPalette(
      background: background ?? this.background,
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      card: card ?? this.card,
      cardAlt: cardAlt ?? this.cardAlt,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
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
    );
  }
}

/// Shorthand: `context.palette.card`, `context.scheme.primary`.
extension ThemeAccess on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
  ColorScheme get scheme => Theme.of(this).colorScheme;
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

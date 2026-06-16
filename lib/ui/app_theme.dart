import 'package:flutter/material.dart';

/// Централизиран дизайн (dark-first), без “магически” стилове разхвърляни из екрани.
///
/// Ползване:
///   theme: AppTheme.lightTheme
///   darkTheme: AppTheme.darkTheme
class AppTheme {
  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00E5FF),
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF050608),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111318),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(scheme.outlineVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceVariant,
        contentTextStyle: TextStyle(color: scheme.onSurfaceVariant),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.35),
        thickness: 1,
        space: 1,
      ),
      textTheme: _textTheme(scheme),
    );
  }

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4CAF50),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: _textTheme(scheme),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    return const TextTheme(
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.35),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.35),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2),
    ).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
  }
}

class Insets {
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
}

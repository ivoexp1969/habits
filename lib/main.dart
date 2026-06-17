import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/habit.dart';
import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'services/habit_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  // android_alarm_manager_plus is Android-only — calling it on iOS throws
  // MissingPluginException at startup. The lazy reset below is the iOS path.
  if (Platform.isAndroid) {
    await AndroidAlarmManager.initialize();
    await scheduleNextMidnightAlarm();
  }
  await loadThemePreference();
  await PurchaseService.instance.init();
  await maybeResetForNewDay();
  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool(kPrefsOnboarded) ?? false;
  runApp(HabitApp(onboarded: onboarded));
}

/// Cross-platform "lazy" daily reset. Android also has a background midnight
/// alarm, but iOS has no equivalent, so this runs at startup and on resume.
/// It only zeroes each habit's daily counter — history is never touched here
/// (history is persisted on every increment). Returns true if a reset ran.
Future<bool> maybeResetForNewDay() async {
  final prefs = await SharedPreferences.getInstance();
  final today = dateKeyFromDate(DateTime.now());
  if (prefs.getString(kPrefsLastActiveDate) == today) return false;

  final habits = await HabitService.loadHabits();
  bool changed = false;
  for (final Habit h in habits) {
    if (h.completedTimes != 0) {
      h.completedTimes = 0;
      changed = true;
    }
  }
  if (changed) await HabitService.saveHabits(habits);
  await prefs.setString(kPrefsLastActiveDate, today);

  // Smart reminders for the new day. On iOS they are (re)scheduled when the
  // app opens / a habit is incremented, so this Android-only call avoids a
  // no-op on iOS while keeping Android counters fresh after the rollover.
  if (Platform.isAndroid) {
    await NotificationService().cancelSmartReminders();
    await NotificationService().scheduleSmartRemindersForToday(habits);
  }
  return true;
}

ThemeData _buildTheme(ColorScheme scheme, AppPalette palette) {
  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    extensions: [palette],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surfaceMuted,
      contentTextStyle: TextStyle(color: scheme.onSurface),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(
      color: palette.border,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.backgroundAlt,
      indicatorColor: scheme.primary.withValues(alpha: 0.22),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class HabitApp extends StatelessWidget {
  const HabitApp({super.key, required this.onboarded});
  final bool onboarded;

  @override
  Widget build(BuildContext context) {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00E5FF),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF00E5FF),
      onPrimary: Colors.black,
      secondary: const Color(0xFF7C4DFF),
      onSecondary: Colors.white,
      tertiary: const Color(0xFFFF4081),
      onTertiary: Colors.white,
      surface: const Color(0xFF111318),
      onSurface: Colors.white,
      // Neutral tint — спира M3 от cyan-оцветяване на диалози и контейнери
      surfaceTint: const Color(0xFF050608),
    );

    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0097A7),
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF14171C),
      surfaceTint: Colors.transparent,
    );

    final darkTheme = _buildTheme(darkScheme, AppPalette.dark);
    final lightTheme = _buildTheme(lightScheme, AppPalette.light);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Habits',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: lightTheme,
        darkTheme: darkTheme,
        routes: {'/home': (_) => const RootNavigation()},
        home: onboarded ? const RootNavigation() : const OnboardingScreen(),
      ),
    );
  }
}

class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<CalendarScreenState> _calendarKey =
      GlobalKey<CalendarScreenState>();
  final GlobalKey<StatsScreenState> _statsKey = GlobalKey<StatsScreenState>();

  late final List<Widget> _screens = [
    HomeScreen(key: _homeKey),
    CalendarScreen(key: _calendarKey),
    StatsScreen(key: _statsKey),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    final didReset = await maybeResetForNewDay();
    if (didReset && mounted) {
      _homeKey.currentState?.reload();
      _calendarKey.currentState?.reload();
      _statsKey.currentState?.reload();
    }
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    // Calendar/Stats load only in initState, but IndexedStack keeps them
    // alive — refresh their data when their tab is reopened.
    if (index == 1) {
      _calendarKey.currentState?.reload();
    } else if (index == 2) {
      _statsKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.background, palette.backgroundAlt],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: palette.backgroundAlt,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Днес',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Календар',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Статистика',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}

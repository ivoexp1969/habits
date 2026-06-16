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
      // Neutral tint — спира M3 от cyan-оцветяване на диалози и контейнери
      surfaceTint: const Color(0xFF050608),
    );
    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: darkScheme,
      scaffoldBackgroundColor: const Color(0xFF050608),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111318),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1A1D26),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF090B10),
        indicatorColor: const Color(0xFF00E5FF).withOpacity(0.22),
      ),
    );

    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0097A7),
      brightness: Brightness.light,
    );
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: lightScheme,
      scaffoldBackgroundColor: const Color(0xFFF2F4F8),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );

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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050608), Color(0xFF090B10)],
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
        backgroundColor: const Color(0xFF090B10),
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

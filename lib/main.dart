import 'dart:async';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
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
import 'widgets/banner_ad_widget.dart';

/// Whether to show the "remove ads for a coffee" prompt above the banner this
/// session (set once at startup — every 3rd launch). The banner is independent.
bool _showRemoveAdsPrompt = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw first, work later: only the theme + language are loaded before the
  // first frame — they decide how the very first screen looks. Everything
  // heavy (notifications, timezone DB, AlarmManager, ads, daily reset, habit
  // loading) runs AFTER the first frame inside [SplashScreen], so the native
  // splash is never frozen (was ~10s on the first launch of a new day).
  await loadThemePreference();
  await loadLocalePreference();
  runApp(const HabitApp());
}

/// Cross-platform "lazy" daily reset. Android also has a background midnight
/// alarm, but iOS has no equivalent, so this runs at startup and on resume.
/// It only zeroes each habit's daily counter — history is never touched here
/// (history is persisted on every increment). Returns true if a reset ran.
Future<bool> maybeResetForNewDay() async {
  final prefs = await SharedPreferences.getInstance();
  final today = dateKeyFromDate(DateTime.now());
  if (prefs.getString(kPrefsLastActiveDate) == today) return false;

  final loadSw = Stopwatch()..start();
  final habits = await HabitService.loadHabits();
  debugPrint('INIT_TIMING: HabitService.loadHabits = ${loadSw.elapsedMilliseconds}ms');
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
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: palette.background,
    extensions: [palette],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
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
          fontFamily: 'Manrope',
          fontSize: 11,
          letterSpacing: -0.2,
          fontWeight: FontWeight.w600,
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
  const HabitApp({super.key});

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
      builder: (_, mode, __) => ValueListenableBuilder<Locale>(
        valueListenable: localeNotifier,
        builder: (_, locale, ___) => MaterialApp(
          title: 'Навици',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: lightTheme,
          darkTheme: darkTheme,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {'/home': (_) => const RootNavigation()},
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// Lightweight Flutter splash shown immediately after the first frame. It runs
/// ALL the heavy startup work in a post-frame callback (so the native splash is
/// never frozen), then replaces itself with onboarding or the main app. The
/// business logic below is unchanged from the old `main()` — only WHEN it runs
/// moved (from before `runApp` to after the first frame).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Defer heavy init until AFTER this splash's first frame is painted, so the
    // user sees this lightweight Flutter screen instead of a frozen native one.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  /// Runs [op], printing how long it took. DIAGNOSTICS ONLY — measures where
  /// startup time goes; remove once the slow step is identified/optimized.
  Future<void> _timed(String label, Future<void> Function() op) async {
    final sw = Stopwatch()..start();
    await op();
    debugPrint('INIT_TIMING: $label = ${sw.elapsedMilliseconds}ms');
  }

  Future<void> _initialize() async {
    final total = Stopwatch()..start();
    await _timed('initializeDateFormatting', () => initializeDateFormatting());
    await _timed('NotificationService.init', () => NotificationService().init());
    // android_alarm_manager_plus is Android-only — calling it on iOS throws
    // MissingPluginException. The lazy reset below is the iOS path.
    if (Platform.isAndroid) {
      await _timed('AndroidAlarmManager init+schedule', () async {
        await AndroidAlarmManager.initialize();
        await scheduleNextMidnightAlarm();
      });
    }
    await _timed('PurchaseService.init', () => PurchaseService.instance.init());
    // AdMob + in-app purchases are mobile-only. Initialize ads, then connect to
    // the store in the background so it never blocks startup.
    if (Platform.isAndroid || Platform.isIOS) {
      await _timed('MobileAds.initialize', () => MobileAds.instance.initialize());
      unawaited(PurchaseService.instance.initIap());
    }
    // Daily reset (zeroes today's counters on a new day) — same logic, just
    // moved off the first-frame path. It's the work that used to freeze the
    // native splash for ~10s on the first launch of a new day. (Habit load +
    // save + smart-reminder reschedule all happen INSIDE this, on a new day.)
    await _timed('maybeResetForNewDay', () => maybeResetForNewDay());

    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool(kPrefsOnboarded) ?? false;
    // The "remove ads for a coffee" prompt is shown every 3rd app launch so it
    // reminds without nagging. The banner itself always shows (until ad-free).
    final launchCount = (prefs.getInt('launch_count') ?? 0) + 1;
    await prefs.setInt('launch_count', launchCount);
    _showRemoveAdsPrompt = launchCount % 3 == 0;
    debugPrint('INIT_TIMING: TOTAL _initialize = ${total.elapsedMilliseconds}ms');

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            onboarded ? const RootNavigation() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.background, palette.backgroundAlt],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 52,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
            ],
          ),
        ),
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
    final l10n = AppLocalizations.of(context);
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: PurchaseService.instance.adFreeNotifier,
            builder: (context, adFree, _) =>
                adFree ? const SizedBox.shrink() : const _AdBar(),
          ),
          MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.0,
        child: NavigationBar(
        backgroundColor: palette.backgroundAlt,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: l10n.navToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: l10n.navCalendar,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: l10n.navStats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
          ),
        ],
      ),
    );
  }
}

/// Bottom bar shown to non-paying users: the "remove ads" prompt above the
/// AdMob banner. Hidden once ads are removed (see [PurchaseService.isAdFree]).
class _AdBar extends StatelessWidget {
  const _AdBar();

  Future<void> _removeAds(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final started = await PurchaseService.instance.buyRemoveAds();
    if (!started) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.purchaseUnavailable),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: palette.backgroundAlt,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showRemoveAdsPrompt)
            TextButton(
              onPressed: () => _removeAds(context),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                minimumSize: const Size(0, 30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.coffee_outlined, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.removeAdsCoffee,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}

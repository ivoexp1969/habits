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

/// Set by [SplashScreen] when a new-day reset ran, so the post-Home background
/// init knows to reschedule today's smart reminders. That reschedule needs a
/// ready NotificationService, which now inits AFTER the first frame — so the
/// reschedule is deferred with it, off the critical path.
bool _needsReminderReschedule = false;

/// Wall-clock stopwatch from app start, used only to log startup timing
/// (HOME_VISIBLE / SERVICES_READY). Cheap; harmless to leave in.
final Stopwatch _startupSw = Stopwatch();

Future<void> main() async {
  _startupSw.start();
  WidgetsFlutterBinding.ensureInitialized();
  // Draw first, work later: only the theme + language are loaded before the
  // first frame — they decide how the very first screen looks. The daily reset
  // runs on the (now tiny) critical path in SplashScreen; everything else heavy
  // (notifications, timezone DB, AlarmManager, ads, IAP) runs AFTER Home's
  // first frame in RootNavigation, so the UI is never blocked by startup work.
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

  final sw = Stopwatch()..start();
  final habits = await HabitService.loadHabits();
  bool changed = false;
  for (final Habit h in habits) {
    if (h.completedTimes != 0) {
      h.completedTimes = 0;
      changed = true;
    }
  }
  // Single batched write (one setString of the whole list), not one per habit.
  if (changed) await HabitService.saveHabits(habits);
  await prefs.setString(kPrefsLastActiveDate, today);
  debugPrint('INIT_TIMING: maybeResetForNewDay(reset) = ${sw.elapsedMilliseconds}ms');
  return true;
}

/// (Android only) reschedule today's smart reminders. Split out of
/// [maybeResetForNewDay] so the fast counter reset can stay on the critical
/// path while this slower work (11 cancels + up to 3 schedules — the ~1.3s
/// that used to live inside the reset) runs after Home is visible. Requires
/// NotificationService().init() to have completed. iOS reschedules reminders
/// on open / habit increment, so this is a no-op there.
Future<void> rescheduleSmartReminders() async {
  if (!Platform.isAndroid) return;
  // scheduleSmartRemindersForToday() clears the whole range first, so an
  // explicit cancel here would be redundant.
  final habits = await HabitService.loadHabits();
  await NotificationService().scheduleSmartRemindersForToday(habits);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('INIT_TIMING: SPLASH_VISIBLE = ${_startupSw.elapsedMilliseconds}ms');
      _initialize();
    });
  }

  /// Critical path only — awaits the bare minimum needed for a correct Home,
  /// then navigates. Everything heavy (notifications, alarms, ads, IAP) is
  /// kicked off AFTER Home's first frame by RootNavigation, not here.
  Future<void> _initialize() async {
    // Needed so DateFormat renders localized dates on Home/Calendar (6ms).
    await initializeDateFormatting();
    // Zero today's counters on a new day so Home shows correct values from the
    // first frame. Now ~50ms — the slow reminder reschedule moved to the
    // background phase. The result tells that phase whether to reschedule.
    _needsReminderReschedule = await maybeResetForNewDay();

    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool(kPrefsOnboarded) ?? false;
    // The "remove ads for a coffee" prompt is shown every 3rd app launch so it
    // reminds without nagging. The banner itself always shows (until ad-free).
    final launchCount = (prefs.getInt('launch_count') ?? 0) + 1;
    await prefs.setInt('launch_count', launchCount);
    _showRemoveAdsPrompt = launchCount % 3 == 0;

    debugPrint('INIT_TIMING: CRITICAL_DONE = ${_startupSw.elapsedMilliseconds}ms');
    if (!mounted) return;
    // Instant (no slide/fade) so the splash→Home swap doesn't add a transition
    // delay on top of an already-minimal critical path.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) =>
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
    // Show Home first, init services after. This fires once the first frame is
    // on screen, so notifications/alarms/ads/IAP never block the UI appearing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('INIT_TIMING: HOME_VISIBLE = ${_startupSw.elapsedMilliseconds}ms');
      _initBackgroundServices();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Fire-and-forget init of everything that isn't needed to render Home. Runs
  /// after the first frame; the three groups are independent so they run in
  /// parallel. Order WITHIN a group is preserved where there's a dependency
  /// (alarm scheduling needs AlarmManager init; the reminder reschedule needs
  /// NotificationService init).
  Future<void> _initBackgroundServices() async {
    final tasks = <Future<void>>[
      () async {
        await NotificationService().init();
        // On a new day, reschedule today's smart reminders (moved here from
        // maybeResetForNewDay — it needs a ready NotificationService).
        if (_needsReminderReschedule) {
          _needsReminderReschedule = false;
          await rescheduleSmartReminders();
        }
      }(),
      if (Platform.isAndroid)
        () async {
          await AndroidAlarmManager.initialize();
          await scheduleNextMidnightAlarm();
        }(),
      if (Platform.isAndroid || Platform.isIOS)
        () async {
          await MobileAds.instance.initialize();
          // Let banners load now that the SDK is ready (see BannerAdWidget).
          adsInitializedNotifier.value = true;
          unawaited(PurchaseService.instance.initIap());
        }(),
      // Reads the ad-free flag → toggles the banner's visibility. Cheap (~60ms);
      // the banner just starts hidden and appears if ads apply.
      PurchaseService.instance.init(),
    ];
    await Future.wait(tasks);
    debugPrint('INIT_TIMING: SERVICES_READY = ${_startupSw.elapsedMilliseconds}ms');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    final didReset = await maybeResetForNewDay();
    if (didReset) {
      // NotificationService is already inited by now (app was running), so
      // reschedule today's reminders — preserves the pre-refactor resume
      // behavior, just without the reminder work living inside the reset.
      unawaited(rescheduleSmartReminders());
      if (mounted) {
        _homeKey.currentState?.reload();
        _calendarKey.currentState?.reload();
        _statsKey.currentState?.reload();
      }
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

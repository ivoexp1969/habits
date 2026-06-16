# Habits — finish-cleanup progress (handoff)

Cross-platform habit tracker (Flutter, Android + iOS), package `com.ivoexp.habits`.
Flutter installed: **3.41.6 stable** (≥3.27, so `withValues` is available).

## Git state
- Working on branch **`finish-cleanup`** (created off `master`; repo was `git init`-ed at start
  because it wasn't a git repo). **Do NOT merge** — leave for the user to review.
- All 8 phases committed, one commit each (see `git log --oneline finish-cleanup ^master`).
- Ignore `_archive_backups/`, `prefs.xml`, `prefs.xml.bak` — do not read/touch.

## flutter analyze baseline vs now
- Baseline (start): **0 errors, 2 warnings, 44 info = 46 issues**.
- Now: **0 errors, 2 issues total**. The 2 remaining are intentional:
  1. `analysis_options.yaml:10` — `flutter_lints/flutter.yaml` include not found
     (preexisting baseline; `flutter_lints` isn't a dependency — left as-is).
  2. `lib/models/habit.dart:41` — `Color.value` deprecation. **Task explicitly forbids
     touching this** (needed for backward-compat with old saved data). Leave it.

## Phases — ALL DONE (✅ committed, analyze clean after each)
1. ✅ `fix: guard Android alarm APIs + cross-platform daily reset (iOS)`
   - `main.dart`: `import 'dart:io'`; `AndroidAlarmManager.initialize()`/`scheduleNextMidnightAlarm()`
     wrapped in `if (Platform.isAndroid)`. Added top-level `maybeResetForNewDay()` (lazy daily
     reset via `kPrefsLastActiveDate`, only zeroes `completedTimes`, never touches history;
     Android-only smart-reminder reschedule). Called in `main()` after init and on resume.
   - `RootNavigation` is now `WidgetsBindingObserver`; `didChangeAppLifecycleState` → `_handleResume()`.
     `_screens` is now `late final` (has GlobalKeys), no longer `const`.
   - `notification_service.dart`: `import 'dart:io'`; `scheduleNextMidnightAlarm()` early-returns
     if `!Platform.isAndroid`; midnight callback now also writes `kPrefsLastActiveDate` to avoid
     double reset.
   - `kPrefsLastActiveDate = 'last_active_date'` added in `habit_service.dart`.
   - `HomeScreen` state made public (`HomeScreenState`) + `reload()` method.
2. ✅ `feat: iOS notification support (Darwin init + details + permissions)`
   - `init()`: `DarwinInitializationSettings` (request* = false) + `iOS:` in `InitializationSettings`;
     explicit `IOSFlutterLocalNotificationsPlugin.requestPermissions(alert/badge/sound: true)`.
   - `iOS: DarwinNotificationDetails(...)` added to daily reminder (loud), smart reminders
     (`presentSound: !isSilent`), and the gated quick-test. iOS `Info.plist`/`AppDelegate.swift`
     checked — standard, no changes needed.
3. ✅ `fix: remove promo-code premium unlock exploit`
   - `settings_screen.dart`: removed promo UI from `_infoSection` + `_showPromoCodeDialog` +
     `_applyPromoCode`.
   - `purchase_service.dart`: `import 'package:flutter/foundation.dart'`; `debugUnlock()` starts
     with `if (!kDebugMode) return;`.
4. ✅ `chore: remove non-existent Pomodoro feature claims`
   - `paywall_screen.dart`: removed `(Icons.timer_outlined, 'Pomodoro таймер')`.
   - `settings_screen.dart`: info text now "…XP, постижения и smart напомняния." (no Pomodoro).
   - grep confirms zero Pomodoro references in `lib/`.
5. ✅ `chore: remove non-functional language selector`
   - `settings_screen.dart`: removed `_languageSelector()`, the `Език` `_Section`, `_languages`,
     `_language`, and all `'language'` prefs read/write.
6. ✅ `refactor: remove dead code (lib/ui, unused notif methods, HabitStore)`
   - Deleted whole `lib/ui/` dir (app_theme, ui_widgets, ui/settings/*) — nothing imported it.
   - Removed unused notif methods: `showTestNotificationAfterTenSeconds`, `cancelAllNotifications`,
     `cancelAll` (dup), `scheduleMidnightRescheduleTrigger`. Kept `cancelSmartReminders` +
     `cancelDailyReminder` (still used).
   - Removed `HabitStore` from `habit_service.dart` + all 7 `HabitStore.instance.setHabits(_habits)`
     calls in `home_screen.dart`.
7. ✅ `fix: refresh Stats/Calendar data on tab switch`
   - `StatsScreen`/`CalendarScreen` states made public (`StatsScreenState`/`CalendarScreenState`)
     + `reload()`. `RootNavigation` has `_calendarKey`/`_statsKey`; `_onDestinationSelected(index)`
     reloads calendar (index 1) / stats (index 2). IndexedStack preserved.
8. ✅ `chore: remove debug prints + migrate withOpacity to withValues`
   - Removed all 12 `debugPrint`s from production paths (notif callbacks/smart + home catch).
     Empty catches changed to `catch (_)`; removed now-unused `beforeSum`.
   - `.withOpacity(x)` → `.withValues(alpha: x)` across `lib/` (incl. one multiline case in
     `calendar_screen.dart`). Did NOT touch `Color.value` in `habit.dart` (forbidden).

## REMAINING — Final verification (the only thing left to do)
Run these and confirm all three pass, then give the user a summary. DO NOT merge.
1. `flutter analyze` → expect 0 errors, 2 issues (both intentional, see above). ✅ already confirmed.
2. `flutter build apk --debug` → **not yet run**.
3. `flutter build ios --debug --no-codesign` → **not yet run** (main check for Phase 1+2).
   NOTE: iOS build requires macOS — on this Windows machine it will fail with a host-OS error,
   not a code error. If on Windows, state that the iOS build can't run here and that the code
   changes (Platform guards + Darwin notif APIs) are what make it correct; verify via analyze +
   code review instead. APK build should work if Android toolchain is present.

After builds: write the per-phase summary (files touched, build results) for the user.

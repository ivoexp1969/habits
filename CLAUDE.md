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

---

# ROUND 2 — user feedback (IN PROGRESS, **uncommitted** on `finish-cleanup`)

The 8 phases above are committed + the debug APK was built & installed wirelessly on a
Samsung Galaxy Note 9 (`adb` lives at `C:\Users\Admin\AppData\Local\Android\Sdk\platform-tools\adb.exe`;
wireless connect: `adb connect 192.168.0.117:5555` — same Wi-Fi needed).

User gave 3 feedback items; chose **"full light theme everywhere"** for #1:
1. Theme switching is a mess — half the app stays dark in light mode (hardcoded dark colors).
2. Add a **lifetime-premium promo code `IVA`** + a place to enter it.
3. All labels must fit inside their boxes (e.g. the "Визия"/theme selector overflowed).

## Approach for theme
Single source of truth = `AppPalette` ThemeExtension (surfaces only) in `theme_service.dart`,
with `dark`/`light` instances + `context.palette` / `context.scheme` getters. Text colors use
`scheme.onSurface` (+ opacity); accents use `scheme.primary`. Map of literals → semantic:
- `0xFF050608`→`palette.background`, `0xFF090B10`→`palette.backgroundAlt`,
  `0xFF111318`→`palette.card`, `0xFF18191F`→`palette.cardAlt`,
  `0xFF1A1E24`/`0xFF1A1D26`→`palette.surfaceMuted`, `0xFF2A2D36`/`0xFF07080B`→`palette.border`.
- `Colors.white`→`scheme.onSurface`; `white54`→`onSurfaceVariant`; `white38/24/12`→
  `onSurfaceVariant` or `onSurface.withValues(alpha: …)`.
- `0xFF00E5FF` (cyan brand)→`scheme.primary`; `Colors.black` foreground→`scheme.onPrimary`.
- De-`const` widgets as needed when switching to context-based colors.

## DONE this round (uncommitted)
- `theme_service.dart`: added `AppPalette` ThemeExtension (dark+light) + `context.palette`/
  `context.scheme` extension.  ✅ analyze-clean
- `main.dart`: replaced inline themes with top-level `_buildTheme(scheme, palette)` that
  registers `extensions:[palette]` + themes AppBar/Card/Dialog/SnackBar/Divider/NavigationBar/
  PopupMenu; light & dark schemes get explicit surface/onSurface. `RootNavigation` gradient +
  nav bar now use `context.palette`.  ✅ analyze-clean
- `purchase_service.dart`: added `redeemPromoCode(code)` → owner code `'IVA'` grants lifetime
  premium (persists `is_premium=true`; works in release, unlike `debugUnlock`).  ✅
- `settings_screen.dart`: `_Section` card/border→palette; profile premium tint→`scheme.primary`;
  `_premiumCard` fully themed; **theme selector overflow fixed** (removed per-segment icons,
  full-width, compact density); `_infoSection` themed + re-added **"Код за отстъпка"** entry
  (only shown when `!_isPremium`) → `_showPromoCodeDialog` + `_redeemCode`.  ✅ analyze-clean
- `home_screen.dart`: SnackBar bg overrides removed; `_showLevelUpDialog`, templates sheet
  (`palette.card`), icon-picker chip (`palette.cardAlt`), `_EmptyState`, `_TemplatesSheet`,
  `_TemplateRow` (cardAlt/border/onSurface/onSurfaceVariant), and `HabitRow` (card/border;
  name→onSurface; +/- icons→onSurfaceVariant / `onSurface.withValues(alpha:.25)`) all themed.
  Added `import '../services/theme_service.dart'`.  ✅ analyze-clean

## DONE this round — remaining screens (all completed)
- `stats_screen.dart`: 4 card surfaces `0xFF111318`→`palette.card`; chip icon `Colors.white`→
  `scheme.onSurface`. Orange/yellow/cyan stat accents kept (intentional). Import added. ✅
- `calendar_screen.dart`: day-cell fills `0xFF111318`→`palette.card`, `0xFF07080B`→`palette.border`;
  day number `Colors.white`→`scheme.onSurface`. Green/yellow/red status colors kept. Import added. ✅
- `paywall_screen.dart`: scaffold→`palette.background`; cards `0xFF111318`→`palette.card`,
  borders→`palette.border`; brand `0xFF00E5FF`→`scheme.primary`; `Colors.black` fg→`scheme.onPrimary`;
  white/white54/38/24→onSurface/onSurfaceVariant/alpha. Gold "Популярен" badge kept. De-consted. ✅
- `onboarding_screen.dart` (rewritten): scaffold→`palette.background`; dots, buttons, fields,
  template cards all themed; `0xFF00E5FF`→`scheme.primary` (incl. gradient/shadow/chip); surfaces→
  `palette.card`/`border`/`surfaceMuted`; text→onSurface/onSurfaceVariant. Kept the cyan→purple
  (`0xFF7B1FA2`) hero gradient + green/yellow/red mini-calendar status; `Colors.white` icons that
  sit on saturated gradient circles left as-is (correct in both themes). ✅

## VERIFICATION — ALL PASS
- `flutter analyze` → 0 errors, 2 issues (both intentional: flutter_lints include + forbidden
  `Color.value`). ✅
- `flutter build apk --debug` → **Built `build/app/outputs/flutter-apk/app-debug.apk`**. ✅
- Installed on Samsung Galaxy Note 9 over Wi-Fi (`adb connect 192.168.0.117:5555` → `install -r`
  → `Success`). ✅
- iOS build: not run (requires macOS). Code is correct via Platform guards + Darwin notif APIs.

Round-2 work is **committed** on `finish-cleanup` (not merged). Remaining manual eye-check on the
phone: switch Тъмна/Авто/Светла in Настройки → every screen flips fully, theme selector fits,
`IVA` code unlocks Premium.

---

# ROUND 3 — promo dialog crash fix + rename + app icons

On-device testing (Note 9) surfaced a hard crash and two small asks. All fixed & verified on device.

## Promo dialog crash (red screen `_dependents.isEmpty is not true`)
- **Root cause** (captured via `flutter attach` → Dart console): `_showPromoCodeDialog` created a
  local `TextEditingController`, `await showDialog(...)`, then `ctrl.dispose()` **immediately**.
  The dialog's exit animation still drops focus → `EditableText._handleFocusChanged` →
  `clearComposing()` writes to the **already-disposed** controller → "TextEditingController was
  used after being disposed" → cascade ending in the `_dependents.isEmpty` ErrorWidget. Autofocus
  was a red herring.
- **Fix** (`settings_screen.dart`): extracted a `_PromoCodeDialog` StatefulWidget that owns the
  controller and disposes it in `State.dispose()` (runs only after the route fully unmounts).
  `_showPromoCodeDialog` now `await showDialog<String>(... _PromoCodeDialog())` and redeems the
  returned code. Verified on device: dialog opens, `IVA` → Активирай → Premium unlocks, no crash.
- Note: the Dart error does NOT reach `adb logcat` on this Impeller build — it goes to the VM
  service. Use `flutter attach -d 192.168.0.117:5555` (log to a file) to capture Dart stacks.

## Other Round-3 changes
- Renamed the entry + dialog title "Код за отстъпка" → **"Промокод"** (user wording).
- **App icons** replaced from `~/Downloads/files.zip` → `habit_icons.zip` (droplet + checkmark on
  dark navy, cyan brand). Copied the 5 Android `mipmap-*/ic_launcher.png` + all 15 iOS
  `AppIcon.appiconset/*.png` (sizes matched 1:1; iOS `Contents.json` untouched).

Round-3 rebuilt APK installed on the Note 9 and confirmed working. **Uncommitted until this note's
commit. Still do NOT merge `finish-cleanup`.**

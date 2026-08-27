# iOS build guide (Навици)

This repo is developed on Windows, where the iOS build **cannot** run (Apple's
toolchain is macOS-only). Everything iOS-specific in the code is guarded with
`Platform.isAndroid` / Darwin notification APIs and verified by code review +
`flutter analyze`. This doc is the runbook to actually compile and run it on a
Mac.

The iOS-relevant work lives on branch **`atomic-habits`** (latest features), which
descends from `combined`. Pull that branch.

**Status (updated for the 1.2.0 release):**
- **Bundle id is now `com.ivoexp.habits`** (matches Android) — set in
  `ios/Runner.xcodeproj/project.pbxproj` (tests → `com.ivoexp.habits.RunnerTests`).
  In Xcode just pick your Team under Signing & Capabilities.
- The **home-screen widget is Android-only** (a Kotlin `AppWidgetProvider`). The
  `home_widget` pod compiles on iOS, but there is **no iOS WidgetKit extension** —
  the app builds and runs fine; iOS simply has no widget yet. Adding one later
  needs a WidgetKit target + an App Group (out of scope for this release).
- Run `cd ios && pod install` after `flutter pub get` (picks up `home_widget`).

---

## 0. One-time Mac prerequisites

- **macOS** + **Xcode** (from the App Store), then run once:
  `sudo xcodebuild -license accept` and open Xcode once to install components.
- **CocoaPods**: `sudo gem install cocoapods` (or `brew install cocoapods`).
- **Flutter SDK** matching this project: **3.41.6 stable** (any `stable ≥ 3.27`
  works — the code uses `withValues`). Install via `git clone` of the Flutter repo
  or `brew install --cask flutter`, then add it to `PATH`.
- Verify: `flutter doctor` — the "iOS toolchain" and "Xcode" lines must be green.

## 1. Get the code

```sh
git clone https://github.com/ivoexp1969/habits.git
cd habits
git checkout atomic-habits
flutter pub get          # also regenerates l10n + the iOS ephemeral files
```

> The `ios/Podfile` is **not** committed — Flutter generates it automatically on
> the first build/`pod install`. That is expected.

## 2. Install CocoaPods deps

```sh
cd ios
pod install --repo-update
cd ..
```

This pulls the native pods for the plugins used: `google_mobile_ads`,
`in_app_purchase`, `flutter_local_notifications`, `shared_preferences`,
`android_alarm_manager_plus` (no-op on iOS), `flutter_timezone`, `file_picker`,
`confetti`, `webview_flutter`, `audioplayers`.

## 3. Build

**Code-verification build (no Apple account needed):**

```sh
flutter build ios --debug --no-codesign --no-tree-shake-icons
```

- `--no-tree-shake-icons` is **required** — the app constructs `IconData`
  dynamically, so the tree-shaker errors without it.
- `--no-codesign` skips signing; this proves the code compiles for iOS. It cannot
  be installed on a device (unsigned).

**Run on a real iPhone / make a TestFlight build (needs an Apple Developer team):**

```sh
open ios/Runner.xcworkspace   # NOT the .xcodeproj
```
In Xcode → **Runner target → Signing & Capabilities**: pick your Team and let it
manage signing, then either run from Xcode or:

```sh
flutter run --release --no-tree-shake-icons          # on a connected device
flutter build ipa --release --no-tree-shake-icons    # archive for App Store Connect
```

---

## 4. iOS caveats to fix before App Store submission

1. **Bundle identifier is still the default `com.example.habit`.** Android uses
   `com.ivoexp.habits`. For the App Store, set the iOS bundle id to
   `com.ivoexp.habits` (Xcode → Runner target → General → Identity, or in
   `ios/Runner.xcodeproj/project.pbxproj` `PRODUCT_BUNDLE_IDENTIFIER`). Create the
   matching App ID + app record in App Store Connect.
2. **Signing**: requires an Apple Developer Program membership + a distribution
   certificate/provisioning profile (Xcode "Automatically manage signing" is
   easiest).
3. **AdMob is already wired**: `GADApplicationIdentifier` =
   `ca-app-pub-4385157735120275~2817625209` and the iOS banner unit
   `/7184511557` are in `ios/Runner/Info.plist` + `banner_ad_widget.dart`. Debug
   uses Google TEST ad units; real ads only serve in release once the AdMob app is
   approved and linked. You'll likely also want an
   `NSUserTrackingUsageDescription` string + the ATT prompt if you enable
   personalized ads.
4. **In-app purchase** (`remove_ads`, one-time): create the same product id in App
   Store Connect → In-App Purchases before `buyRemoveAds()` can succeed on iOS.
5. **Deployment target**: iOS **12.0** (already set; `google_mobile_ads` needs
   ≥12). Display name is **„Навици"** (`CFBundleDisplayName`).
6. **Notifications**: Darwin init + permission request are already in
   `notification_service.dart`; the new per-habit *implementation-intention*
   reminders (Feature 4) schedule via the same `zonedSchedule` path — nothing
   iOS-specific to add. As on Android, a reminder scheduled with
   `DateTimeComponents.time` repeats daily but is re-registered by the OS across
   reboots only via the plugin's standard mechanism.

## 5. If a build fails

- Wrong Flutter version → `flutter --version`; switch to `stable`.
- Stale pods → `cd ios && pod deintegrate && pod install --repo-update`.
- Xcode cache → `flutter clean && flutter pub get`, then rebuild.
- Capture Dart-side errors with `flutter run` (Xcode console shows only native).

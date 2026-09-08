# iOS билд — подробни инструкции (Навици)

Проектът се разработва на **Windows**, където iOS билд **не може** да се пусне —
инструментите на Apple са само за macOS. Целият iOS-специфичен код е защитен с
`Platform.isAndroid` / Darwin notification API-та и е проверен чрез code review +
`flutter analyze`. Този документ е стъпка-по-стъпка ръководството да го компилираш
и пуснеш реално на Mac.

Актуалната работа (вкл. числовите цели) е на branch **`atomic-habits`** (произлиза
от `combined`). Изтегли този branch.

---

## Текущо състояние (вече конфигурирано — НЕ пипай, освен ако не се налага)

| Настройка | Стойност | Къде |
|---|---|---|
| **Bundle ID** | `com.ivoexp.habits` (= Android; тестовете = `…RunnerTests`) | `ios/Runner.xcodeproj/project.pbxproj` |
| **Deployment target** | **iOS 13.0** | `project.pbxproj` + `ios/Podfile` (`platform :ios, '13.0'`) |
| **Име на приложението** | **Навици** | `Info.plist` → `CFBundleDisplayName` / `CFBundleName` |
| **Версия** | **1.2.0+8** | `pubspec.yaml` (`version:`) |
| **AdMob app id (iOS)** | `ca-app-pub-4385157735120275~2817625209` | `Info.plist` → `GADApplicationIdentifier` |
| **AdMob банер unit (iOS)** | `/7184511557` | `widgets/banner_ad_widget.dart` (release) |
| **Разрешение „снимки/файлове"** | `NSPhotoLibraryUsageDescription` е зададен (за резервно копие) | `Info.plist` |
| **Известия** | Darwin init + заявка за разрешение | `services/notification_service.dart` |

**iOS home-screen widget** е подготвен (Swift код + Dart мост в репото), но таргетът
се създава в Xcode на Mac — виж **`IOS_WIDGET.md`**. Докато не добавиш таргета, iOS
просто няма widget; приложението се билдва и работи нормално. Android widget-ът
(Kotlin `AppWidgetProvider`) е непроменен.

---

## 0. Еднократни предпоставки на Mac

1. **macOS** + **Xcode** (от App Store). После веднъж:
   ```sh
   sudo xcodebuild -license accept
   ```
   и отвори Xcode веднъж, за да си доинсталира компонентите.
2. **CocoaPods**:
   ```sh
   sudo gem install cocoapods      # или: brew install cocoapods
   ```
3. **Flutter SDK** — **3.41.6 stable** (върши работа всеки `stable ≥ 3.27`, защото
   кодът ползва `withValues`). Инсталирай през `git clone` на Flutter репото или
   `brew install --cask flutter`, добави го в `PATH`.
4. Провери:
   ```sh
   flutter doctor
   ```
   Редовете **„Xcode"** и **„iOS toolchain"** трябва да са зелени.

## 1. Изтегли кода

```sh
git clone https://github.com/ivoexp1969/habits.git
cd habits
git checkout atomic-habits
flutter pub get          # също регенерира l10n + iOS ephemeral файловете
```

## 2. Инсталирай CocoaPods зависимостите

```sh
cd ios
pod install --repo-update
cd ..
```

Тегли native pod-овете за плъгините: `google_mobile_ads`, `in_app_purchase`,
`flutter_local_notifications`, `shared_preferences`, `android_alarm_manager_plus`
(no-op на iOS), `flutter_timezone`, `file_picker`, `confetti`, `webview_flutter`,
`audioplayers`, `home_widget`.

## 3. Билд

### 3а. Проверка на компилацията (БЕЗ Apple акаунт)
```sh
flutter build ios --debug --no-codesign --no-tree-shake-icons
```
- `--no-tree-shake-icons` е **задължителен** — приложението строи `IconData`
  динамично, иначе tree-shaker-ът гърми.
- `--no-codesign` пропуска подписването; доказва, че кодът се компилира за iOS, но
  **не може** да се инсталира на устройство (неподписан).

### 3б. Пускане на реален iPhone (нужен е Apple Developer акаунт)
```sh
open ios/Runner.xcworkspace     # ВНИМАНИЕ: .xcworkspace, НЕ .xcodeproj
```
В Xcode → **Runner target → Signing & Capabilities**:
- Избери своя **Team** и остави **„Automatically manage signing"** включено.
- Xcode ще генерира provisioning profile за `com.ivoexp.habits`.

После или пусни директно от Xcode (▶), или:
```sh
flutter run --release --no-tree-shake-icons        # на свързан iPhone
```

### 3в. Архив за App Store / TestFlight
```sh
flutter build ipa --release --no-tree-shake-icons
```
Резултат: `build/ios/ipa/*.ipa`. Качи го през **Xcode Organizer**
(`Window → Organizer → Distribute App`) или **Transporter** (от App Store) към
App Store Connect. Алтернативно от Xcode: `Product → Archive → Distribute App`.

> Можеш да презапишеш версията при билд: `--build-name=1.2.0 --build-number=9`.

---

## 4. Чеклист за подаване в App Store

1. **Apple Developer Program** членство ($99/год) — задължително за подписване и
   качване.
2. **App record в App Store Connect** с bundle id `com.ivoexp.habits` (вече зададен
   в проекта). Създай App ID в Developer Portal → Certificates, Identifiers & Profiles,
   ако Xcode не го направи автоматично.
3. **In-App Purchase**: създай продукт с id **`remove_ads`** (тип **Non-Consumable**,
   еднократен) в App Store Connect → *Monetization → In-App Purchases*. Докато не е
   одобрен, `buyRemoveAds()` на iOS ще връща неуспех.
4. **AdMob**: `GADApplicationIdentifier` и банер unit-ът вече са в `Info.plist` /
   кода. Debug ползва Google **TEST** реклами; реални се показват само в release,
   след като AdMob приложението е одобрено и свързано с App Store записа.
5. **App Tracking Transparency (ATT)** — само ако включиш **персонализирани**
   реклами: добави `NSUserTrackingUsageDescription` в `Info.plist` + покажи ATT
   промпта. В момента НЯМА такъв низ → дръж рекламите неперсонализирани, за да
   избегнеш отхвърляне. (Резервното копие ползва `NSPhotoLibraryUsageDescription`,
   който вече е наличен.)
6. **Privacy „Nutrition Label"** в App Store Connect: декларирай данните (реклами/
   идентификатори през AdMob; локални данни за навици не напускат устройството).
7. **Икони и splash**: иконите са в `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
   Провери, че всички размери са налични (Xcode ще предупреди при липса).
8. **Екранни снимки** за App Store: направи ги от iOS Simulator
   (`xcrun simctl io booted screenshot shot.png`) в изискваните размери.

---

## 5. Известия (Feature-и по „Атомни навици")

Darwin init + заявката за разрешение са в `notification_service.dart`. Per-habit
напомнянията за намерение (час+място) и streak/stack напомнянията минават през същия
`zonedSchedule` път — **няма нищо iOS-специфично за добавяне**. Напомняне със
`DateTimeComponents.time` се повтаря дневно чрез стандартния механизъм на плъгина.
Числовата **цел** (24/година и т.н.) е чисто UI/данни — не пипа iOS специфики.

## 6. Ако билдът се провали

| Симптом | Решение |
|---|---|
| Грешна Flutter версия | `flutter --version` → минни на `stable ≥ 3.27` |
| Стари/счупени pod-ове | `cd ios && pod deintegrate && pod install --repo-update` |
| Xcode кеш / странни грешки | `flutter clean && flutter pub get`, после билд наново |
| Tree-shaker грешка за икони | добави `--no-tree-shake-icons` (виж 3а) |
| Не виждаш Dart грешките | `flutter run` (Xcode конзолата показва само native) |
| „Signing requires a development team" | Xcode → Signing & Capabilities → избери Team |
| Pod иска по-нов iOS | deployment target вече е 13.0; не сваляй под 13 |

---

**Забележка**: този проект е тестван реално само на Android (Samsung Galaxy Note 9).
iOS е верифициран чрез Platform guard-ове + Darwin API-та + `flutter analyze`, но
**не е пускан на реален iPhone** (няма достъпен Mac при разработката). Първият Mac
билд може да изисква дребни донастройки в Xcode (Team/сертификати) — те са очаквани
и не са кодови проблеми.

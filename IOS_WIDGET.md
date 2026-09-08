# iOS home-screen widget — Xcode runbook (Навици)

Кодът на widget-а е готов и в репото, но **създаването на WidgetKit таргета, App
Group-а и подписването може да стане само в Xcode на Mac** (не на Windows). Този
документ е точните стъпки. Върши се веднъж; после widget-ът се обновява сам при
всяко отмятане (същия trigger като Android).

## Какво вече е подготвено (в репото, `atomic-habits`)
- **Dart мост** (`lib/services/widget_service.dart`): вика `HomeWidget.setAppGroupId('group.com.ivoexp.habits')`
  на iOS + `updateWidget(iOSName: 'HabitWidget')`. Android пътят е непроменен.
- **Swift widget**: `ios/HabitWidget/HabitWidget.swift` (TimelineProvider + SwiftUI изглед — заглавие,
  брой, хоризонтален % бар, серия; виолетов градиент 1:1 с Android).
- **`ios/HabitWidget/Info.plist`** (WidgetKit extension point) и **`ios/HabitWidget/HabitWidget.entitlements`**
  (App Group). Тези файлове са **инертни**, докато не добавиш таргета в Xcode — НЕ влияят на текущия build.

## Данни (за справка)
Widget-ът чете от App Group UserDefaults същите ключове, които Flutter записва:
`widget_title`, `widget_count_line`, `widget_percent` (0..100), `widget_streak_line`
(`widget_date` също се записва, но не се показва — както на Android). Всички са вече
локализирани от Flutter, затова в Swift няма локализация.

Константи, които трябва да съвпадат навсякъде:
- **App Group**: `group.com.ivoexp.habits`
- **Widget bundle id**: `com.ivoexp.habits.HabitWidget`
- **Widget kind / target name**: `HabitWidget`

---

## Стъпка 1 — App Group към Runner
1. `open ios/Runner.xcworkspace`
2. Избери **Runner** таргета → **Signing & Capabilities** → **+ Capability** → **App Groups**.
3. Натисни **+** под App Groups и добави `group.com.ivoexp.habits`.
   - Това създава/свързва `ios/Runner/Runner.entitlements` (Xcode задава `CODE_SIGN_ENTITLEMENTS`).
   - Ако ползваш **manual signing** (както е сега — виж `ExportOptions.plist`), регистрирай App Group-а в
     **developer.apple.com → Identifiers → App Groups**, добави го към App ID `com.ivoexp.habits` и
     регенерирай profile-а „Habits App Store".

## Стъпка 2 — Създай Widget Extension таргета
1. **File → New → Target… → iOS → Widget Extension**.
2. Product Name: **`HabitWidget`**. **Махни** отметките „Include Live Activity" и „Include Configuration
   App Intent" (ползваме `StaticConfiguration`). Team: твоя. Embed in Application: **Runner**.
3. Когато попита „Activate scheme?" → **Cancel** (остави Runner схемата активна).
4. Xcode създава група `HabitWidget/` с шаблонни файлове. **Замести съдържанието**:
   - Изтрий генерирания `HabitWidget.swift` (и `*Bundle.swift`, ако е сложил такъв) и **добави** нашия
     `ios/HabitWidget/HabitWidget.swift` (Add Files to Runner → таргет **HabitWidget**, не Runner).
   - За `Info.plist`: остави генерирания или го замести с нашия (важното е `NSExtensionPointIdentifier =
     com.apple.widgetkit-extension` и `CFBundleDisplayName = Навици`).

## Стъпка 3 — App Group към widget-а
1. Избери **HabitWidget** таргета → **Signing & Capabilities** → **+ Capability → App Groups** →
   отметни **`group.com.ivoexp.habits`** (същия).
   - Това свързва `HabitWidget.entitlements`. Ако Xcode създаде нов, увери се, че съдържа App Group-а
     (нашият `ios/HabitWidget/HabitWidget.entitlements` е за справка).
2. **General → Minimum Deployments**: iOS **14.0** (WidgetKit иска 14+; Runner остава 13.0).
3. **Signing**: Team = твоя; bundle id = **`com.ivoexp.habits.HabitWidget`**. При manual signing —
   създай App ID + provisioning profile за този bundle id (с App Group capability) в developer.apple.com.

## Стъпка 4 — Pods / Flutter
- Widget-ът ползва само **WidgetKit + SwiftUI** — **не** му трябват Flutter pod-ове. НЕ добавяй
  `HabitWidget` към Flutter/Pods build phase-овете. (`pod install` не пипа новия таргет.)
- Ако Xcode се оплаче за bitcode/скриптове — widget extension-ите не ползват Flutter „Run Script" фазата;
  остави я само на Runner.

## Стъпка 5 — За IPA export (manual signing)
В `ios/ExportOptions.plist` добави и профила на widget-а към `provisioningProfiles`:
```xml
<key>provisioningProfiles</key>
<dict>
  <key>com.ivoexp.habits</key><string>Habits App Store</string>
  <key>com.ivoexp.habits.HabitWidget</key><string>Habits Widget App Store</string>
</dict>
```
(Името вдясно = точното име на profile-а, който създаваш за widget bundle id-то.)

## Стъпка 6 — Билд + тест на симулатор
```sh
flutter build ios --debug --no-codesign --no-tree-shake-icons   # проверка на компилацията
# или пусни Runner схемата от Xcode на симулатор/устройство
flutter run --no-tree-shake-icons
```
1. Пусни приложението веднъж (за да запише данни в App Group-а) и **отметни поне един навик**.
2. На home screen на симулатора: дълго натискане → **+** → търси **Навици** → добави widget-а (Small/Medium).
3. Провери, че се вижда: заглавие, **брой** (напр. „2 / 5 днес"), **% бар**, **серия** („🔥 N дни").
4. Върни се в приложението, отметни/отмени навик → widget-ът се обновява (Flutter вика
   `updateWidget`, което на iOS прави `WidgetCenter.reloadAllTimelines`).

---

## Верификационен чеклист
- [ ] Android widget непокътнат (Dart промяната само добавя iOS клон + `iOSName`).
- [ ] App Group `group.com.ivoexp.habits` е добавен на **Runner И HabitWidget** (и в profile-ите при manual signing).
- [ ] Widget bundle id = `com.ivoexp.habits.HabitWidget`, min iOS 14.
- [ ] Widget показва верните % / брой / серия и се обновява при отмятане.
- [ ] `flutter build ios --no-codesign` минава; IPA export включва двата profile-а.

## Ако нещо не работи
| Симптом | Причина / решение |
|---|---|
| Widget показва „0 / 0" / празно | App Group id не съвпада на трите места, или приложението не е пускано веднъж да запише данни |
| „No such module 'WidgetKit'" | min deployment на widget target < 14 → сложи 14 |
| Данните не се обновяват | липсва `setAppGroupId` (вече е в Dart), или App Group липсва на Runner |
| Provisioning грешка при archive | липсва profile за `com.ivoexp.habits.HabitWidget` с App Group capability |
| iOS 17 — прозрачен фон | ползваме `containerBackground` (вече в кода) — увери се, че строиш с Xcode 15+ |

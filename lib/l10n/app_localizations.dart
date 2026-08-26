import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bg.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bg'),
    Locale('en')
  ];

  /// No description provided for @navToday.
  ///
  /// In bg, this message translates to:
  /// **'Днес'**
  String get navToday;

  /// No description provided for @navCalendar.
  ///
  /// In bg, this message translates to:
  /// **'Календар'**
  String get navCalendar;

  /// No description provided for @navStats.
  ///
  /// In bg, this message translates to:
  /// **'Статистика'**
  String get navStats;

  /// No description provided for @navSettings.
  ///
  /// In bg, this message translates to:
  /// **'Настройки'**
  String get navSettings;

  /// No description provided for @removeAdsCoffee.
  ///
  /// In bg, this message translates to:
  /// **'Премахни рекламите на цената на едно кафе'**
  String get removeAdsCoffee;

  /// No description provided for @purchaseUnavailable.
  ///
  /// In bg, this message translates to:
  /// **'Покупката не е налична в момента. Опитай по-късно.'**
  String get purchaseUnavailable;

  /// No description provided for @restorePurchasesBtn.
  ///
  /// In bg, this message translates to:
  /// **'Възстанови покупките'**
  String get restorePurchasesBtn;

  /// No description provided for @restoreChecking.
  ///
  /// In bg, this message translates to:
  /// **'Проверяваме за предишни покупки…'**
  String get restoreChecking;

  /// No description provided for @homeTitle.
  ///
  /// In bg, this message translates to:
  /// **'Днес'**
  String get homeTitle;

  /// No description provided for @templatesTooltip.
  ///
  /// In bg, this message translates to:
  /// **'Шаблони'**
  String get templatesTooltip;

  /// No description provided for @greetingMorning.
  ///
  /// In bg, this message translates to:
  /// **'Добро утро'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In bg, this message translates to:
  /// **'Добър ден'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In bg, this message translates to:
  /// **'Добър вечер'**
  String get greetingEvening;

  /// No description provided for @perfectDayBonus.
  ///
  /// In bg, this message translates to:
  /// **'🏆 Перфектен ден! +50 XP бонус'**
  String get perfectDayBonus;

  /// No description provided for @levelUpTitle.
  ///
  /// In bg, this message translates to:
  /// **'Ниво {level}!'**
  String levelUpTitle(int level);

  /// No description provided for @levelXp.
  ///
  /// In bg, this message translates to:
  /// **'{xp} XP'**
  String levelXp(int xp);

  /// No description provided for @levelUpContinue.
  ///
  /// In bg, this message translates to:
  /// **'Напред!'**
  String get levelUpContinue;

  /// No description provided for @achievementUnlocked.
  ///
  /// In bg, this message translates to:
  /// **'Постижение: {title}!'**
  String achievementUnlocked(String title);

  /// No description provided for @habitsCompletedToday.
  ///
  /// In bg, this message translates to:
  /// **'{completed} / {total} навика завършени днес'**
  String habitsCompletedToday(int completed, int total);

  /// No description provided for @emptyTitle.
  ///
  /// In bg, this message translates to:
  /// **'Нямаш навици още'**
  String get emptyTitle;

  /// No description provided for @emptySubtitle.
  ///
  /// In bg, this message translates to:
  /// **'Добави ръчно или избери готов пакет'**
  String get emptySubtitle;

  /// No description provided for @choosePack.
  ///
  /// In bg, this message translates to:
  /// **'Избери пакет'**
  String get choosePack;

  /// No description provided for @packsTitle.
  ///
  /// In bg, this message translates to:
  /// **'Пакети с навици'**
  String get packsTitle;

  /// No description provided for @packsSubtitle.
  ///
  /// In bg, this message translates to:
  /// **'Докосни пакет, за да видиш навиците в него'**
  String get packsSubtitle;

  /// No description provided for @allHabitsAdded.
  ///
  /// In bg, this message translates to:
  /// **'Всички {total} навика са добавени'**
  String allHabitsAdded(int total);

  /// No description provided for @packSomeAdded.
  ///
  /// In bg, this message translates to:
  /// **'{total} навика · {added} вече добавени'**
  String packSomeAdded(int total, int added);

  /// No description provided for @packDescCount.
  ///
  /// In bg, this message translates to:
  /// **'{description} · {total} навика'**
  String packDescCount(String description, int total);

  /// No description provided for @nHabits.
  ///
  /// In bg, this message translates to:
  /// **'{count} навика'**
  String nHabits(int count);

  /// No description provided for @timesPerDayShort.
  ///
  /// In bg, this message translates to:
  /// **'{times}x на ден'**
  String timesPerDayShort(int times);

  /// No description provided for @exitBtn.
  ///
  /// In bg, this message translates to:
  /// **'Изход'**
  String get exitBtn;

  /// No description provided for @allAddedShort.
  ///
  /// In bg, this message translates to:
  /// **'Всички са добавени'**
  String get allAddedShort;

  /// No description provided for @addN.
  ///
  /// In bg, this message translates to:
  /// **'Добави ({count})'**
  String addN(int count);

  /// No description provided for @newHabit.
  ///
  /// In bg, this message translates to:
  /// **'Нов навик'**
  String get newHabit;

  /// No description provided for @habitName.
  ///
  /// In bg, this message translates to:
  /// **'Име на навика'**
  String get habitName;

  /// No description provided for @habitNameHint.
  ///
  /// In bg, this message translates to:
  /// **'Напр. Пия вода'**
  String get habitNameHint;

  /// No description provided for @timesPerDay.
  ///
  /// In bg, this message translates to:
  /// **'Пъти на ден'**
  String get timesPerDay;

  /// No description provided for @iconLabel.
  ///
  /// In bg, this message translates to:
  /// **'Иконка'**
  String get iconLabel;

  /// No description provided for @cancel.
  ///
  /// In bg, this message translates to:
  /// **'Отказ'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In bg, this message translates to:
  /// **'Добави'**
  String get add;

  /// No description provided for @editHabit.
  ///
  /// In bg, this message translates to:
  /// **'Редакция на навик'**
  String get editHabit;

  /// No description provided for @save.
  ///
  /// In bg, this message translates to:
  /// **'Запази'**
  String get save;

  /// No description provided for @deleteHabit.
  ///
  /// In bg, this message translates to:
  /// **'Изтриване на навик'**
  String get deleteHabit;

  /// No description provided for @deleteHabitConfirm.
  ///
  /// In bg, this message translates to:
  /// **'Сигурен ли си, че искаш да изтриеш „{name}“?'**
  String deleteHabitConfirm(String name);

  /// No description provided for @delete.
  ///
  /// In bg, this message translates to:
  /// **'Изтрий'**
  String get delete;

  /// No description provided for @packAlreadyAdded.
  ///
  /// In bg, this message translates to:
  /// **'Навиците от „{name}“ вече са добавени'**
  String packAlreadyAdded(String name);

  /// No description provided for @packAddedCount.
  ///
  /// In bg, this message translates to:
  /// **'Добавени {count} навика от „{name}“'**
  String packAddedCount(int count, String name);

  /// No description provided for @addHabitFab.
  ///
  /// In bg, this message translates to:
  /// **'Навик'**
  String get addHabitFab;

  /// No description provided for @editMenu.
  ///
  /// In bg, this message translates to:
  /// **'Редакция'**
  String get editMenu;

  /// No description provided for @deleteMenu.
  ///
  /// In bg, this message translates to:
  /// **'Изтриване'**
  String get deleteMenu;

  /// No description provided for @advancedSection.
  ///
  /// In bg, this message translates to:
  /// **'Разширени (Атомни навици)'**
  String get advancedSection;

  /// No description provided for @identityLabel.
  ///
  /// In bg, this message translates to:
  /// **'Кой ставаш?'**
  String get identityLabel;

  /// No description provided for @identityHint.
  ///
  /// In bg, this message translates to:
  /// **'напр. здрав човек, четящ'**
  String get identityHint;

  /// No description provided for @identityVoteFeedback.
  ///
  /// In bg, this message translates to:
  /// **'+1 глас за „{identity}“'**
  String identityVoteFeedback(String identity);

  /// No description provided for @identityVotesLine.
  ///
  /// In bg, this message translates to:
  /// **'🗳 {count, plural, one{{count} глас} other{{count} гласа}} за „{identity}“'**
  String identityVotesLine(int count, String identity);

  /// No description provided for @miniVersionLabel.
  ///
  /// In bg, this message translates to:
  /// **'Мини-версия (2 минути)'**
  String get miniVersionLabel;

  /// No description provided for @miniVersionHint.
  ///
  /// In bg, this message translates to:
  /// **'напр. обувам маратонките'**
  String get miniVersionHint;

  /// No description provided for @miniVersionTooltip.
  ///
  /// In bg, this message translates to:
  /// **'Мини-версия — брои се като изпълнение'**
  String get miniVersionTooltip;

  /// No description provided for @stackAfterLabel.
  ///
  /// In bg, this message translates to:
  /// **'След кой навик?'**
  String get stackAfterLabel;

  /// No description provided for @stackAfterNone.
  ///
  /// In bg, this message translates to:
  /// **'Без'**
  String get stackAfterNone;

  /// No description provided for @stackAfterCard.
  ///
  /// In bg, this message translates to:
  /// **'⛓ След „{anchor}“'**
  String stackAfterCard(String anchor);

  /// No description provided for @notifStackTitle.
  ///
  /// In bg, this message translates to:
  /// **'⛓ Твой ред: {habit}'**
  String notifStackTitle(String habit);

  /// No description provided for @notifStackBody.
  ///
  /// In bg, this message translates to:
  /// **'Точно след „{anchor}“ — направи го сега.'**
  String notifStackBody(String anchor);

  /// No description provided for @rewardLabel.
  ///
  /// In bg, this message translates to:
  /// **'След това ще си позволя…'**
  String get rewardLabel;

  /// No description provided for @rewardHint.
  ///
  /// In bg, this message translates to:
  /// **'напр. епизод от сериала'**
  String get rewardHint;

  /// No description provided for @rewardFeedback.
  ///
  /// In bg, this message translates to:
  /// **'🎁 Заслужи си: {reward}'**
  String rewardFeedback(String reward);

  /// No description provided for @rewardCard.
  ///
  /// In bg, this message translates to:
  /// **'🎁 Награда: {reward}'**
  String rewardCard(String reward);

  /// No description provided for @intentionTimeLabel.
  ///
  /// In bg, this message translates to:
  /// **'Час'**
  String get intentionTimeLabel;

  /// No description provided for @intentionPlaceLabel.
  ///
  /// In bg, this message translates to:
  /// **'Място'**
  String get intentionPlaceLabel;

  /// No description provided for @intentionPlaceHint.
  ///
  /// In bg, this message translates to:
  /// **'напр. в кухнята'**
  String get intentionPlaceHint;

  /// No description provided for @intentionPick.
  ///
  /// In bg, this message translates to:
  /// **'Избери час'**
  String get intentionPick;

  /// No description provided for @intentionClear.
  ///
  /// In bg, this message translates to:
  /// **'Изчисти'**
  String get intentionClear;

  /// No description provided for @intentionCard.
  ///
  /// In bg, this message translates to:
  /// **'🕒 в {time}'**
  String intentionCard(String time);

  /// No description provided for @intentionCardPlace.
  ///
  /// In bg, this message translates to:
  /// **'🕒 в {time} · {place}'**
  String intentionCardPlace(String time, String place);

  /// No description provided for @notifIntentionTitle.
  ///
  /// In bg, this message translates to:
  /// **'🕒 Време е: {habit}'**
  String notifIntentionTitle(String habit);

  /// No description provided for @notifIntentionBody.
  ///
  /// In bg, this message translates to:
  /// **'Направи го сега — {place}.'**
  String notifIntentionBody(String place);

  /// No description provided for @notifIntentionBodyNoPlace.
  ///
  /// In bg, this message translates to:
  /// **'Направи го сега.'**
  String get notifIntentionBodyNoPlace;

  /// No description provided for @monthSummaryCompleted.
  ///
  /// In bg, this message translates to:
  /// **'завършени'**
  String get monthSummaryCompleted;

  /// No description provided for @monthSummaryBestStreak.
  ///
  /// In bg, this message translates to:
  /// **'най-добра серия'**
  String get monthSummaryBestStreak;

  /// No description provided for @monthSummaryAvg.
  ///
  /// In bg, this message translates to:
  /// **'среден успех'**
  String get monthSummaryAvg;

  /// No description provided for @legendFull.
  ///
  /// In bg, this message translates to:
  /// **'Напълно завършен'**
  String get legendFull;

  /// No description provided for @legendPartial.
  ///
  /// In bg, this message translates to:
  /// **'Частично'**
  String get legendPartial;

  /// No description provided for @legendMissed.
  ///
  /// In bg, this message translates to:
  /// **'Пропуснат'**
  String get legendMissed;

  /// No description provided for @statsTitle.
  ///
  /// In bg, this message translates to:
  /// **'Статистика'**
  String get statsTitle;

  /// No description provided for @statOverallSuccess.
  ///
  /// In bg, this message translates to:
  /// **'Общ успех'**
  String get statOverallSuccess;

  /// No description provided for @statCurrentStreak.
  ///
  /// In bg, this message translates to:
  /// **'Текущ streak'**
  String get statCurrentStreak;

  /// No description provided for @statLongestStreak.
  ///
  /// In bg, this message translates to:
  /// **'Най-дълъг streak'**
  String get statLongestStreak;

  /// No description provided for @statActiveHabits.
  ///
  /// In bg, this message translates to:
  /// **'Активни навици'**
  String get statActiveHabits;

  /// No description provided for @statDays.
  ///
  /// In bg, this message translates to:
  /// **'{count} дни'**
  String statDays(int count);

  /// No description provided for @last7Days.
  ///
  /// In bg, this message translates to:
  /// **'Последни 7 дни'**
  String get last7Days;

  /// No description provided for @achievementsTitle.
  ///
  /// In bg, this message translates to:
  /// **'Постижения'**
  String get achievementsTitle;

  /// No description provided for @levelAndTitle.
  ///
  /// In bg, this message translates to:
  /// **'Ниво {level} · {title}'**
  String levelAndTitle(int level, String title);

  /// No description provided for @xpToNextLevel.
  ///
  /// In bg, this message translates to:
  /// **'{xp} XP · {remaining} до следващото ниво'**
  String xpToNextLevel(int xp, int remaining);

  /// No description provided for @xpMaxLevel.
  ///
  /// In bg, this message translates to:
  /// **'{xp} XP · Максимално ниво!'**
  String xpMaxLevel(int xp);

  /// No description provided for @settingsTitle.
  ///
  /// In bg, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @sectionProfile.
  ///
  /// In bg, this message translates to:
  /// **'Профил'**
  String get sectionProfile;

  /// No description provided for @sectionAds.
  ///
  /// In bg, this message translates to:
  /// **'Реклами'**
  String get sectionAds;

  /// No description provided for @sectionAppearance.
  ///
  /// In bg, this message translates to:
  /// **'Визия'**
  String get sectionAppearance;

  /// No description provided for @sectionReminders.
  ///
  /// In bg, this message translates to:
  /// **'Напомняния'**
  String get sectionReminders;

  /// No description provided for @sectionMusic.
  ///
  /// In bg, this message translates to:
  /// **'Музика'**
  String get sectionMusic;

  /// No description provided for @sectionData.
  ///
  /// In bg, this message translates to:
  /// **'Данни'**
  String get sectionData;

  /// No description provided for @sectionStreak.
  ///
  /// In bg, this message translates to:
  /// **'Серия'**
  String get sectionStreak;

  /// No description provided for @sectionLanguage.
  ///
  /// In bg, this message translates to:
  /// **'Език'**
  String get sectionLanguage;

  /// No description provided for @sectionInfo.
  ///
  /// In bg, this message translates to:
  /// **'Информация'**
  String get sectionInfo;

  /// No description provided for @streakFreeze.
  ///
  /// In bg, this message translates to:
  /// **'Гратисен ден'**
  String get streakFreeze;

  /// No description provided for @streakFreezeSub.
  ///
  /// In bg, this message translates to:
  /// **'Един пропуснат ден не къса серията'**
  String get streakFreezeSub;

  /// No description provided for @heatmapTitle.
  ///
  /// In bg, this message translates to:
  /// **'Активност през годината'**
  String get heatmapTitle;

  /// No description provided for @heatmapLess.
  ///
  /// In bg, this message translates to:
  /// **'По-малко'**
  String get heatmapLess;

  /// No description provided for @heatmapMore.
  ///
  /// In bg, this message translates to:
  /// **'Повече'**
  String get heatmapMore;

  /// No description provided for @profileAdFree.
  ///
  /// In bg, this message translates to:
  /// **'✨ Без реклами'**
  String get profileAdFree;

  /// No description provided for @profileFreePlan.
  ///
  /// In bg, this message translates to:
  /// **'Безплатен план'**
  String get profileFreePlan;

  /// No description provided for @editTooltip.
  ///
  /// In bg, this message translates to:
  /// **'Промени'**
  String get editTooltip;

  /// No description provided for @yourName.
  ///
  /// In bg, this message translates to:
  /// **'Твоето име'**
  String get yourName;

  /// No description provided for @nickname.
  ///
  /// In bg, this message translates to:
  /// **'Псевдоним'**
  String get nickname;

  /// No description provided for @adsRemovedTitle.
  ///
  /// In bg, this message translates to:
  /// **'Рекламите са премахнати'**
  String get adsRemovedTitle;

  /// No description provided for @adsRemovedThanks.
  ///
  /// In bg, this message translates to:
  /// **'Благодарим за подкрепата!'**
  String get adsRemovedThanks;

  /// No description provided for @adFreeShort.
  ///
  /// In bg, this message translates to:
  /// **'Без реклами'**
  String get adFreeShort;

  /// No description provided for @adsRemoveSupport.
  ///
  /// In bg, this message translates to:
  /// **'Подкрепи приложението и махни рекламите завинаги.'**
  String get adsRemoveSupport;

  /// No description provided for @musicHint.
  ///
  /// In bg, this message translates to:
  /// **'Релаксираща музика свири с бутона ♪ горе в лентата.'**
  String get musicHint;

  /// No description provided for @sleepTimer.
  ///
  /// In bg, this message translates to:
  /// **'Таймер за спиране'**
  String get sleepTimer;

  /// No description provided for @timerOff.
  ///
  /// In bg, this message translates to:
  /// **'Изкл'**
  String get timerOff;

  /// No description provided for @timerMinutes.
  ///
  /// In bg, this message translates to:
  /// **'{count} мин'**
  String timerMinutes(int count);

  /// No description provided for @dataHint.
  ///
  /// In bg, this message translates to:
  /// **'Запази навиците и историята си във файл или ги възстанови на друго устройство.'**
  String get dataHint;

  /// No description provided for @backupBtn.
  ///
  /// In bg, this message translates to:
  /// **'Бекъп'**
  String get backupBtn;

  /// No description provided for @restoreBtn.
  ///
  /// In bg, this message translates to:
  /// **'Възстанови'**
  String get restoreBtn;

  /// No description provided for @saveBackupDialog.
  ///
  /// In bg, this message translates to:
  /// **'Запази бекъп'**
  String get saveBackupDialog;

  /// No description provided for @backupSaved.
  ///
  /// In bg, this message translates to:
  /// **'Бекъпът е запазен.'**
  String get backupSaved;

  /// No description provided for @backupError.
  ///
  /// In bg, this message translates to:
  /// **'Грешка при създаване на бекъп.'**
  String get backupError;

  /// No description provided for @restoreSuccess.
  ///
  /// In bg, this message translates to:
  /// **'Данните са възстановени.'**
  String get restoreSuccess;

  /// No description provided for @restoreInvalid.
  ///
  /// In bg, this message translates to:
  /// **'Невалиден файл за възстановяване.'**
  String get restoreInvalid;

  /// No description provided for @restoreTooNew.
  ///
  /// In bg, this message translates to:
  /// **'Този архив е от по-нова версия на приложението. Обнови приложението, за да го възстановиш.'**
  String get restoreTooNew;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In bg, this message translates to:
  /// **'Възстановяване на данни'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In bg, this message translates to:
  /// **'Това ще замести текущите ти данни с тези от архива. Действието е необратимо.'**
  String get restoreConfirmBody;

  /// No description provided for @restoreReplace.
  ///
  /// In bg, this message translates to:
  /// **'Замести'**
  String get restoreReplace;

  /// No description provided for @themeDark.
  ///
  /// In bg, this message translates to:
  /// **'Тъмна'**
  String get themeDark;

  /// No description provided for @themeAuto.
  ///
  /// In bg, this message translates to:
  /// **'Авто'**
  String get themeAuto;

  /// No description provided for @themeLight.
  ///
  /// In bg, this message translates to:
  /// **'Светла'**
  String get themeLight;

  /// No description provided for @languageBulgarian.
  ///
  /// In bg, this message translates to:
  /// **'Български'**
  String get languageBulgarian;

  /// No description provided for @languageEnglish.
  ///
  /// In bg, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @dailyReminder.
  ///
  /// In bg, this message translates to:
  /// **'Ежедневно напомняне'**
  String get dailyReminder;

  /// No description provided for @dailyReminderSub.
  ///
  /// In bg, this message translates to:
  /// **'Фиксиран час всеки ден'**
  String get dailyReminderSub;

  /// No description provided for @reminderTime.
  ///
  /// In bg, this message translates to:
  /// **'Час'**
  String get reminderTime;

  /// No description provided for @smartReminders.
  ///
  /// In bg, this message translates to:
  /// **'Smart напомняния'**
  String get smartReminders;

  /// No description provided for @smartRemindersSub.
  ///
  /// In bg, this message translates to:
  /// **'Проследява прогреса — напомня само при нужда (09:00 / 14:00 / 19:30)'**
  String get smartRemindersSub;

  /// No description provided for @silent.
  ///
  /// In bg, this message translates to:
  /// **'Без звук'**
  String get silent;

  /// No description provided for @silentSub.
  ///
  /// In bg, this message translates to:
  /// **'Smart напомняния — без звук и вибрация'**
  String get silentSub;

  /// No description provided for @remindersUpdated.
  ///
  /// In bg, this message translates to:
  /// **'Напомнянията са обновени.'**
  String get remindersUpdated;

  /// No description provided for @version.
  ///
  /// In bg, this message translates to:
  /// **'Версия'**
  String get version;

  /// No description provided for @promoCode.
  ///
  /// In bg, this message translates to:
  /// **'Промокод'**
  String get promoCode;

  /// No description provided for @infoTagline.
  ///
  /// In bg, this message translates to:
  /// **'Habits — tracker за навици с XP, постижения и smart напомняния.'**
  String get infoTagline;

  /// No description provided for @enterCode.
  ///
  /// In bg, this message translates to:
  /// **'Въведи код'**
  String get enterCode;

  /// No description provided for @codeHint.
  ///
  /// In bg, this message translates to:
  /// **'напр. XXXX'**
  String get codeHint;

  /// No description provided for @activate.
  ///
  /// In bg, this message translates to:
  /// **'Активирай'**
  String get activate;

  /// No description provided for @adsRemovedSnack.
  ///
  /// In bg, this message translates to:
  /// **'✨ Рекламите са премахнати!'**
  String get adsRemovedSnack;

  /// No description provided for @invalidCode.
  ///
  /// In bg, this message translates to:
  /// **'Невалиден код.'**
  String get invalidCode;

  /// No description provided for @skip.
  ///
  /// In bg, this message translates to:
  /// **'Пропусни'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In bg, this message translates to:
  /// **'Напред'**
  String get next;

  /// No description provided for @start.
  ///
  /// In bg, this message translates to:
  /// **'Старт!'**
  String get start;

  /// No description provided for @onboardTagline.
  ///
  /// In bg, this message translates to:
  /// **'Изгради по-добри навици.\nПромени живота си.'**
  String get onboardTagline;

  /// No description provided for @onboardFeature1.
  ///
  /// In bg, this message translates to:
  /// **'Проследявай навиците си всеки ден'**
  String get onboardFeature1;

  /// No description provided for @onboardFeature2.
  ///
  /// In bg, this message translates to:
  /// **'Streak и XP система за мотивация'**
  String get onboardFeature2;

  /// No description provided for @onboardFeature3.
  ///
  /// In bg, this message translates to:
  /// **'Постижения за всеки milestone'**
  String get onboardFeature3;

  /// No description provided for @onboardTrackTitle.
  ///
  /// In bg, this message translates to:
  /// **'Проследявай напредъка'**
  String get onboardTrackTitle;

  /// No description provided for @onboardTrackSub.
  ///
  /// In bg, this message translates to:
  /// **'Виж как се подобряваш ден след ден'**
  String get onboardTrackSub;

  /// No description provided for @todayProgress.
  ///
  /// In bg, this message translates to:
  /// **'Днешен прогрес'**
  String get todayProgress;

  /// No description provided for @miniStatDays.
  ///
  /// In bg, this message translates to:
  /// **'дни серия'**
  String get miniStatDays;

  /// No description provided for @miniStatAchievements.
  ///
  /// In bg, this message translates to:
  /// **'постижения'**
  String get miniStatAchievements;

  /// No description provided for @onboardNameTitle.
  ///
  /// In bg, this message translates to:
  /// **'Как да те наричаме?'**
  String get onboardNameTitle;

  /// No description provided for @onboardNameSub.
  ///
  /// In bg, this message translates to:
  /// **'Напиши своето име или псевдоним'**
  String get onboardNameSub;

  /// No description provided for @yourNameHint.
  ///
  /// In bg, this message translates to:
  /// **'Твоето име...'**
  String get yourNameHint;

  /// No description provided for @canSkip.
  ///
  /// In bg, this message translates to:
  /// **'(можеш да пропуснеш)'**
  String get canSkip;

  /// No description provided for @onboardPackTitle.
  ///
  /// In bg, this message translates to:
  /// **'Избери стартов пакет'**
  String get onboardPackTitle;

  /// No description provided for @onboardPackSub.
  ///
  /// In bg, this message translates to:
  /// **'Можеш да добавяш и премахваш навици по-късно'**
  String get onboardPackSub;

  /// No description provided for @paywallFeatureUnlimited.
  ///
  /// In bg, this message translates to:
  /// **'Неограничени навици'**
  String get paywallFeatureUnlimited;

  /// No description provided for @paywallFeatureTemplates.
  ///
  /// In bg, this message translates to:
  /// **'Всички шаблони'**
  String get paywallFeatureTemplates;

  /// No description provided for @paywallFeatureXp.
  ///
  /// In bg, this message translates to:
  /// **'XP система и постижения'**
  String get paywallFeatureXp;

  /// No description provided for @paywallFeatureStats.
  ///
  /// In bg, this message translates to:
  /// **'Детайлна статистика'**
  String get paywallFeatureStats;

  /// No description provided for @paywallFeatureNoAds.
  ///
  /// In bg, this message translates to:
  /// **'Без реклами'**
  String get paywallFeatureNoAds;

  /// No description provided for @planMonthly.
  ///
  /// In bg, this message translates to:
  /// **'Месечен'**
  String get planMonthly;

  /// No description provided for @planYearly.
  ///
  /// In bg, this message translates to:
  /// **'Годишен'**
  String get planYearly;

  /// No description provided for @planLifetime.
  ///
  /// In bg, this message translates to:
  /// **'Lifetime'**
  String get planLifetime;

  /// No description provided for @perMonth.
  ///
  /// In bg, this message translates to:
  /// **'/месец'**
  String get perMonth;

  /// No description provided for @perYear.
  ///
  /// In bg, this message translates to:
  /// **'/година'**
  String get perYear;

  /// No description provided for @oneTime.
  ///
  /// In bg, this message translates to:
  /// **'еднократно'**
  String get oneTime;

  /// No description provided for @popular.
  ///
  /// In bg, this message translates to:
  /// **'Популярен'**
  String get popular;

  /// No description provided for @paywallTagline.
  ///
  /// In bg, this message translates to:
  /// **'Постигни повече всеки ден'**
  String get paywallTagline;

  /// No description provided for @continuePremium.
  ///
  /// In bg, this message translates to:
  /// **'Продължи с Premium'**
  String get continuePremium;

  /// No description provided for @restorePurchase.
  ///
  /// In bg, this message translates to:
  /// **'Възстанови покупка'**
  String get restorePurchase;

  /// No description provided for @cancelAnytime.
  ///
  /// In bg, this message translates to:
  /// **'Анулиране по всяко време от Google Play.'**
  String get cancelAnytime;

  /// No description provided for @purchaseAfterPublish.
  ///
  /// In bg, this message translates to:
  /// **'Покупките ще бъдат активни след публикуване в Play Store.'**
  String get purchaseAfterPublish;

  /// No description provided for @purchasesChecked.
  ///
  /// In bg, this message translates to:
  /// **'Покупките са проверени.'**
  String get purchasesChecked;

  /// No description provided for @stopMusic.
  ///
  /// In bg, this message translates to:
  /// **'Спри музиката'**
  String get stopMusic;

  /// No description provided for @relaxingMusic.
  ///
  /// In bg, this message translates to:
  /// **'Релаксираща музика'**
  String get relaxingMusic;

  /// No description provided for @templateMorningName.
  ///
  /// In bg, this message translates to:
  /// **'Сутрешна рутина'**
  String get templateMorningName;

  /// No description provided for @templateMorningDesc.
  ///
  /// In bg, this message translates to:
  /// **'Започни деня с енергия и фокус'**
  String get templateMorningDesc;

  /// No description provided for @templateHealthName.
  ///
  /// In bg, this message translates to:
  /// **'Здравословен живот'**
  String get templateHealthName;

  /// No description provided for @templateHealthDesc.
  ///
  /// In bg, this message translates to:
  /// **'Тяло и ум в баланс'**
  String get templateHealthDesc;

  /// No description provided for @templateFocusName.
  ///
  /// In bg, this message translates to:
  /// **'Продуктивност'**
  String get templateFocusName;

  /// No description provided for @templateFocusDesc.
  ///
  /// In bg, this message translates to:
  /// **'Постигни повече всеки ден'**
  String get templateFocusDesc;

  /// No description provided for @templateMindfulnessName.
  ///
  /// In bg, this message translates to:
  /// **'Равновесие'**
  String get templateMindfulnessName;

  /// No description provided for @templateMindfulnessDesc.
  ///
  /// In bg, this message translates to:
  /// **'Спокойствие и осъзнатост'**
  String get templateMindfulnessDesc;

  /// No description provided for @iconWater.
  ///
  /// In bg, this message translates to:
  /// **'Вода'**
  String get iconWater;

  /// No description provided for @iconReading.
  ///
  /// In bg, this message translates to:
  /// **'Четене'**
  String get iconReading;

  /// No description provided for @iconWorkout.
  ///
  /// In bg, this message translates to:
  /// **'Тренировка'**
  String get iconWorkout;

  /// No description provided for @iconWalk.
  ///
  /// In bg, this message translates to:
  /// **'Разходка'**
  String get iconWalk;

  /// No description provided for @iconRun.
  ///
  /// In bg, this message translates to:
  /// **'Бягане'**
  String get iconRun;

  /// No description provided for @iconMeditation.
  ///
  /// In bg, this message translates to:
  /// **'Медитация'**
  String get iconMeditation;

  /// No description provided for @iconSleep.
  ///
  /// In bg, this message translates to:
  /// **'Сън'**
  String get iconSleep;

  /// No description provided for @iconEating.
  ///
  /// In bg, this message translates to:
  /// **'Хранене'**
  String get iconEating;

  /// No description provided for @iconCooking.
  ///
  /// In bg, this message translates to:
  /// **'Готвене'**
  String get iconCooking;

  /// No description provided for @iconNoSmoking.
  ///
  /// In bg, this message translates to:
  /// **'Без цигари'**
  String get iconNoSmoking;

  /// No description provided for @iconSelfCare.
  ///
  /// In bg, this message translates to:
  /// **'Грижа'**
  String get iconSelfCare;

  /// No description provided for @iconCreativity.
  ///
  /// In bg, this message translates to:
  /// **'Творчество'**
  String get iconCreativity;

  /// No description provided for @iconMusic.
  ///
  /// In bg, this message translates to:
  /// **'Музика'**
  String get iconMusic;

  /// No description provided for @iconMind.
  ///
  /// In bg, this message translates to:
  /// **'Ум'**
  String get iconMind;

  /// No description provided for @iconLanguage.
  ///
  /// In bg, this message translates to:
  /// **'Език'**
  String get iconLanguage;

  /// No description provided for @iconFocus.
  ///
  /// In bg, this message translates to:
  /// **'Фокус'**
  String get iconFocus;

  /// No description provided for @iconWork.
  ///
  /// In bg, this message translates to:
  /// **'Работа'**
  String get iconWork;

  /// No description provided for @iconFinance.
  ///
  /// In bg, this message translates to:
  /// **'Финанси'**
  String get iconFinance;

  /// No description provided for @iconCleaning.
  ///
  /// In bg, this message translates to:
  /// **'Чистене'**
  String get iconCleaning;

  /// No description provided for @iconPhone.
  ///
  /// In bg, this message translates to:
  /// **'Телефон'**
  String get iconPhone;

  /// No description provided for @iconHabit.
  ///
  /// In bg, this message translates to:
  /// **'Навик'**
  String get iconHabit;

  /// No description provided for @iconFamily.
  ///
  /// In bg, this message translates to:
  /// **'Семейство'**
  String get iconFamily;

  /// No description provided for @iconPet.
  ///
  /// In bg, this message translates to:
  /// **'Домашен любимец'**
  String get iconPet;

  /// No description provided for @iconOutdoors.
  ///
  /// In bg, this message translates to:
  /// **'Навън'**
  String get iconOutdoors;

  /// No description provided for @achievementFirstStepTitle.
  ///
  /// In bg, this message translates to:
  /// **'Първа стъпка'**
  String get achievementFirstStepTitle;

  /// No description provided for @achievementFirstStepDesc.
  ///
  /// In bg, this message translates to:
  /// **'Добави първия си навик'**
  String get achievementFirstStepDesc;

  /// No description provided for @achievementOnFireTitle.
  ///
  /// In bg, this message translates to:
  /// **'В огъня'**
  String get achievementOnFireTitle;

  /// No description provided for @achievementOnFireDesc.
  ///
  /// In bg, this message translates to:
  /// **'7 поредни дни с ≥80% изпълнение'**
  String get achievementOnFireDesc;

  /// No description provided for @achievementUnstoppableTitle.
  ///
  /// In bg, this message translates to:
  /// **'Неудържим'**
  String get achievementUnstoppableTitle;

  /// No description provided for @achievementUnstoppableDesc.
  ///
  /// In bg, this message translates to:
  /// **'30 поредни дни с ≥80% изпълнение'**
  String get achievementUnstoppableDesc;

  /// No description provided for @achievementPerfectWeekTitle.
  ///
  /// In bg, this message translates to:
  /// **'Перфектна седмица'**
  String get achievementPerfectWeekTitle;

  /// No description provided for @achievementPerfectWeekDesc.
  ///
  /// In bg, this message translates to:
  /// **'100% изпълнение 7 дни подред'**
  String get achievementPerfectWeekDesc;

  /// No description provided for @achievementHabitMasterTitle.
  ///
  /// In bg, this message translates to:
  /// **'Контрол на навиците'**
  String get achievementHabitMasterTitle;

  /// No description provided for @achievementHabitMasterDesc.
  ///
  /// In bg, this message translates to:
  /// **'5 активни навика едновременно'**
  String get achievementHabitMasterDesc;

  /// No description provided for @achievementCenturionTitle.
  ///
  /// In bg, this message translates to:
  /// **'Центурион'**
  String get achievementCenturionTitle;

  /// No description provided for @achievementCenturionDesc.
  ///
  /// In bg, this message translates to:
  /// **'Изпълни навик 100 пъти общо'**
  String get achievementCenturionDesc;

  /// No description provided for @level1.
  ///
  /// In bg, this message translates to:
  /// **'Начинаещ'**
  String get level1;

  /// No description provided for @level2.
  ///
  /// In bg, this message translates to:
  /// **'Новак'**
  String get level2;

  /// No description provided for @level3.
  ///
  /// In bg, this message translates to:
  /// **'Стажант'**
  String get level3;

  /// No description provided for @level4.
  ///
  /// In bg, this message translates to:
  /// **'Ученик'**
  String get level4;

  /// No description provided for @level5.
  ///
  /// In bg, this message translates to:
  /// **'Изследовател'**
  String get level5;

  /// No description provided for @level6.
  ///
  /// In bg, this message translates to:
  /// **'Любознателен'**
  String get level6;

  /// No description provided for @level7.
  ///
  /// In bg, this message translates to:
  /// **'Практик'**
  String get level7;

  /// No description provided for @level8.
  ///
  /// In bg, this message translates to:
  /// **'Занаятчия'**
  String get level8;

  /// No description provided for @level9.
  ///
  /// In bg, this message translates to:
  /// **'Умел'**
  String get level9;

  /// No description provided for @level10.
  ///
  /// In bg, this message translates to:
  /// **'Опитен'**
  String get level10;

  /// No description provided for @level11.
  ///
  /// In bg, this message translates to:
  /// **'Вещ'**
  String get level11;

  /// No description provided for @level12.
  ///
  /// In bg, this message translates to:
  /// **'Специалист'**
  String get level12;

  /// No description provided for @level13.
  ///
  /// In bg, this message translates to:
  /// **'Майстор'**
  String get level13;

  /// No description provided for @level14.
  ///
  /// In bg, this message translates to:
  /// **'Шампион'**
  String get level14;

  /// No description provided for @level15.
  ///
  /// In bg, this message translates to:
  /// **'Елит'**
  String get level15;

  /// No description provided for @level16.
  ///
  /// In bg, this message translates to:
  /// **'Ветеран'**
  String get level16;

  /// No description provided for @level17.
  ///
  /// In bg, this message translates to:
  /// **'Легенда'**
  String get level17;

  /// No description provided for @level18.
  ///
  /// In bg, this message translates to:
  /// **'Митичен'**
  String get level18;

  /// No description provided for @level19.
  ///
  /// In bg, this message translates to:
  /// **'Безсмъртен'**
  String get level19;

  /// No description provided for @level20.
  ///
  /// In bg, this message translates to:
  /// **'Господар на навиците'**
  String get level20;

  /// No description provided for @levelShort.
  ///
  /// In bg, this message translates to:
  /// **'Ниво {level}'**
  String levelShort(int level);

  /// No description provided for @notifDailyTitle.
  ///
  /// In bg, this message translates to:
  /// **'Ежедневен преглед на навиците'**
  String get notifDailyTitle;

  /// No description provided for @notifDailyBody.
  ///
  /// In bg, this message translates to:
  /// **'Маркирай какво изпълни днес.'**
  String get notifDailyBody;

  /// No description provided for @notifMorning.
  ///
  /// In bg, this message translates to:
  /// **'☀️ Добро утро! {pct}% изпълнено'**
  String notifMorning(int pct);

  /// No description provided for @notifMidday.
  ///
  /// In bg, this message translates to:
  /// **'⚡ Обедна проверка — {pct}%'**
  String notifMidday(int pct);

  /// No description provided for @notifEvening.
  ///
  /// In bg, this message translates to:
  /// **'🌙 Вечерен преглед — {pct}%'**
  String notifEvening(int pct);

  /// No description provided for @notifRemaining.
  ///
  /// In bg, this message translates to:
  /// **'{name} — {count, plural, one{остава {count} път} other{остават {count} пъти}}'**
  String notifRemaining(String name, int count);

  /// No description provided for @notifLeadWithCount.
  ///
  /// In bg, this message translates to:
  /// **'{name} ({count})'**
  String notifLeadWithCount(String name, int count);

  /// No description provided for @notifPlusMore.
  ///
  /// In bg, this message translates to:
  /// **'{lead} + {count, plural, one{още {count} навик} other{още {count} навика}}'**
  String notifPlusMore(String lead, int count);

  /// No description provided for @channelSmartLoudName.
  ///
  /// In bg, this message translates to:
  /// **'Умни напомняния (със звук)'**
  String get channelSmartLoudName;

  /// No description provided for @channelSmartSilentName.
  ///
  /// In bg, this message translates to:
  /// **'Умни напомняния (без звук)'**
  String get channelSmartSilentName;

  /// No description provided for @channelSmartLoudDesc.
  ///
  /// In bg, this message translates to:
  /// **'Интелигентни напомняния със звук'**
  String get channelSmartLoudDesc;

  /// No description provided for @channelSmartSilentDesc.
  ///
  /// In bg, this message translates to:
  /// **'Интелигентни напомняния без звук'**
  String get channelSmartSilentDesc;

  /// No description provided for @channelSmartDesc.
  ///
  /// In bg, this message translates to:
  /// **'Интелигентни напомняния за навици'**
  String get channelSmartDesc;

  /// No description provided for @channelDailyName.
  ///
  /// In bg, this message translates to:
  /// **'Ежедневни напомняния за навици'**
  String get channelDailyName;

  /// No description provided for @channelDailyDesc.
  ///
  /// In bg, this message translates to:
  /// **'Ежедневни напомняния за навици'**
  String get channelDailyDesc;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bg', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bg':
      return AppLocalizationsBg();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

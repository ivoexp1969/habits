// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class AppLocalizationsBg extends AppLocalizations {
  AppLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get navToday => 'Днес';

  @override
  String get navCalendar => 'Календар';

  @override
  String get navStats => 'Статистика';

  @override
  String get navSettings => 'Настройки';

  @override
  String get removeAdsCoffee => 'Премахни рекламите на цената на едно кафе';

  @override
  String get removeAdsAction => 'Премахни';

  @override
  String get widgetTitle => 'Навици';

  @override
  String widgetDone(int done, int total) {
    return '$done / $total днес';
  }

  @override
  String widgetStreakLine(int days) {
    return '🔥 $days дни серия';
  }

  @override
  String get widgetEmpty => 'Няма навици още';

  @override
  String get purchaseUnavailable =>
      'Покупката не е налична в момента. Опитай по-късно.';

  @override
  String get restorePurchasesBtn => 'Възстанови покупките';

  @override
  String get restoreChecking => 'Проверяваме за предишни покупки…';

  @override
  String get homeTitle => 'Днес';

  @override
  String get templatesTooltip => 'Шаблони';

  @override
  String get greetingMorning => 'Добро утро';

  @override
  String get greetingAfternoon => 'Добър ден';

  @override
  String get greetingEvening => 'Добър вечер';

  @override
  String get perfectDayBonus => '🏆 Перфектен ден! +50 XP бонус';

  @override
  String levelUpTitle(int level) {
    return 'Ниво $level!';
  }

  @override
  String levelXp(int xp) {
    return '$xp XP';
  }

  @override
  String get levelUpContinue => 'Напред!';

  @override
  String achievementUnlocked(String title) {
    return 'Постижение: $title!';
  }

  @override
  String habitsCompletedToday(int completed, int total) {
    return '$completed / $total навика завършени днес';
  }

  @override
  String get emptyTitle => 'Нямаш навици още';

  @override
  String get emptySubtitle => 'Добави ръчно или избери готов пакет';

  @override
  String get choosePack => 'Избери пакет';

  @override
  String get packsTitle => 'Пакети с навици';

  @override
  String get packsSubtitle => 'Докосни пакет, за да видиш навиците в него';

  @override
  String allHabitsAdded(int total) {
    return 'Всички $total навика са добавени';
  }

  @override
  String packSomeAdded(int total, int added) {
    return '$total навика · $added вече добавени';
  }

  @override
  String packDescCount(String description, int total) {
    return '$description · $total навика';
  }

  @override
  String nHabits(int count) {
    return '$count навика';
  }

  @override
  String timesPerDayShort(int times) {
    return '${times}x на ден';
  }

  @override
  String get exitBtn => 'Изход';

  @override
  String get allAddedShort => 'Всички са добавени';

  @override
  String addN(int count) {
    return 'Добави ($count)';
  }

  @override
  String get newHabit => 'Нов навик';

  @override
  String get habitName => 'Име на навика';

  @override
  String get habitNameHint => 'Напр. Пия вода';

  @override
  String get timesPerDay => 'Пъти на ден';

  @override
  String get iconLabel => 'Иконка';

  @override
  String get cancel => 'Отказ';

  @override
  String get add => 'Добави';

  @override
  String get editHabit => 'Редакция на навик';

  @override
  String get save => 'Запази';

  @override
  String get deleteHabit => 'Изтриване на навик';

  @override
  String deleteHabitConfirm(String name) {
    return 'Сигурен ли си, че искаш да изтриеш „$name“?';
  }

  @override
  String get delete => 'Изтрий';

  @override
  String packAlreadyAdded(String name) {
    return 'Навиците от „$name“ вече са добавени';
  }

  @override
  String packAddedCount(int count, String name) {
    return 'Добавени $count навика от „$name“';
  }

  @override
  String get addHabitFab => 'Навик';

  @override
  String get editMenu => 'Редакция';

  @override
  String get deleteMenu => 'Изтриване';

  @override
  String get advancedSection => 'Разширени (Атомни навици)';

  @override
  String get identityLabel => 'Кой ставаш?';

  @override
  String get identityHint => 'напр. здрав човек, четящ';

  @override
  String identityVoteFeedback(String identity) {
    return '+1 глас за „$identity“';
  }

  @override
  String identityVotesLine(int count, String identity) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count гласа',
      one: '$count глас',
    );
    return '🗳 $_temp0 за „$identity“';
  }

  @override
  String get miniVersionLabel => 'Мини-версия (2 минути)';

  @override
  String get miniVersionHint => 'напр. обувам маратонките';

  @override
  String get miniVersionTooltip => 'Мини-версия — брои се като изпълнение';

  @override
  String get stackAfterLabel => 'След кой навик?';

  @override
  String get stackAfterNone => 'Без';

  @override
  String stackAfterCard(String anchor) {
    return '⛓ След „$anchor“';
  }

  @override
  String notifStackTitle(String habit) {
    return '⛓ Твой ред: $habit';
  }

  @override
  String notifStackBody(String anchor) {
    return 'Точно след „$anchor“ — направи го сега.';
  }

  @override
  String get rewardLabel => 'След това ще си позволя…';

  @override
  String get rewardHint => 'напр. епизод от сериала';

  @override
  String rewardFeedback(String reward) {
    return '🎁 Заслужи си: $reward';
  }

  @override
  String rewardCard(String reward) {
    return '🎁 Награда: $reward';
  }

  @override
  String get intentionTimeLabel => 'Час';

  @override
  String get intentionPlaceLabel => 'Място';

  @override
  String get intentionPlaceHint => 'напр. в кухнята';

  @override
  String get intentionPick => 'Избери час';

  @override
  String get intentionClear => 'Изчисти';

  @override
  String intentionCard(String time) {
    return '🕒 в $time';
  }

  @override
  String intentionCardPlace(String time, String place) {
    return '🕒 в $time · $place';
  }

  @override
  String notifIntentionTitle(String habit) {
    return '🕒 Време е: $habit';
  }

  @override
  String notifIntentionBody(String place) {
    return 'Направи го сега — $place.';
  }

  @override
  String get notifIntentionBodyNoPlace => 'Направи го сега.';

  @override
  String get advancedOptional => 'по избор';

  @override
  String get atomicIntroTitle => 'Какво са Атомни навици?';

  @override
  String get atomicIntro =>
      'Малки промени, големи резултати. Вместо да разчиташ на мотивация, направи навика очевиден, лесен, привлекателен и възнаграждаващ. Полетата по-долу са по избор — попълни само каквото ти помага.';

  @override
  String get atomicMenu => 'Атомни навици';

  @override
  String get newHabitSubtitle => 'Стъпка към това кой ставаш';

  @override
  String get iconChangeHint => 'Докосни, за да смениш иконата';

  @override
  String get stickTitle => 'Затвърди навика';

  @override
  String get stickSubtitle => 'Незадължително · по „Атомни навици“';

  @override
  String get stickHint => 'Попълни колкото искаш — и празно е валиден навик.';

  @override
  String get freqHeading => 'Колко често';

  @override
  String get freqCountDay => 'Колко пъти на ден';

  @override
  String get freqCountWeek => 'Колко пъти на седмица';

  @override
  String get freqCountMonth => 'Колко пъти на месец';

  @override
  String get freqDay => 'Ден';

  @override
  String get freqWeek => 'Седмица';

  @override
  String get freqMonth => 'Месец';

  @override
  String get freqWeeklyShort => 'седмично';

  @override
  String get freqMonthlyShort => 'месечно';

  @override
  String get sentBecome => 'Искам да стана';

  @override
  String get sentWill => 'Ще направя';

  @override
  String get sentInTime => 'в';

  @override
  String get sentAtPlace => 'на';

  @override
  String get sentAfter => 'След като';

  @override
  String get sentHardDay => 'Труден ден';

  @override
  String get sentThen => 'После';

  @override
  String get pillIdentityEmpty => 'идентичност';

  @override
  String get pillNameFallback => 'това';

  @override
  String get pillTimeEmpty => 'час';

  @override
  String get pillPlaceEmpty => 'място';

  @override
  String get pillAnchorEmpty => 'навик';

  @override
  String get pillMiniEmpty => 'мини-версия';

  @override
  String get pillRewardEmpty => 'награда';

  @override
  String get voteBadge => '+1 ГЛАС';

  @override
  String voteTagText(String identity) {
    return 'Всяко отмятане е глас, че си „$identity“';
  }

  @override
  String get editIdentityTitle => 'Кой ставаш?';

  @override
  String get editPlaceTitle => 'Къде ще го правиш?';

  @override
  String get editMiniTitle => 'Мини-версия за труден ден';

  @override
  String get editRewardTitle => 'Награда след това';

  @override
  String get editAnchorTitle => 'След кой навик?';

  @override
  String get editTimeTitle => 'Кога?';

  @override
  String get timePickChoose => 'Избери час';

  @override
  String get timeRemove => 'Премахни часа';

  @override
  String get editDone => 'Готово';

  @override
  String get atomicIdentityTitle => 'Идентичност';

  @override
  String get atomicIdentityDesc =>
      'Всяко изпълнение е глас за човека, който ставаш.';

  @override
  String get atomicMiniTitle => 'Лесен старт (2 минути)';

  @override
  String get atomicMiniDesc => 'Смали навика до нещо, което отнема 2 минути.';

  @override
  String get atomicWhenTitle => 'Кога и къде';

  @override
  String get atomicWhenDesc =>
      'Точен план води до реално напомняне в този час.';

  @override
  String get atomicStackTitle => 'След друг навик';

  @override
  String get atomicStackDesc =>
      'Закачи го веднага след нещо, което вече правиш.';

  @override
  String get atomicRewardTitle => 'Награда';

  @override
  String get atomicRewardDesc => 'Дай си малък повод веднага след това.';

  @override
  String intentionSentence(String time) {
    return 'Ще правя това в $time';
  }

  @override
  String intentionSentencePlace(String time, String place) {
    return 'Ще правя това в $time · $place';
  }

  @override
  String get monthSummaryCompleted => 'завършени';

  @override
  String get monthSummaryBestStreak => 'най-добра серия';

  @override
  String get monthSummaryAvg => 'среден успех';

  @override
  String get legendFull => 'Напълно завършен';

  @override
  String get legendPartial => 'Частично';

  @override
  String get legendMissed => 'Пропуснат';

  @override
  String get statsTitle => 'Статистика';

  @override
  String get statOverallSuccess => 'Общ успех';

  @override
  String get statCurrentStreak => 'Текущ streak';

  @override
  String get statLongestStreak => 'Най-дълъг streak';

  @override
  String get statActiveHabits => 'Активни навици';

  @override
  String statDays(int count) {
    return '$count дни';
  }

  @override
  String get last7Days => 'Последни 7 дни';

  @override
  String get achievementsTitle => 'Постижения';

  @override
  String levelAndTitle(int level, String title) {
    return 'Ниво $level · $title';
  }

  @override
  String xpToNextLevel(int xp, int remaining) {
    return '$xp XP · $remaining до следващото ниво';
  }

  @override
  String xpMaxLevel(int xp) {
    return '$xp XP · Максимално ниво!';
  }

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get sectionProfile => 'Профил';

  @override
  String get sectionAds => 'Реклами';

  @override
  String get sectionAppearance => 'Визия';

  @override
  String get sectionReminders => 'Напомняния';

  @override
  String get sectionMusic => 'Музика';

  @override
  String get sectionData => 'Данни';

  @override
  String get sectionStreak => 'Серия';

  @override
  String get sectionLanguage => 'Език';

  @override
  String get sectionInfo => 'Информация';

  @override
  String get streakFreeze => 'Гратисен ден';

  @override
  String get streakFreezeSub => 'Един пропуснат ден не къса серията';

  @override
  String get heatmapTitle => 'Активност през годината';

  @override
  String get heatmapLess => 'По-малко';

  @override
  String get heatmapMore => 'Повече';

  @override
  String get profileAdFree => '✨ Без реклами';

  @override
  String get profileFreePlan => 'Безплатен план';

  @override
  String get editTooltip => 'Промени';

  @override
  String get yourName => 'Твоето име';

  @override
  String get nickname => 'Псевдоним';

  @override
  String get adsRemovedTitle => 'Рекламите са премахнати';

  @override
  String get adsRemovedThanks => 'Благодарим за подкрепата!';

  @override
  String get adFreeShort => 'Без реклами';

  @override
  String get adsRemoveSupport =>
      'Подкрепи приложението и махни рекламите завинаги.';

  @override
  String get musicHint => 'Релаксираща музика свири с бутона ♪ горе в лентата.';

  @override
  String get sleepTimer => 'Таймер за спиране';

  @override
  String get timerOff => 'Изкл';

  @override
  String timerMinutes(int count) {
    return '$count мин';
  }

  @override
  String get dataHint =>
      'Запази навиците и историята си във файл или ги възстанови на друго устройство.';

  @override
  String get backupBtn => 'Бекъп';

  @override
  String get restoreBtn => 'Възстанови';

  @override
  String get saveBackupDialog => 'Запази бекъп';

  @override
  String get backupSaved => 'Бекъпът е запазен.';

  @override
  String get backupError => 'Грешка при създаване на бекъп.';

  @override
  String get restoreSuccess => 'Данните са възстановени.';

  @override
  String get restoreInvalid => 'Невалиден файл за възстановяване.';

  @override
  String get restoreTooNew =>
      'Този архив е от по-нова версия на приложението. Обнови приложението, за да го възстановиш.';

  @override
  String get restoreConfirmTitle => 'Възстановяване на данни';

  @override
  String get restoreConfirmBody =>
      'Това ще замести текущите ти данни с тези от архива. Действието е необратимо.';

  @override
  String get restoreReplace => 'Замести';

  @override
  String get themeDark => 'Тъмна';

  @override
  String get themeAuto => 'Авто';

  @override
  String get themeLight => 'Светла';

  @override
  String get languageBulgarian => 'Български';

  @override
  String get languageEnglish => 'English';

  @override
  String get dailyReminder => 'Ежедневно напомняне';

  @override
  String get dailyReminderSub => 'Фиксиран час всеки ден';

  @override
  String get reminderTime => 'Час';

  @override
  String get smartReminders => 'Smart напомняния';

  @override
  String get smartRemindersSub =>
      'Проследява прогреса — напомня само при нужда (09:00 / 14:00 / 19:30)';

  @override
  String get silent => 'Без звук';

  @override
  String get silentSub => 'Smart напомняния — без звук и вибрация';

  @override
  String get remindersUpdated => 'Напомнянията са обновени.';

  @override
  String get version => 'Версия';

  @override
  String get promoCode => 'Промокод';

  @override
  String get infoTagline =>
      'Habits — tracker за навици с XP, постижения и smart напомняния.';

  @override
  String get enterCode => 'Въведи код';

  @override
  String get codeHint => 'напр. XXXX';

  @override
  String get activate => 'Активирай';

  @override
  String get adsRemovedSnack => '✨ Рекламите са премахнати!';

  @override
  String get invalidCode => 'Невалиден код.';

  @override
  String get skip => 'Пропусни';

  @override
  String get next => 'Напред';

  @override
  String get start => 'Старт!';

  @override
  String get onboardTagline => 'Изгради по-добри навици.\nПромени живота си.';

  @override
  String get onboardFeature1 => 'Проследявай навиците си всеки ден';

  @override
  String get onboardFeature2 => 'Streak и XP система за мотивация';

  @override
  String get onboardFeature3 => 'Постижения за всеки milestone';

  @override
  String get onboardTrackTitle => 'Проследявай напредъка';

  @override
  String get onboardTrackSub => 'Виж как се подобряваш ден след ден';

  @override
  String get todayProgress => 'Днешен прогрес';

  @override
  String get miniStatDays => 'дни серия';

  @override
  String get miniStatAchievements => 'постижения';

  @override
  String get onboardNameTitle => 'Как да те наричаме?';

  @override
  String get onboardNameSub => 'Напиши своето име или псевдоним';

  @override
  String get yourNameHint => 'Твоето име...';

  @override
  String get canSkip => '(можеш да пропуснеш)';

  @override
  String get onboardPackTitle => 'Избери стартов пакет';

  @override
  String get onboardPackSub => 'Можеш да добавяш и премахваш навици по-късно';

  @override
  String get paywallFeatureUnlimited => 'Неограничени навици';

  @override
  String get paywallFeatureTemplates => 'Всички шаблони';

  @override
  String get paywallFeatureXp => 'XP система и постижения';

  @override
  String get paywallFeatureStats => 'Детайлна статистика';

  @override
  String get paywallFeatureNoAds => 'Без реклами';

  @override
  String get planMonthly => 'Месечен';

  @override
  String get planYearly => 'Годишен';

  @override
  String get planLifetime => 'Lifetime';

  @override
  String get perMonth => '/месец';

  @override
  String get perYear => '/година';

  @override
  String get oneTime => 'еднократно';

  @override
  String get popular => 'Популярен';

  @override
  String get paywallTagline => 'Постигни повече всеки ден';

  @override
  String get continuePremium => 'Продължи с Premium';

  @override
  String get restorePurchase => 'Възстанови покупка';

  @override
  String get cancelAnytime => 'Анулиране по всяко време от Google Play.';

  @override
  String get purchaseAfterPublish =>
      'Покупките ще бъдат активни след публикуване в Play Store.';

  @override
  String get purchasesChecked => 'Покупките са проверени.';

  @override
  String get stopMusic => 'Спри музиката';

  @override
  String get relaxingMusic => 'Релаксираща музика';

  @override
  String get templateMorningName => 'Сутрешна рутина';

  @override
  String get templateMorningDesc => 'Започни деня с енергия и фокус';

  @override
  String get templateHealthName => 'Здравословен живот';

  @override
  String get templateHealthDesc => 'Тяло и ум в баланс';

  @override
  String get templateFocusName => 'Продуктивност';

  @override
  String get templateFocusDesc => 'Постигни повече всеки ден';

  @override
  String get templateMindfulnessName => 'Равновесие';

  @override
  String get templateMindfulnessDesc => 'Спокойствие и осъзнатост';

  @override
  String get iconWater => 'Вода';

  @override
  String get iconReading => 'Четене';

  @override
  String get iconWorkout => 'Тренировка';

  @override
  String get iconWalk => 'Разходка';

  @override
  String get iconRun => 'Бягане';

  @override
  String get iconMeditation => 'Медитация';

  @override
  String get iconSleep => 'Сън';

  @override
  String get iconEating => 'Хранене';

  @override
  String get iconCooking => 'Готвене';

  @override
  String get iconNoSmoking => 'Без цигари';

  @override
  String get iconSelfCare => 'Грижа';

  @override
  String get iconCreativity => 'Творчество';

  @override
  String get iconMusic => 'Музика';

  @override
  String get iconMind => 'Ум';

  @override
  String get iconLanguage => 'Език';

  @override
  String get iconFocus => 'Фокус';

  @override
  String get iconWork => 'Работа';

  @override
  String get iconFinance => 'Финанси';

  @override
  String get iconCleaning => 'Чистене';

  @override
  String get iconPhone => 'Телефон';

  @override
  String get iconHabit => 'Навик';

  @override
  String get iconFamily => 'Семейство';

  @override
  String get iconPet => 'Домашен любимец';

  @override
  String get iconOutdoors => 'Навън';

  @override
  String get achievementFirstStepTitle => 'Първа стъпка';

  @override
  String get achievementFirstStepDesc => 'Добави първия си навик';

  @override
  String get achievementOnFireTitle => 'В огъня';

  @override
  String get achievementOnFireDesc => '7 поредни дни с ≥80% изпълнение';

  @override
  String get achievementUnstoppableTitle => 'Неудържим';

  @override
  String get achievementUnstoppableDesc => '30 поредни дни с ≥80% изпълнение';

  @override
  String get achievementPerfectWeekTitle => 'Перфектна седмица';

  @override
  String get achievementPerfectWeekDesc => '100% изпълнение 7 дни подред';

  @override
  String get achievementHabitMasterTitle => 'Контрол на навиците';

  @override
  String get achievementHabitMasterDesc => '5 активни навика едновременно';

  @override
  String get achievementCenturionTitle => 'Центурион';

  @override
  String get achievementCenturionDesc => 'Изпълни навик 100 пъти общо';

  @override
  String get level1 => 'Начинаещ';

  @override
  String get level2 => 'Новак';

  @override
  String get level3 => 'Стажант';

  @override
  String get level4 => 'Ученик';

  @override
  String get level5 => 'Изследовател';

  @override
  String get level6 => 'Любознателен';

  @override
  String get level7 => 'Практик';

  @override
  String get level8 => 'Занаятчия';

  @override
  String get level9 => 'Умел';

  @override
  String get level10 => 'Опитен';

  @override
  String get level11 => 'Вещ';

  @override
  String get level12 => 'Специалист';

  @override
  String get level13 => 'Майстор';

  @override
  String get level14 => 'Шампион';

  @override
  String get level15 => 'Елит';

  @override
  String get level16 => 'Ветеран';

  @override
  String get level17 => 'Легенда';

  @override
  String get level18 => 'Митичен';

  @override
  String get level19 => 'Безсмъртен';

  @override
  String get level20 => 'Господар на навиците';

  @override
  String levelShort(int level) {
    return 'Ниво $level';
  }

  @override
  String get notifDailyTitle => 'Ежедневен преглед на навиците';

  @override
  String get notifDailyBody => 'Маркирай какво изпълни днес.';

  @override
  String notifMorning(int pct) {
    return '☀️ Добро утро! $pct% изпълнено';
  }

  @override
  String notifMidday(int pct) {
    return '⚡ Обедна проверка — $pct%';
  }

  @override
  String notifEvening(int pct) {
    return '🌙 Вечерен преглед — $pct%';
  }

  @override
  String notifRemaining(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'остават $count пъти',
      one: 'остава $count път',
    );
    return '$name — $_temp0';
  }

  @override
  String notifLeadWithCount(String name, int count) {
    return '$name ($count)';
  }

  @override
  String notifPlusMore(String lead, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'още $count навика',
      one: 'още $count навик',
    );
    return '$lead + $_temp0';
  }

  @override
  String get channelSmartLoudName => 'Умни напомняния (със звук)';

  @override
  String get channelSmartSilentName => 'Умни напомняния (без звук)';

  @override
  String get channelSmartLoudDesc => 'Интелигентни напомняния със звук';

  @override
  String get channelSmartSilentDesc => 'Интелигентни напомняния без звук';

  @override
  String get channelSmartDesc => 'Интелигентни напомняния за навици';

  @override
  String get channelDailyName => 'Ежедневни напомняния за навици';

  @override
  String get channelDailyDesc => 'Ежедневни напомняния за навици';
}

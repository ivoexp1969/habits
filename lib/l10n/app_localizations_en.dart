// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navToday => 'Today';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navStats => 'Stats';

  @override
  String get navSettings => 'Settings';

  @override
  String get removeAdsCoffee => 'Remove ads for the price of a coffee';

  @override
  String get purchaseUnavailable =>
      'The purchase isn\'t available right now. Try again later.';

  @override
  String get restorePurchasesBtn => 'Restore purchases';

  @override
  String get restoreChecking => 'Checking for previous purchases…';

  @override
  String get homeTitle => 'Today';

  @override
  String get templatesTooltip => 'Templates';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get perfectDayBonus => '🏆 Perfect day! +50 XP bonus';

  @override
  String levelUpTitle(int level) {
    return 'Level $level!';
  }

  @override
  String levelXp(int xp) {
    return '$xp XP';
  }

  @override
  String get levelUpContinue => 'Onward!';

  @override
  String achievementUnlocked(String title) {
    return 'Achievement: $title!';
  }

  @override
  String habitsCompletedToday(int completed, int total) {
    return '$completed / $total habits completed today';
  }

  @override
  String get emptyTitle => 'No habits yet';

  @override
  String get emptySubtitle => 'Add one manually or pick a ready-made pack';

  @override
  String get choosePack => 'Choose a pack';

  @override
  String get packsTitle => 'Habit packs';

  @override
  String get packsSubtitle => 'Tap a pack to see the habits inside it';

  @override
  String allHabitsAdded(int total) {
    return 'All $total habits added';
  }

  @override
  String packSomeAdded(int total, int added) {
    return '$total habits · $added already added';
  }

  @override
  String packDescCount(String description, int total) {
    return '$description · $total habits';
  }

  @override
  String nHabits(int count) {
    return '$count habits';
  }

  @override
  String timesPerDayShort(int times) {
    return '${times}x per day';
  }

  @override
  String get exitBtn => 'Exit';

  @override
  String get allAddedShort => 'All added';

  @override
  String addN(int count) {
    return 'Add ($count)';
  }

  @override
  String get newHabit => 'New habit';

  @override
  String get habitName => 'Habit name';

  @override
  String get habitNameHint => 'e.g. Drink water';

  @override
  String get timesPerDay => 'Times per day';

  @override
  String get iconLabel => 'Icon';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get editHabit => 'Edit habit';

  @override
  String get save => 'Save';

  @override
  String get deleteHabit => 'Delete habit';

  @override
  String deleteHabitConfirm(String name) {
    return 'Are you sure you want to delete “$name”?';
  }

  @override
  String get delete => 'Delete';

  @override
  String packAlreadyAdded(String name) {
    return 'The habits from “$name” are already added';
  }

  @override
  String packAddedCount(int count, String name) {
    return 'Added $count habits from “$name”';
  }

  @override
  String get addHabitFab => 'Habit';

  @override
  String get editMenu => 'Edit';

  @override
  String get deleteMenu => 'Delete';

  @override
  String get advancedSection => 'Advanced (Atomic Habits)';

  @override
  String get identityLabel => 'Who are you becoming?';

  @override
  String get identityHint => 'e.g. a healthy person, a reader';

  @override
  String identityVoteFeedback(String identity) {
    return '+1 vote for “$identity”';
  }

  @override
  String identityVotesLine(int count, String identity) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '$count vote',
    );
    return '🗳 $_temp0 for “$identity”';
  }

  @override
  String get miniVersionLabel => 'Mini version (2 minutes)';

  @override
  String get miniVersionHint => 'e.g. put on my running shoes';

  @override
  String get miniVersionTooltip => 'Mini version — counts as a completion';

  @override
  String get stackAfterLabel => 'After which habit?';

  @override
  String get stackAfterNone => 'None';

  @override
  String stackAfterCard(String anchor) {
    return '⛓ After “$anchor”';
  }

  @override
  String notifStackTitle(String habit) {
    return '⛓ Your turn: $habit';
  }

  @override
  String notifStackBody(String anchor) {
    return 'Right after “$anchor” — do it now.';
  }

  @override
  String get rewardLabel => 'Afterwards I\'ll treat myself to…';

  @override
  String get rewardHint => 'e.g. an episode of the show';

  @override
  String rewardFeedback(String reward) {
    return '🎁 You earned it: $reward';
  }

  @override
  String rewardCard(String reward) {
    return '🎁 Reward: $reward';
  }

  @override
  String get intentionTimeLabel => 'Time';

  @override
  String get intentionPlaceLabel => 'Place';

  @override
  String get intentionPlaceHint => 'e.g. in the kitchen';

  @override
  String get intentionPick => 'Pick a time';

  @override
  String get intentionClear => 'Clear';

  @override
  String intentionCard(String time) {
    return '🕒 at $time';
  }

  @override
  String intentionCardPlace(String time, String place) {
    return '🕒 at $time · $place';
  }

  @override
  String notifIntentionTitle(String habit) {
    return '🕒 It\'s time: $habit';
  }

  @override
  String notifIntentionBody(String place) {
    return 'Do it now — $place.';
  }

  @override
  String get notifIntentionBodyNoPlace => 'Do it now.';

  @override
  String get monthSummaryCompleted => 'completed';

  @override
  String get monthSummaryBestStreak => 'best streak';

  @override
  String get monthSummaryAvg => 'avg. success';

  @override
  String get legendFull => 'Fully completed';

  @override
  String get legendPartial => 'Partial';

  @override
  String get legendMissed => 'Missed';

  @override
  String get statsTitle => 'Stats';

  @override
  String get statOverallSuccess => 'Overall success';

  @override
  String get statCurrentStreak => 'Current streak';

  @override
  String get statLongestStreak => 'Longest streak';

  @override
  String get statActiveHabits => 'Active habits';

  @override
  String statDays(int count) {
    return '$count days';
  }

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get achievementsTitle => 'Achievements';

  @override
  String levelAndTitle(int level, String title) {
    return 'Level $level · $title';
  }

  @override
  String xpToNextLevel(int xp, int remaining) {
    return '$xp XP · $remaining to next level';
  }

  @override
  String xpMaxLevel(int xp) {
    return '$xp XP · Max level!';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionProfile => 'Profile';

  @override
  String get sectionAds => 'Ads';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionReminders => 'Reminders';

  @override
  String get sectionMusic => 'Music';

  @override
  String get sectionData => 'Data';

  @override
  String get sectionStreak => 'Streak';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get sectionInfo => 'Information';

  @override
  String get streakFreeze => 'Grace day';

  @override
  String get streakFreezeSub => 'A single missed day won\'t break your streak';

  @override
  String get heatmapTitle => 'Activity this year';

  @override
  String get heatmapLess => 'Less';

  @override
  String get heatmapMore => 'More';

  @override
  String get profileAdFree => '✨ Ad-free';

  @override
  String get profileFreePlan => 'Free plan';

  @override
  String get editTooltip => 'Edit';

  @override
  String get yourName => 'Your name';

  @override
  String get nickname => 'Nickname';

  @override
  String get adsRemovedTitle => 'Ads removed';

  @override
  String get adsRemovedThanks => 'Thanks for your support!';

  @override
  String get adFreeShort => 'Ad-free';

  @override
  String get adsRemoveSupport => 'Support the app and remove the ads forever.';

  @override
  String get musicHint =>
      'Relaxing music plays with the ♪ button in the top bar.';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get timerOff => 'Off';

  @override
  String timerMinutes(int count) {
    return '$count min';
  }

  @override
  String get dataHint =>
      'Save your habits and history to a file, or restore them on another device.';

  @override
  String get backupBtn => 'Backup';

  @override
  String get restoreBtn => 'Restore';

  @override
  String get saveBackupDialog => 'Save backup';

  @override
  String get backupSaved => 'Backup saved.';

  @override
  String get backupError => 'Error creating backup.';

  @override
  String get restoreSuccess => 'Your data has been restored.';

  @override
  String get restoreInvalid => 'Invalid restore file.';

  @override
  String get restoreTooNew =>
      'This backup is from a newer app version. Update the app to restore it.';

  @override
  String get restoreConfirmTitle => 'Restore data';

  @override
  String get restoreConfirmBody =>
      'This will replace your current data with the backup. This can\'t be undone.';

  @override
  String get restoreReplace => 'Replace';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeLight => 'Light';

  @override
  String get languageBulgarian => 'Български';

  @override
  String get languageEnglish => 'English';

  @override
  String get dailyReminder => 'Daily reminder';

  @override
  String get dailyReminderSub => 'A fixed time every day';

  @override
  String get reminderTime => 'Time';

  @override
  String get smartReminders => 'Smart reminders';

  @override
  String get smartRemindersSub =>
      'Tracks your progress — reminds you only when needed (09:00 / 14:00 / 19:30)';

  @override
  String get silent => 'Silent';

  @override
  String get silentSub => 'Smart reminders — no sound or vibration';

  @override
  String get remindersUpdated => 'Reminders updated.';

  @override
  String get version => 'Version';

  @override
  String get promoCode => 'Promo code';

  @override
  String get infoTagline =>
      'Habits — a habit tracker with XP, achievements and smart reminders.';

  @override
  String get enterCode => 'Enter code';

  @override
  String get codeHint => 'e.g. XXXX';

  @override
  String get activate => 'Activate';

  @override
  String get adsRemovedSnack => '✨ Ads removed!';

  @override
  String get invalidCode => 'Invalid code.';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get start => 'Start!';

  @override
  String get onboardTagline => 'Build better habits.\nChange your life.';

  @override
  String get onboardFeature1 => 'Track your habits every day';

  @override
  String get onboardFeature2 =>
      'Streaks and an XP system to keep you motivated';

  @override
  String get onboardFeature3 => 'Achievements for every milestone';

  @override
  String get onboardTrackTitle => 'Track your progress';

  @override
  String get onboardTrackSub => 'See how you improve day after day';

  @override
  String get todayProgress => 'Today\'s progress';

  @override
  String get miniStatDays => 'day streak';

  @override
  String get miniStatAchievements => 'achievements';

  @override
  String get onboardNameTitle => 'What should we call you?';

  @override
  String get onboardNameSub => 'Enter your name or a nickname';

  @override
  String get yourNameHint => 'Your name...';

  @override
  String get canSkip => '(you can skip this)';

  @override
  String get onboardPackTitle => 'Choose a starter pack';

  @override
  String get onboardPackSub => 'You can add and remove habits later';

  @override
  String get paywallFeatureUnlimited => 'Unlimited habits';

  @override
  String get paywallFeatureTemplates => 'All templates';

  @override
  String get paywallFeatureXp => 'XP system and achievements';

  @override
  String get paywallFeatureStats => 'Detailed statistics';

  @override
  String get paywallFeatureNoAds => 'Ad-free';

  @override
  String get planMonthly => 'Monthly';

  @override
  String get planYearly => 'Yearly';

  @override
  String get planLifetime => 'Lifetime';

  @override
  String get perMonth => '/month';

  @override
  String get perYear => '/year';

  @override
  String get oneTime => 'one-time';

  @override
  String get popular => 'Popular';

  @override
  String get paywallTagline => 'Achieve more every day';

  @override
  String get continuePremium => 'Continue with Premium';

  @override
  String get restorePurchase => 'Restore purchase';

  @override
  String get cancelAnytime => 'Cancel anytime from Google Play.';

  @override
  String get purchaseAfterPublish =>
      'Purchases will become active after publishing to the Play Store.';

  @override
  String get purchasesChecked => 'Purchases have been checked.';

  @override
  String get stopMusic => 'Stop the music';

  @override
  String get relaxingMusic => 'Relaxing music';

  @override
  String get templateMorningName => 'Morning routine';

  @override
  String get templateMorningDesc => 'Start your day with energy and focus';

  @override
  String get templateHealthName => 'Healthy living';

  @override
  String get templateHealthDesc => 'Body and mind in balance';

  @override
  String get templateFocusName => 'Productivity';

  @override
  String get templateFocusDesc => 'Achieve more every day';

  @override
  String get templateMindfulnessName => 'Balance';

  @override
  String get templateMindfulnessDesc => 'Calm and mindfulness';

  @override
  String get iconWater => 'Water';

  @override
  String get iconReading => 'Reading';

  @override
  String get iconWorkout => 'Workout';

  @override
  String get iconWalk => 'Walk';

  @override
  String get iconRun => 'Running';

  @override
  String get iconMeditation => 'Meditation';

  @override
  String get iconSleep => 'Sleep';

  @override
  String get iconEating => 'Eating';

  @override
  String get iconCooking => 'Cooking';

  @override
  String get iconNoSmoking => 'No smoking';

  @override
  String get iconSelfCare => 'Self-care';

  @override
  String get iconCreativity => 'Creativity';

  @override
  String get iconMusic => 'Music';

  @override
  String get iconMind => 'Mind';

  @override
  String get iconLanguage => 'Language';

  @override
  String get iconFocus => 'Focus';

  @override
  String get iconWork => 'Work';

  @override
  String get iconFinance => 'Finance';

  @override
  String get iconCleaning => 'Cleaning';

  @override
  String get iconPhone => 'Phone';

  @override
  String get iconHabit => 'Habit';

  @override
  String get iconFamily => 'Family';

  @override
  String get iconPet => 'Pet';

  @override
  String get iconOutdoors => 'Outdoors';

  @override
  String get achievementFirstStepTitle => 'First step';

  @override
  String get achievementFirstStepDesc => 'Add your first habit';

  @override
  String get achievementOnFireTitle => 'On fire';

  @override
  String get achievementOnFireDesc => '7 days in a row at ≥80% completion';

  @override
  String get achievementUnstoppableTitle => 'Unstoppable';

  @override
  String get achievementUnstoppableDesc =>
      '30 days in a row at ≥80% completion';

  @override
  String get achievementPerfectWeekTitle => 'Perfect week';

  @override
  String get achievementPerfectWeekDesc => '100% completion 7 days in a row';

  @override
  String get achievementHabitMasterTitle => 'Habit master';

  @override
  String get achievementHabitMasterDesc => '5 active habits at once';

  @override
  String get achievementCenturionTitle => 'Centurion';

  @override
  String get achievementCenturionDesc => 'Complete a habit 100 times in total';

  @override
  String get level1 => 'Beginner';

  @override
  String get level2 => 'Novice';

  @override
  String get level3 => 'Trainee';

  @override
  String get level4 => 'Student';

  @override
  String get level5 => 'Explorer';

  @override
  String get level6 => 'Curious';

  @override
  String get level7 => 'Practitioner';

  @override
  String get level8 => 'Craftsman';

  @override
  String get level9 => 'Skilled';

  @override
  String get level10 => 'Seasoned';

  @override
  String get level11 => 'Adept';

  @override
  String get level12 => 'Specialist';

  @override
  String get level13 => 'Master';

  @override
  String get level14 => 'Champion';

  @override
  String get level15 => 'Elite';

  @override
  String get level16 => 'Veteran';

  @override
  String get level17 => 'Legend';

  @override
  String get level18 => 'Mythic';

  @override
  String get level19 => 'Immortal';

  @override
  String get level20 => 'Habit Master';

  @override
  String levelShort(int level) {
    return 'Level $level';
  }

  @override
  String get notifDailyTitle => 'Daily habit review';

  @override
  String get notifDailyBody => 'Mark what you completed today.';

  @override
  String notifMorning(int pct) {
    return '☀️ Good morning! $pct% done';
  }

  @override
  String notifMidday(int pct) {
    return '⚡ Midday check — $pct%';
  }

  @override
  String notifEvening(int pct) {
    return '🌙 Evening review — $pct%';
  }

  @override
  String notifRemaining(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times left',
      one: '$count time left',
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
      other: '$count more habits',
      one: '$count more habit',
    );
    return '$lead + $_temp0';
  }

  @override
  String get channelSmartLoudName => 'Smart reminders (loud)';

  @override
  String get channelSmartSilentName => 'Smart reminders (silent)';

  @override
  String get channelSmartLoudDesc => 'Smart reminders with sound';

  @override
  String get channelSmartSilentDesc => 'Smart reminders without sound';

  @override
  String get channelSmartDesc => 'Smart habit reminders';

  @override
  String get channelDailyName => 'Daily habit reminders';

  @override
  String get channelDailyDesc => 'Daily habit reminders';
}

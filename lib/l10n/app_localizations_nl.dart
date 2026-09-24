// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get navToday => 'Vandaag';

  @override
  String get navCalendar => 'Kalender';

  @override
  String get navStats => 'Statistieken';

  @override
  String get navSettings => 'Instellingen';

  @override
  String get removeAdsCoffee =>
      'Verwijder advertenties voor de prijs van een koffie';

  @override
  String get removeAdsAction => 'Verwijderen';

  @override
  String get widgetTitle => 'Gewoontes';

  @override
  String widgetDone(int done, int total) {
    return '$done / $total vandaag';
  }

  @override
  String widgetStreakLine(int days) {
    return '🔥 reeks van $days dagen';
  }

  @override
  String get widgetEmpty => 'Nog geen gewoontes';

  @override
  String get tplWater => 'Water drinken';

  @override
  String get tplStretch => 'Rekken';

  @override
  String get tplMeditate => 'Mediteren';

  @override
  String get tplJournal => 'Dagboek bijhouden';

  @override
  String get tplSport => 'Bewegen';

  @override
  String get tplSleep => '8 uur slapen';

  @override
  String get tplHealthyFood => 'Gezond eten';

  @override
  String get tplWalk => 'Wandelen';

  @override
  String get tplRead => '30 min lezen';

  @override
  String get tplFocusWork => 'Geconcentreerd werken';

  @override
  String get tplStudy => 'Studeren';

  @override
  String get tplNoPhone => '1 uur geen telefoon';

  @override
  String get tplJoy => 'Vreugde vinden';

  @override
  String get tplNoSocial => 'Social media-pauze';

  @override
  String get purchaseUnavailable =>
      'De aankoop is nu niet beschikbaar. Probeer het later opnieuw.';

  @override
  String get restorePurchasesBtn => 'Aankopen herstellen';

  @override
  String get restoreChecking => 'Eerdere aankopen controleren…';

  @override
  String get homeTitle => 'Vandaag';

  @override
  String get templatesTooltip => 'Sjablonen';

  @override
  String get greetingMorning => 'Goedemorgen';

  @override
  String get greetingAfternoon => 'Goedemiddag';

  @override
  String get greetingEvening => 'Goedenavond';

  @override
  String get perfectDayBonus => '🏆 Perfecte dag! +50 XP bonus';

  @override
  String levelUpTitle(int level) {
    return 'Niveau $level!';
  }

  @override
  String levelXp(int xp) {
    return '$xp XP';
  }

  @override
  String get levelUpContinue => 'Verder!';

  @override
  String achievementUnlocked(String title) {
    return 'Prestatie: $title!';
  }

  @override
  String habitsCompletedToday(int completed, int total) {
    return '$completed / $total gewoontes vandaag voltooid';
  }

  @override
  String get emptyTitle => 'Nog geen gewoontes';

  @override
  String get emptySubtitle =>
      'Voeg er handmatig een toe of kies een kant-en-klaar pakket';

  @override
  String get choosePack => 'Kies een pakket';

  @override
  String get packsTitle => 'Gewoontepakketten';

  @override
  String get packsSubtitle => 'Tik op een pakket om de gewoontes erin te zien';

  @override
  String allHabitsAdded(int total) {
    return 'Alle $total gewoontes toegevoegd';
  }

  @override
  String packSomeAdded(int total, int added) {
    return '$total gewoontes · $added al toegevoegd';
  }

  @override
  String packDescCount(String description, int total) {
    return '$description · $total gewoontes';
  }

  @override
  String nHabits(int count) {
    return '$count gewoontes';
  }

  @override
  String timesPerDayShort(int times) {
    return '${times}x per dag';
  }

  @override
  String get exitBtn => 'Sluiten';

  @override
  String get allAddedShort => 'Alles toegevoegd';

  @override
  String addN(int count) {
    return 'Toevoegen ($count)';
  }

  @override
  String get newHabit => 'Nieuwe gewoonte';

  @override
  String get habitName => 'Naam van de gewoonte';

  @override
  String get habitNameHint => 'bijv. Water drinken';

  @override
  String get timesPerDay => 'Keer per dag';

  @override
  String get iconLabel => 'Pictogram';

  @override
  String get cancel => 'Annuleren';

  @override
  String get add => 'Toevoegen';

  @override
  String get editHabit => 'Gewoonte bewerken';

  @override
  String get save => 'Opslaan';

  @override
  String get deleteHabit => 'Gewoonte verwijderen';

  @override
  String deleteHabitConfirm(String name) {
    return 'Weet je zeker dat je “$name” wilt verwijderen?';
  }

  @override
  String get delete => 'Verwijderen';

  @override
  String packAlreadyAdded(String name) {
    return 'De gewoontes uit “$name” zijn al toegevoegd';
  }

  @override
  String packAddedCount(int count, String name) {
    return '$count gewoontes uit “$name” toegevoegd';
  }

  @override
  String get addHabitFab => 'Gewoonte';

  @override
  String get editMenu => 'Bewerken';

  @override
  String get deleteMenu => 'Verwijderen';

  @override
  String get advancedSection => 'Geavanceerd (Atomic Habits)';

  @override
  String get identityLabel => 'Wie word je?';

  @override
  String get identityHint => 'bijv. een gezond persoon, een lezer';

  @override
  String identityVoteFeedback(String identity) {
    return '+1 stem voor “$identity”';
  }

  @override
  String identityVotesLine(int count, String identity) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stemmen',
      one: '$count stem',
    );
    return '🗳 $_temp0 voor “$identity”';
  }

  @override
  String get miniVersionLabel => 'Miniversie (2 minuten)';

  @override
  String get miniVersionHint => 'bijv. mijn hardloopschoenen aantrekken';

  @override
  String get miniVersionTooltip => 'Miniversie — telt als voltooiing';

  @override
  String get stackAfterLabel => 'Na welke gewoonte?';

  @override
  String get stackAfterNone => 'Geen';

  @override
  String stackAfterCard(String anchor) {
    return '⛓ Na “$anchor”';
  }

  @override
  String notifStackTitle(String habit) {
    return '⛓ Jouw beurt: $habit';
  }

  @override
  String notifStackBody(String anchor) {
    return 'Meteen na “$anchor” — doe het nu.';
  }

  @override
  String get rewardLabel => 'Daarna trakteer ik mezelf op…';

  @override
  String get rewardHint => 'bijv. een aflevering van de serie';

  @override
  String rewardFeedback(String reward) {
    return '🎁 Je hebt het verdiend: $reward';
  }

  @override
  String rewardCard(String reward) {
    return '🎁 Beloning: $reward';
  }

  @override
  String get intentionTimeLabel => 'Tijd';

  @override
  String get intentionPlaceLabel => 'Plaats';

  @override
  String get intentionPlaceHint => 'bijv. in de keuken';

  @override
  String get intentionPick => 'Kies een tijd';

  @override
  String get intentionClear => 'Wissen';

  @override
  String intentionCard(String time) {
    return '🕒 om $time';
  }

  @override
  String intentionCardPlace(String time, String place) {
    return '🕒 om $time · $place';
  }

  @override
  String notifIntentionTitle(String habit) {
    return '🕒 Het is tijd: $habit';
  }

  @override
  String notifIntentionBody(String place) {
    return 'Doe het nu — $place.';
  }

  @override
  String get notifIntentionBodyNoPlace => 'Doe het nu.';

  @override
  String get advancedOptional => 'optioneel';

  @override
  String get atomicIntroTitle => 'Wat zijn Atomic Habits?';

  @override
  String get atomicIntro =>
      'Kleine veranderingen, grote resultaten. In plaats van op motivatie te vertrouwen, maak je de gewoonte duidelijk, makkelijk, aantrekkelijk en belonend. De velden hieronder zijn optioneel — vul alleen in wat je helpt.';

  @override
  String get atomicMenu => 'Atomic Habits';

  @override
  String get newHabitSubtitle => 'Een stap richting wie je wordt';

  @override
  String get iconChangeHint => 'Tik om het pictogram te wijzigen';

  @override
  String get stickTitle => 'Laat het beklijven';

  @override
  String get stickSubtitle => 'Optioneel · uit “Atomic Habits”';

  @override
  String get stickHint =>
      'Vul zoveel in als je wilt — leeg is ook een geldige gewoonte.';

  @override
  String get freqHeading => 'Hoe vaak';

  @override
  String get freqCountDay => 'Hoe vaak per dag';

  @override
  String get freqCountWeek => 'Hoe vaak per week';

  @override
  String get freqCountMonth => 'Hoe vaak per maand';

  @override
  String get freqDay => 'Dag';

  @override
  String get freqWeek => 'Week';

  @override
  String get freqMonth => 'Maand';

  @override
  String get freqWeeklyShort => 'wekelijks';

  @override
  String get freqMonthlyShort => 'maandelijks';

  @override
  String get sentBecome => 'Ik wil worden';

  @override
  String get sentWill => 'Ik doe';

  @override
  String get sentInTime => 'om';

  @override
  String get sentAtPlace => 'in';

  @override
  String get sentAfter => 'Na';

  @override
  String get sentHardDay => 'Zware dag';

  @override
  String get sentThen => 'Dan';

  @override
  String get pillIdentityEmpty => 'identiteit';

  @override
  String get pillNameFallback => 'dit';

  @override
  String get pillTimeEmpty => 'tijd';

  @override
  String get pillPlaceEmpty => 'plaats';

  @override
  String get pillAnchorEmpty => 'gewoonte';

  @override
  String get pillMiniEmpty => 'miniversie';

  @override
  String get pillRewardEmpty => 'beloning';

  @override
  String get sentGoal => 'Doel';

  @override
  String get sentGoalPer => 'per';

  @override
  String get pillGoalEmpty => 'aantal';

  @override
  String get goalPeriodYear => 'Jaar';

  @override
  String get goalPeriodMonth => 'Maand';

  @override
  String get goalPeriodOngoing => 'Totaal';

  @override
  String get editGoalTitle => 'Doel (aantal)';

  @override
  String get goalTargetHint => 'bijv. 24';

  @override
  String get editGoalPeriodTitle => 'Over welke periode?';

  @override
  String get goalCountFromNow => 'Het tellen begint nu';

  @override
  String get periodScopeDay => 'vandaag';

  @override
  String get periodScopeWeek => 'deze week';

  @override
  String get periodScopeMonth => 'deze maand';

  @override
  String goalCardYear(int count, int target, int percent) {
    return '🎯 Jaardoel: $count / $target · $percent%';
  }

  @override
  String goalCardMonth(int count, int target, int percent) {
    return '🎯 Maanddoel: $count / $target · $percent%';
  }

  @override
  String goalCardOngoing(int count, int target, int percent) {
    return '🎯 Totaaldoel: $count / $target · $percent%';
  }

  @override
  String goalCardDone(int target) {
    return '🎯 Doel bereikt: $target / $target ✓';
  }

  @override
  String get goalRaiseHint =>
      'Je bent voorbij je doel — wil je een hoger doel?';

  @override
  String get goalRaiseAction => 'Doel verhogen';

  @override
  String get goalRaiseDismiss => 'Sluiten';

  @override
  String get voteBadge => '+1 STEM';

  @override
  String voteTagText(String identity) {
    return 'Elke afvinking is een stem dat je “$identity” bent';
  }

  @override
  String get editIdentityTitle => 'Wie word je?';

  @override
  String get editPlaceTitle => 'Waar ga je het doen?';

  @override
  String get editMiniTitle => 'Miniversie voor een zware dag';

  @override
  String get editRewardTitle => 'Beloning achteraf';

  @override
  String get editAnchorTitle => 'Na welke gewoonte?';

  @override
  String get editTimeTitle => 'Wanneer?';

  @override
  String get timePickChoose => 'Kies een tijd';

  @override
  String get timeRemove => 'Tijd verwijderen';

  @override
  String get editDone => 'Klaar';

  @override
  String get atomicIdentityTitle => 'Identiteit';

  @override
  String get atomicIdentityDesc =>
      'Elke afvinking is een stem voor de persoon die je wordt.';

  @override
  String get atomicMiniTitle => 'Makkelijke start (2 minuten)';

  @override
  String get atomicMiniDesc => 'Verklein de gewoonte tot iets van 2 minuten.';

  @override
  String get atomicWhenTitle => 'Wanneer en waar';

  @override
  String get atomicWhenDesc =>
      'Een concreet plan wordt op dat moment een echte herinnering.';

  @override
  String get atomicStackTitle => 'Na een andere gewoonte';

  @override
  String get atomicStackDesc => 'Koppel het meteen na iets wat je al doet.';

  @override
  String get atomicRewardTitle => 'Beloning';

  @override
  String get atomicRewardDesc =>
      'Gun jezelf meteen daarna een kleine traktatie.';

  @override
  String intentionSentence(String time) {
    return 'Ik doe dit om $time';
  }

  @override
  String intentionSentencePlace(String time, String place) {
    return 'Ik doe dit om $time · $place';
  }

  @override
  String get monthSummaryCompleted => 'voltooid';

  @override
  String get monthSummaryBestStreak => 'beste reeks';

  @override
  String get monthSummaryAvg => 'gem. succes';

  @override
  String get legendFull => 'Volledig voltooid';

  @override
  String get legendPartial => 'Gedeeltelijk';

  @override
  String get legendMissed => 'Gemist';

  @override
  String get legendPaused => 'Buiten het programma';

  @override
  String get heatmapPaused => 'Gepauzeerd';

  @override
  String get pauseMarkPeriod => 'Markeer een periode buiten het programma';

  @override
  String get pauseMarkDay => 'Markeer als buiten het programma';

  @override
  String get pauseRemove => 'Terug in het programma brengen';

  @override
  String get pauseDayIsPaused =>
      'Deze dag valt buiten het programma — hij telt niet als gemist.';

  @override
  String pauseDaySuccess(int percent) {
    return 'Succes: $percent%';
  }

  @override
  String get pauseListTitle => 'Dagen buiten het programma';

  @override
  String get pauseSettingsHint =>
      'Ga je op vakantie of ben je ziek? Markeer dagen als “buiten het programma” vanuit de Kalender — je reeks blijft intact en ze tellen niet als gemist.';

  @override
  String get commonOk => 'OK';

  @override
  String get whatsNewTitle => 'Wat is er nieuw';

  @override
  String get whatsNewGotIt => 'Begrepen';

  @override
  String get whatsNewPauseTitle => 'Dagen buiten het programma';

  @override
  String get whatsNewPauseBody =>
      'Ga je op vakantie of ben je ziek? Markeer dagen of een periode vanuit de Kalender — je reeks blijft intact en die dagen tellen niet als gemist.';

  @override
  String get whatsNewGoalTitle => 'Numeriek gewoontedoel';

  @override
  String get whatsNewGoalBody =>
      'Stel een doel in zoals 24 per jaar of 12 per maand en volg een live teller.';

  @override
  String get whatsNewWidgetTitle => 'Widget op het beginscherm';

  @override
  String get whatsNewWidgetBody =>
      'Zie de voortgang, het aantal en de reeks van vandaag direct op je beginscherm.';

  @override
  String get statsTitle => 'Statistieken';

  @override
  String get statOverallSuccess => 'Algemeen succes';

  @override
  String get statCurrentStreak => 'Huidige reeks';

  @override
  String get statLongestStreak => 'Langste reeks';

  @override
  String get statActiveHabits => 'Actieve gewoontes';

  @override
  String statDays(int count) {
    return '$count dagen';
  }

  @override
  String get last7Days => 'Laatste 7 dagen';

  @override
  String get achievementsTitle => 'Prestaties';

  @override
  String levelAndTitle(int level, String title) {
    return 'Niveau $level · $title';
  }

  @override
  String xpToNextLevel(int xp, int remaining) {
    return '$xp XP · $remaining tot volgend niveau';
  }

  @override
  String xpMaxLevel(int xp) {
    return '$xp XP · Maximaal niveau!';
  }

  @override
  String get settingsTitle => 'Instellingen';

  @override
  String get sectionProfile => 'Profiel';

  @override
  String get sectionAds => 'Advertenties';

  @override
  String get sectionAppearance => 'Weergave';

  @override
  String get sectionReminders => 'Herinneringen';

  @override
  String get sectionMusic => 'Muziek';

  @override
  String get sectionData => 'Gegevens';

  @override
  String get sectionStreak => 'Reeks';

  @override
  String get sectionLanguage => 'Taal';

  @override
  String get sectionInfo => 'Informatie';

  @override
  String get streakFreeze => 'Gratiedag';

  @override
  String get streakFreezeSub => 'Eén gemiste dag breekt je reeks niet';

  @override
  String get heatmapTitle => 'Activiteit dit jaar';

  @override
  String get heatmapLess => 'Minder';

  @override
  String get heatmapMore => 'Meer';

  @override
  String get profileAdFree => '✨ Advertentievrij';

  @override
  String get profileFreePlan => 'Gratis abonnement';

  @override
  String get editTooltip => 'Bewerken';

  @override
  String get yourName => 'Je naam';

  @override
  String get nickname => 'Bijnaam';

  @override
  String get adsRemovedTitle => 'Advertenties verwijderd';

  @override
  String get adsRemovedThanks => 'Bedankt voor je steun!';

  @override
  String get adFreeShort => 'Advertentievrij';

  @override
  String get adsRemoveSupport =>
      'Steun de app en verwijder de advertenties voorgoed.';

  @override
  String get musicHint =>
      'Ontspannende muziek speelt met de ♪-knop in de bovenbalk.';

  @override
  String get sleepTimer => 'Slaaptimer';

  @override
  String get timerOff => 'Uit';

  @override
  String timerMinutes(int count) {
    return '$count min';
  }

  @override
  String get dataHint =>
      'Bewaar je gewoontes en geschiedenis in een bestand, of herstel ze op een ander apparaat.';

  @override
  String get backupBtn => 'Back-up';

  @override
  String get restoreBtn => 'Herstellen';

  @override
  String get saveBackupDialog => 'Back-up opslaan';

  @override
  String get backupSaved => 'Back-up opgeslagen.';

  @override
  String get backupError => 'Fout bij het maken van de back-up.';

  @override
  String get restoreSuccess => 'Je gegevens zijn hersteld.';

  @override
  String get restoreInvalid => 'Ongeldig herstelbestand.';

  @override
  String get restoreTooNew =>
      'Deze back-up komt van een nieuwere versie van de app. Werk de app bij om hem te herstellen.';

  @override
  String get restoreConfirmTitle => 'Gegevens herstellen';

  @override
  String get restoreConfirmBody =>
      'Dit vervangt je huidige gegevens door de back-up. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get restoreReplace => 'Vervangen';

  @override
  String get themeDark => 'Donker';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeLight => 'Licht';

  @override
  String get languageBulgarian => 'Български';

  @override
  String get languageEnglish => 'English';

  @override
  String get dailyReminder => 'Dagelijkse herinnering';

  @override
  String get dailyReminderSub => 'Elke dag op een vast tijdstip';

  @override
  String get reminderTime => 'Tijd';

  @override
  String get smartReminders => 'Slimme herinneringen';

  @override
  String get smartRemindersSub =>
      'Volgt je voortgang — herinnert je alleen wanneer nodig (09:00 / 14:00 / 19:30)';

  @override
  String get silent => 'Stil';

  @override
  String get silentSub => 'Slimme herinneringen — geen geluid of trilling';

  @override
  String get remindersUpdated => 'Herinneringen bijgewerkt.';

  @override
  String get version => 'Versie';

  @override
  String get infoTagline =>
      'Gewoontes — een gewoonte-tracker met XP, prestaties en slimme herinneringen.';

  @override
  String get skip => 'Overslaan';

  @override
  String get next => 'Volgende';

  @override
  String get start => 'Starten!';

  @override
  String get onboardTagline => 'Bouw betere gewoontes op.\nVerander je leven.';

  @override
  String get onboardFeature1 => 'Volg je gewoontes elke dag';

  @override
  String get onboardFeature2 =>
      'Reeksen en een XP-systeem om je gemotiveerd te houden';

  @override
  String get onboardFeature3 => 'Prestaties voor elke mijlpaal';

  @override
  String get onboardTrackTitle => 'Volg je voortgang';

  @override
  String get onboardTrackSub => 'Zie hoe je dag na dag beter wordt';

  @override
  String get todayProgress => 'Voortgang van vandaag';

  @override
  String get miniStatDays => 'dagen reeks';

  @override
  String get miniStatAchievements => 'prestaties';

  @override
  String get onboardNameTitle => 'Hoe zullen we je noemen?';

  @override
  String get onboardNameSub => 'Voer je naam of een bijnaam in';

  @override
  String get yourNameHint => 'Je naam...';

  @override
  String get canSkip => '(je kunt dit overslaan)';

  @override
  String get onboardPackTitle => 'Kies een startpakket';

  @override
  String get onboardPackSub =>
      'Je kunt later gewoontes toevoegen en verwijderen';

  @override
  String get paywallFeatureUnlimited => 'Onbeperkt gewoontes';

  @override
  String get paywallFeatureTemplates => 'Alle sjablonen';

  @override
  String get paywallFeatureXp => 'XP-systeem en prestaties';

  @override
  String get paywallFeatureStats => 'Gedetailleerde statistieken';

  @override
  String get paywallFeatureNoAds => 'Advertentievrij';

  @override
  String get planMonthly => 'Maandelijks';

  @override
  String get planYearly => 'Jaarlijks';

  @override
  String get planLifetime => 'Levenslang';

  @override
  String get perMonth => '/maand';

  @override
  String get perYear => '/jaar';

  @override
  String get oneTime => 'eenmalig';

  @override
  String get popular => 'Populair';

  @override
  String get paywallTagline => 'Bereik elke dag meer';

  @override
  String get continuePremium => 'Doorgaan met Premium';

  @override
  String get restorePurchase => 'Aankoop herstellen';

  @override
  String get cancelAnytime => 'Altijd opzegbaar via Google Play.';

  @override
  String get purchaseAfterPublish =>
      'Aankopen worden actief na publicatie in de Play Store.';

  @override
  String get purchasesChecked => 'Aankopen zijn gecontroleerd.';

  @override
  String get stopMusic => 'Muziek stoppen';

  @override
  String get relaxingMusic => 'Ontspannende muziek';

  @override
  String get templateMorningName => 'Ochtendroutine';

  @override
  String get templateMorningDesc => 'Begin je dag met energie en focus';

  @override
  String get templateHealthName => 'Gezond leven';

  @override
  String get templateHealthDesc => 'Lichaam en geest in balans';

  @override
  String get templateFocusName => 'Productiviteit';

  @override
  String get templateFocusDesc => 'Bereik elke dag meer';

  @override
  String get templateMindfulnessName => 'Balans';

  @override
  String get templateMindfulnessDesc => 'Rust en aandacht';

  @override
  String get iconWater => 'Water';

  @override
  String get iconReading => 'Lezen';

  @override
  String get iconWorkout => 'Training';

  @override
  String get iconWalk => 'Wandelen';

  @override
  String get iconRun => 'Hardlopen';

  @override
  String get iconMeditation => 'Meditatie';

  @override
  String get iconSleep => 'Slaap';

  @override
  String get iconEating => 'Eten';

  @override
  String get iconCooking => 'Koken';

  @override
  String get iconNoSmoking => 'Niet roken';

  @override
  String get iconSelfCare => 'Zelfzorg';

  @override
  String get iconCreativity => 'Creativiteit';

  @override
  String get iconMusic => 'Muziek';

  @override
  String get iconMind => 'Geest';

  @override
  String get iconLanguage => 'Taal';

  @override
  String get iconFocus => 'Focus';

  @override
  String get iconWork => 'Werk';

  @override
  String get iconFinance => 'Financiën';

  @override
  String get iconCleaning => 'Schoonmaken';

  @override
  String get iconPhone => 'Telefoon';

  @override
  String get iconHabit => 'Gewoonte';

  @override
  String get iconFamily => 'Familie';

  @override
  String get iconPet => 'Huisdier';

  @override
  String get iconOutdoors => 'Buiten';

  @override
  String get achievementFirstStepTitle => 'Eerste stap';

  @override
  String get achievementFirstStepDesc => 'Voeg je eerste gewoonte toe';

  @override
  String get achievementOnFireTitle => 'In vuur en vlam';

  @override
  String get achievementOnFireDesc => '7 dagen op rij op ≥80% voltooiing';

  @override
  String get achievementUnstoppableTitle => 'Niet te stoppen';

  @override
  String get achievementUnstoppableDesc => '30 dagen op rij op ≥80% voltooiing';

  @override
  String get achievementPerfectWeekTitle => 'Perfecte week';

  @override
  String get achievementPerfectWeekDesc => '100% voltooiing 7 dagen op rij';

  @override
  String get achievementHabitMasterTitle => 'Gewoontemeester';

  @override
  String get achievementHabitMasterDesc => '5 actieve gewoontes tegelijk';

  @override
  String get achievementCenturionTitle => 'Centurio';

  @override
  String get achievementCenturionDesc =>
      'Voltooi een gewoonte in totaal 100 keer';

  @override
  String get level1 => 'Beginner';

  @override
  String get level2 => 'Nieuweling';

  @override
  String get level3 => 'Leerling';

  @override
  String get level4 => 'Student';

  @override
  String get level5 => 'Ontdekker';

  @override
  String get level6 => 'Nieuwsgierig';

  @override
  String get level7 => 'Beoefenaar';

  @override
  String get level8 => 'Vakman';

  @override
  String get level9 => 'Bekwaam';

  @override
  String get level10 => 'Ervaren';

  @override
  String get level11 => 'Adept';

  @override
  String get level12 => 'Specialist';

  @override
  String get level13 => 'Meester';

  @override
  String get level14 => 'Kampioen';

  @override
  String get level15 => 'Elite';

  @override
  String get level16 => 'Veteraan';

  @override
  String get level17 => 'Legende';

  @override
  String get level18 => 'Mythisch';

  @override
  String get level19 => 'Onsterfelijk';

  @override
  String get level20 => 'Gewoontemeester';

  @override
  String levelShort(int level) {
    return 'Niveau $level';
  }

  @override
  String get notifDailyTitle => 'Dagelijkse gewoontecheck';

  @override
  String get notifDailyBody => 'Markeer wat je vandaag hebt voltooid.';

  @override
  String notifMorning(int pct) {
    return '☀️ Goedemorgen! $pct% klaar';
  }

  @override
  String notifMidday(int pct) {
    return '⚡ Middagcheck — $pct%';
  }

  @override
  String notifEvening(int pct) {
    return '🌙 Avondcheck — $pct%';
  }

  @override
  String notifRemaining(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'nog $count keer',
      one: 'nog $count keer',
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
      other: 'nog $count gewoontes',
      one: 'nog $count gewoonte',
    );
    return '$lead + $_temp0';
  }

  @override
  String get channelSmartLoudName => 'Slimme herinneringen (luid)';

  @override
  String get channelSmartSilentName => 'Slimme herinneringen (stil)';

  @override
  String get channelSmartLoudDesc => 'Slimme herinneringen met geluid';

  @override
  String get channelSmartSilentDesc => 'Slimme herinneringen zonder geluid';

  @override
  String get channelSmartDesc => 'Slimme gewoonteherinneringen';

  @override
  String get channelDailyName => 'Dagelijkse gewoonteherinneringen';

  @override
  String get channelDailyDesc => 'Dagelijkse gewoonteherinneringen';
}

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../models/habit.dart';
import 'habit_service.dart';

/// Loads the localized strings for the user's saved language WITHOUT a
/// BuildContext. Notifications (incl. the background midnight isolate) are built
/// off the widget tree, so `AppLocalizations.of(context)` is unavailable here.
/// Mirrors the UI's language resolution: saved pref, else device language when
/// Bulgarian, else English.
Future<AppLocalizations> _loadNotifL10n() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('language');
  final code = (saved == 'bg' || saved == 'en')
      ? saved!
      : (ui.PlatformDispatcher.instance.locale.languageCode == 'bg'
          ? 'bg'
          : 'en');
  return AppLocalizations.delegate.load(Locale(code));
}

const bool kSmartQuickTest = false;

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> midnightRescheduleCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));

  await NotificationService().init();

  final prefs = await SharedPreferences.getInstance();
  final habitsStr = prefs.getString(kPrefsHabits);

  if (habitsStr != null) {
    try {
      final List<dynamic> data = jsonDecode(habitsStr) as List<dynamic>;
      final habits =
          data.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();

      for (final h in habits) {
        h.completedTimes = 0;
      }

      await prefs.setString(
          kPrefsHabits, jsonEncode(habits.map((h) => h.toJson()).toList()));
      // Mark today as handled so the cross-platform lazy reset doesn't run again.
      await prefs.setString(kPrefsLastActiveDate, dateKeyFromDate(DateTime.now()));

      await NotificationService().cancelSmartReminders();
      await NotificationService().scheduleSmartRemindersForToday(habits);
    } catch (_) {}
  }

  await scheduleNextMidnightAlarm();
}

// FIX: was now + 1 minute; now correctly targets next midnight (00:01)
Future<void> scheduleNextMidnightAlarm() async {
  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 1);
  const int alarmId = 5001;

  if (!Platform.isAndroid) return;

  await AndroidAlarmManager.oneShotAt(
    nextMidnight,
    alarmId,
    midnightRescheduleCallback,
    exact: true,
    wakeup: true,
    rescheduleOnReboot: false,
  );
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  Future<void>? _initFuture;

  // Smart reminder notification IDs occupy [kSmartIdStart, kSmartIdEnd].
  static const int kSmartIdStart = 3100;
  static const int kSmartIdEnd = 3110;
  // Habit-stacking cue IDs occupy [kStackIdStart, kStackIdStart+255].
  static const int kStackIdStart = 4000;

  Future<void> cancelSmartReminders() async {
    await init();
    for (var id = kSmartIdStart; id <= kSmartIdEnd; id++) {
      await notificationsPlugin.cancel(id);
    }
  }

  /// Idempotent + concurrency-safe: the first call does the work and every
  /// later or concurrent caller awaits that same future. Heavy init now runs
  /// AFTER the first frame, so a user action (e.g. toggling a reminder in
  /// Settings) can reach the schedule methods before background init has
  /// finished — those methods await this, so nothing ever schedules against an
  /// uninitialized plugin or an unset timezone.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    final l10n = await _loadNotifL10n();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS permissions are requested explicitly below, not during init.
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: darwinInit);
    await notificationsPlugin.initialize(initSettings);

    // Channel IDs ('smart_loud'/'smart_silent') are stable — only the display
    // name/description are localized. (Android caches an existing channel's
    // name, so an in-place language switch won't rename already-created ones.)
    final AndroidNotificationChannel smartLoudChannel = AndroidNotificationChannel(
      'smart_loud',
      l10n.channelSmartLoudName,
      description: l10n.channelSmartLoudDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final AndroidNotificationChannel smartSilentChannel = AndroidNotificationChannel(
      'smart_silent',
      l10n.channelSmartSilentName,
      description: l10n.channelSmartSilentDesc,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    if (kSmartQuickTest) {
      final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 15));
      final androidDetails = AndroidNotificationDetails(
        'smart_loud',
        l10n.channelSmartLoudName,
        channelDescription: l10n.channelSmartLoudDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await notificationsPlugin.zonedSchedule(
        9099,
        'LOUD TEST',
        'Test notification (15s) — if you see/hear it, all is OK.',
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
    }

    final androidPlugin = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(smartLoudChannel);
    await androidPlugin?.createNotificationChannel(smartSilentChannel);
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleDailyReminderAt(TimeOfDay time) async {
    await init();
    final l10n = await _loadNotifL10n();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final androidDetails = AndroidNotificationDetails(
      'smart_loud',
      l10n.channelDailyName,
      channelDescription: l10n.channelDailyDesc,
      importance: Importance.max,
      priority: Priority.high,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await notificationsPlugin.zonedSchedule(
      2000,
      l10n.notifDailyTitle,
      l10n.notifDailyBody,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    await init();
    await notificationsPlugin.cancel(2000);
  }

  // Smart slots: (hour, minute, progressThreshold)
  // Fires at that time only if completion < threshold
  static const _smartSlots = [
    (9, 0, 0.3),   // 09:00 — send if < 30% done
    (14, 0, 0.6),  // 14:00 — send if < 60% done
    (19, 30, 1.0), // 19:30 — send if not fully done
  ];

  Future<void> scheduleSmartRemindersForToday(List<Habit> habits) async {
    await init();
    // Always clear the whole range first so a re-schedule never leaves stale
    // reminders for habits that have since been completed or deleted.
    await cancelSmartReminders();

    final l10n = await _loadNotifL10n();
    final prefs = await SharedPreferences.getInstance();
    final profileStr = prefs.getString(kPrefsProfile);
    bool smartEnabled = true;
    bool isSilent = false;
    if (profileStr != null) {
      try {
        final data = jsonDecode(profileStr) as Map<String, dynamic>;
        smartEnabled = data['smartRemindersEnabled'] as bool? ?? true;
        isSilent = data['smartRemindersSilent'] as bool? ?? false;
      } catch (_) {}
    }
    if (!smartEnabled) return;

    final incomplete = habits
        .where((h) => h.timesPerDay > 0 && h.completedTimes < h.timesPerDay)
        .toList();
    if (incomplete.isEmpty) return;

    // Target the habit that is the most behind (largest remaining fraction),
    // so the reminder always nudges what needs the most attention.
    incomplete.sort((a, b) {
      final ra = (a.timesPerDay - a.completedTimes) / a.timesPerDay;
      final rb = (b.timesPerDay - b.completedTimes) / b.timesPerDay;
      return rb.compareTo(ra);
    });

    final total = habits.fold<int>(0, (s, h) => s + h.timesPerDay);
    final done = habits.fold<int>(0, (s, h) => s + h.completedTimes);
    final progress = total == 0 ? 1.0 : done / total;
    final pct = (progress * 100).round();

    final now = tz.TZDateTime.now(tz.local);
    final channel = isSilent ? 'smart_silent' : 'smart_loud';
    int notifId = kSmartIdStart;

    for (final slot in _smartSlots) {
      if (progress >= slot.$3) continue; // already past threshold — skip

      final slotTime = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, slot.$1, slot.$2);
      // Skip slots that are in the past (or within the next 3 min).
      if (!slotTime.isAfter(now.add(const Duration(minutes: 3)))) continue;

      final title = slot.$1 < 12
          ? l10n.notifMorning(pct)
          : slot.$1 < 17
              ? l10n.notifMidday(pct)
              : l10n.notifEvening(pct);

      await notificationsPlugin.zonedSchedule(
        notifId,
        title,
        _smartBody(l10n, incomplete),
        slotTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            isSilent ? l10n.channelSmartSilentName : l10n.channelSmartLoudName,
            channelDescription: l10n.channelSmartDesc,
            importance: isSilent ? Importance.low : Importance.high,
            priority: isSilent ? Priority.low : Priority.high,
            playSound: !isSilent,
            enableVibration: !isSilent,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: !isSilent,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      notifId++;
      if (notifId > kSmartIdEnd) break;
    }
  }

  /// Habit stacking: fires an immediate "your turn" cue for [next] right after
  /// its anchor habit [anchor] was completed. Uses show() (not zonedSchedule) —
  /// the trigger is the anchor's completion event, not a clock time. The id is
  /// derived from [next]'s id so repeated triggers replace rather than stack.
  Future<void> showStackReminder(Habit next, Habit anchor) async {
    await init();
    final l10n = await _loadNotifL10n();
    final id = kStackIdStart + (next.id.hashCode & 0xff);
    await notificationsPlugin.show(
      id,
      l10n.notifStackTitle(next.name),
      l10n.notifStackBody(anchor.name),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_loud',
          l10n.channelSmartLoudName,
          channelDescription: l10n.channelSmartDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Builds a concise reminder body. For a single outstanding habit it shows
  /// how many times remain; for several it leads with the most-behind one and
  /// summarizes the rest (e.g. "Спорт + още 2 навика").
  String _smartBody(AppLocalizations l10n, List<Habit> incomplete) {
    final lead = incomplete.first;
    final remaining = lead.timesPerDay - lead.completedTimes;
    if (incomplete.length == 1) {
      return l10n.notifRemaining(lead.name, remaining);
    }
    final others = incomplete.length - 1;
    final lead2 =
        remaining > 1 ? l10n.notifLeadWithCount(lead.name, remaining) : lead.name;
    return l10n.notifPlusMore(lead2, others);
  }
}

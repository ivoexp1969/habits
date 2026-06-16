import 'dart:convert';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit.dart';
import 'habit_service.dart';

const bool kSmartQuickTest = false;

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> midnightRescheduleCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));

  debugPrint('MIDNIGHT: callback fired at ${DateTime.now().toIso8601String()}');

  await NotificationService().init();

  final prefs = await SharedPreferences.getInstance();
  final habitsStr = prefs.getString(kPrefsHabits);
  debugPrint('MIDNIGHT: habitsStr len=${habitsStr?.length ?? 0}');

  if (habitsStr != null) {
    try {
      final List<dynamic> data = jsonDecode(habitsStr) as List<dynamic>;
      final habits =
          data.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();

      int beforeSum = 0;
      for (final h in habits) {
        beforeSum += h.completedTimes;
      }

      for (final h in habits) {
        h.completedTimes = 0;
      }

      await prefs.setString(
          kPrefsHabits, jsonEncode(habits.map((h) => h.toJson()).toList()));
      // Mark today as handled so the cross-platform lazy reset doesn't run again.
      await prefs.setString(kPrefsLastActiveDate, dateKeyFromDate(DateTime.now()));
      debugPrint('MIDNIGHT: reset done; beforeSum=$beforeSum habits=${habits.length}');

      await NotificationService().cancelSmartReminders();
      await NotificationService().scheduleSmartRemindersForToday(habits);
      debugPrint('MIDNIGHT: rescheduled smart reminders');
    } catch (e) {
      debugPrint('MIDNIGHT: error $e');
    }
  } else {
    debugPrint('MIDNIGHT: no habitsStr');
  }

  await scheduleNextMidnightAlarm();
  debugPrint('MIDNIGHT: next alarm scheduled');
}

// FIX: was now + 1 minute; now correctly targets next midnight (00:01)
Future<void> scheduleNextMidnightAlarm() async {
  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 1);
  const int alarmId = 5001;

  if (!Platform.isAndroid) return;

  debugPrint('MIDNIGHT: scheduled for $nextMidnight');
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

  bool _initialized = false;

  Future<void> cancelSmartReminders() async {
    for (var id = 3100; id <= 3104; id++) {
      await notificationsPlugin.cancel(id);
    }
    debugPrint('SMART: cancelled 3100..3104');
  }

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

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

    const AndroidNotificationChannel smartLoudChannel = AndroidNotificationChannel(
      'smart_loud',
      'Smart reminders (loud)',
      description: 'Интелигентни напомняния със звук',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel smartSilentChannel = AndroidNotificationChannel(
      'smart_silent',
      'Smart reminders (silent)',
      description: 'Интелигентни напомняния без звук',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    if (kSmartQuickTest) {
      final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 15));
      const androidDetails = AndroidNotificationDetails(
        'smart_loud',
        'Smart reminders (loud)',
        channelDescription: 'Интелигентни напомняния със звук',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await notificationsPlugin.zonedSchedule(
        9099,
        'LOUD TEST',
        'Тестова нотификация (15 сек) – ако я видиш/чуеш, всичко е ОК.',
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
      debugPrint('SMART: LOUD TEST scheduled for $when');
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

    _initialized = true;
  }

  Future<void> scheduleDailyReminderAt(TimeOfDay time) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final androidDetails = AndroidNotificationDetails(
      'smart_loud',
      'Daily habit reminders',
      channelDescription: 'Ежедневни напомняния за навици',
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
      'Ежедневен преглед на навиците',
      'Маркирай какво изпълни днес.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
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
    for (var id = 3100; id <= 3110; id++) {
      await notificationsPlugin.cancel(id);
    }

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

    final total = habits.fold<int>(0, (s, h) => s + h.timesPerDay);
    final done = habits.fold<int>(0, (s, h) => s + h.completedTimes);
    final progress = total == 0 ? 1.0 : done / total;

    final now = tz.TZDateTime.now(tz.local);
    final channel = isSilent ? 'smart_silent' : 'smart_loud';
    int notifId = 3100;

    for (final slot in _smartSlots) {
      if (progress >= slot.$3) continue; // already past threshold — skip

      final slotTime = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, slot.$1, slot.$2);
      if (!slotTime.isAfter(now.add(const Duration(minutes: 3)))) continue;

      final habit = incomplete[notifId % incomplete.length];
      final remaining = habit.timesPerDay - habit.completedTimes;
      final pct = (progress * 100).round();

      final title = slot.$1 < 12
          ? '☀️ Добро утро! $pct% изпълнено'
          : slot.$1 < 17
              ? '⚡ Обедна проверка — $pct%'
              : '🌙 Вечерен преглед — $pct%';

      final body = remaining > 1
          ? '${habit.name} — остават $remaining пъти'
          : '${habit.name} — остава 1 път';

      await notificationsPlugin.zonedSchedule(
        notifId,
        title,
        body,
        slotTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            isSilent ? 'Smart reminders (silent)' : 'Smart reminders (loud)',
            channelDescription: 'Интелигентни напомняния за навици',
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
      if (notifId > 3104) break;
    }

    debugPrint('SMART: scheduled ${notifId - 3100} reminders (progress=${(progress * 100).round()}%)');
  }
}

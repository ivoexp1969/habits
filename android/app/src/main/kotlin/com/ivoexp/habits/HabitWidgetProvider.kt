package com.ivoexp.habits

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Home-screen (launcher) widget for Навици. Renders today's progress that the
 * Flutter side pushes via home_widget (WidgetService). Tapping opens the app.
 * All display strings are computed + localized in Flutter, so this only paints
 * them into the RemoteViews.
 *
 * Midnight rollover WITHOUT opening the app: the app stamps `widget_data_day`
 * (local yyyy-MM-dd) with the data. Here we compare it to the device's local
 * "today" (dayState); if it's stale we paint the period-aware zero values
 * instead of yesterday's. updatePeriodMillis (30 min) is a best-effort trigger,
 * but OEMs (Samsung One UI) throttle it when the app sleeps — so the manifest
 * also delivers DATE_CHANGED / TIME_SET / TIMEZONE_CHANGED here (see onReceive),
 * which fire reliably at midnight / on a clock change. No exact alarm (Play).
 */
class HabitWidgetProvider : HomeWidgetProvider() {
    // Samsung One UI (and other aggressive OEMs) throttle updatePeriodMillis when
    // the app is asleep, so onUpdate can fail to run for many hours — the widget
    // then shows yesterday's numbers. These system broadcasts (midnight, manual
    // time change, timezone change) reach a manifest receiver reliably, so we
    // force a refresh on them. AppWidgetProvider.onReceive only routes
    // APPWIDGET_UPDATE to onUpdate, so we re-dispatch onUpdate ourselves here.
    // No exact alarm / SCHEDULE_EXACT_ALARM (Play policy).
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_MIDNIGHT, // our own inexact alarm fired (next local midnight)
            Intent.ACTION_DATE_CHANGED, // pre-API-26 only (not an 8.0 exception)
            Intent.ACTION_TIME_CHANGED, // TIME_SET — exempt on 8+
            Intent.ACTION_TIMEZONE_CHANGED, // exempt on 8+
            Intent.ACTION_BOOT_COMPLETED, // alarms cleared on reboot → re-arm
            Intent.ACTION_MY_PACKAGE_REPLACED -> // alarms cleared on update → re-arm
                refreshAndReschedule(context, intent.action ?: "")
        }
    }

    // Repaint every widget now and re-arm the midnight alarm. ACTION_DATE_CHANGED
    // does NOT reach a manifest receiver on API 26+ (it is not an implicit-
    // broadcast exception), which is why build 41 never rolled over at midnight —
    // so the real trigger is the inexact alarm below, fired by an EXPLICIT
    // broadcast to our own component (always delivered). No exact alarm.
    private fun refreshAndReschedule(context: Context, reason: String) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, HabitWidgetProvider::class.java))
        val data = HomeWidgetPlugin.getData(context)
        widgetLog(data, "onReceive $reason -> refresh ${ids.size}")
        if (ids.isNotEmpty()) onUpdate(context, manager, ids, data)
        scheduleMidnight(context)
    }

    // Inexact alarm for the next local midnight + 1 min. setAndAllowWhileIdle
    // fires even in Doze and needs NO SCHEDULE_EXACT_ALARM permission; being
    // inexact it may fire a little late, which is fine for a day rollover.
    // Re-armed on every onUpdate and on each time/timezone change, so it is
    // always set for the next midnight without opening the app.
    private fun scheduleMidnight(context: Context) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val next = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 1)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val pi = PendingIntent.getBroadcast(
                context, 0,
                Intent(context, HabitWidgetProvider::class.java).setAction(ACTION_MIDNIGHT),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, pi)
        } catch (e: Exception) {
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val dataDay = widgetData.getString("widget_data_day", null)
        val today = todayKey()
        val state = dayState(dataDay)
        // На граница на седмица/месец пушнатият period-aware нул е невалиден за
        // седмични/месечни навици → принудително "0 / N" за всички.
        val boundary = crossedPeriodBoundary(dataDay)
        val cz = widgetData.getString("widget_count_line_zero", "0 / 0") ?: "0 / 0"
        widgetLog(widgetData,
            "onUpdate day=$dataDay today=$today state=$state zero=[$cz] n=${appWidgetIds.size}")

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.habit_widget)

            val title = widgetData.getString("widget_title", "Навици") ?: "Навици"

            val count: String
            val percent: Int
            val streak: String
            when (state) {
                1 -> { // точно вчера → 0 / N (period-aware), серията остава
                    count = if (boundary) allZeroCount(cz) else cz
                    percent = if (boundary) 0 else widgetData.getInt("widget_percent_zero", 0)
                    streak = widgetData.getString("widget_streak_line", "") ?: ""
                }
                2 -> { // 2+ дни стари → 0 / N, серията се скрива (вече ненадеждна)
                    count = if (boundary) allZeroCount(cz) else cz
                    percent = if (boundary) 0 else widgetData.getInt("widget_percent_zero", 0)
                    streak = ""
                }
                else -> { // днес/бъдеще ИЛИ без ключ (стари инсталации) → пушнатите стойности
                    count = widgetData.getString("widget_count_line", "0 / 0") ?: "0 / 0"
                    percent = widgetData.getInt("widget_percent", 0)
                    streak = widgetData.getString("widget_streak_line", "") ?: ""
                }
            }

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_count, count)
            views.setProgressBar(R.id.widget_progress, 100, percent, false)
            views.setTextViewText(R.id.widget_streak, streak)

            // Whole widget taps through to the app.
            val launch = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, launch)

            appWidgetManager.updateAppWidget(id, views)
        }
        // Always (re)arm the next-midnight alarm — the reliable rollover trigger.
        scheduleMidnight(context)
    }

    // Mirrors WidgetService.widgetDayState (Dart) + dayState (Swift):
    //  -1 no key (old install) → old behaviour; 0 today/future; 1 yesterday; 2 older.
    //  LOCAL only (SimpleDateFormat/Calendar default time zone) — never UTC.
    private fun dayState(dataDay: String?): Int {
        if (dataDay.isNullOrEmpty()) return -1
        return try {
            val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val cal = Calendar.getInstance()
            val today = fmt.format(cal.time)
            cal.add(Calendar.DAY_OF_MONTH, -1)
            val yesterday = fmt.format(cal.time)
            when {
                dataDay >= today -> 0
                dataDay == yesterday -> 1
                else -> 2
            }
        } catch (e: Exception) {
            -1
        }
    }

    // Local "today" yyyy-MM-dd (default time zone, never UTC) — for the diag log.
    private fun todayKey(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)

    // Appends to the shared diagnostics log (home_widget prefs, key
    // "widget_diag_log", capped at 20) that the app reads on its hidden
    // diagnostics screen — so we can see WHEN onUpdate actually ran overnight.
    private fun widgetLog(prefs: SharedPreferences, msg: String) {
        try {
            val fmt = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)
            val existing = prefs.getString("widget_diag_log", "") ?: ""
            val lines =
                if (existing.isEmpty()) mutableListOf() else existing.split("\n").toMutableList()
            lines.add("${fmt.format(Calendar.getInstance().time)}  [widget] $msg")
            while (lines.size > 20) lines.removeAt(0)
            prefs.edit().putString("widget_diag_log", lines.joinToString("\n")).apply()
        } catch (e: Exception) {
        }
    }

    // Mirrors WidgetService.widgetCrossedPeriodBoundary (Dart) + Swift: did an
    // ISO-week start (понеделник) OR a month start fall in (dataDay, today]? At
    // such a boundary the pushed period-aware zero is no longer valid for
    // weekly/monthly habits. LOCAL only (Calendar default time zone) — never UTC.
    private fun crossedPeriodBoundary(dataDay: String?): Boolean {
        if (dataDay.isNullOrEmpty()) return false
        return try {
            val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val parsed = fmt.parse(dataDay) ?: return false
            // ISO week: Monday is the first day of the week.
            val data = Calendar.getInstance().apply {
                time = parsed
                firstDayOfWeek = Calendar.MONDAY
                clearTime()
            }
            val today = Calendar.getInstance().apply {
                firstDayOfWeek = Calendar.MONDAY
                clearTime()
            }
            if (!data.before(today)) return false // днес/бъдеще → няма граница
            // Month (or year) boundary.
            if (data.get(Calendar.YEAR) != today.get(Calendar.YEAR) ||
                data.get(Calendar.MONTH) != today.get(Calendar.MONTH)) return true
            // ISO-week boundary: the Monday-of-week differs.
            mondayOf(data) != mondayOf(today)
        } catch (e: Exception) {
            false
        }
    }

    // The Monday that starts [c]'s ISO week, as a comparable yyyy-MM-dd string.
    private fun mondayOf(c: Calendar): String {
        val m = c.clone() as Calendar
        m.firstDayOfWeek = Calendar.MONDAY
        // Calendar.DAY_OF_WEEK: Sunday=1..Saturday=7 → distance back to Monday.
        val diff = (m.get(Calendar.DAY_OF_WEEK) + 5) % 7 // Mon→0, Tue→1 ... Sun→6
        m.add(Calendar.DAY_OF_MONTH, -diff)
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(m.time)
    }

    // Turns a localized "N / M" into "0 / M" (replaces the part before " / "
    // with "0"), preserving the localized separator/format. Mirrors the Swift
    // allZero branch + Dart spec. Falls back to the input if " / " isn't found.
    private fun allZeroCount(countZero: String): String {
        val i = countZero.indexOf(" / ")
        return if (i >= 0) "0" + countZero.substring(i) else countZero
    }

    // Zeroes the time-of-day so two Calendars compare by date only.
    private fun Calendar.clearTime() {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }

    companion object {
        // Explicit (self-addressed) broadcast action for the midnight alarm —
        // explicit broadcasts are always delivered, even on API 26+.
        private const val ACTION_MIDNIGHT = "com.ivoexp.habits.WIDGET_MIDNIGHT"
    }
}

package com.ivoexp.habits

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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
 * "today"; if it's stale we paint the period-aware zero values instead of
 * yesterday's. updatePeriodMillis (30 min) re-runs onUpdate, so the widget
 * corrects itself within ~30 min of midnight — no exact alarm (Play policy).
 */
class HabitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.habit_widget)

            val title = widgetData.getString("widget_title", "Навици") ?: "Навици"
            val dataDay = widgetData.getString("widget_data_day", null)
            val state = dayState(dataDay)
            // На граница на седмица/месец пушнатият period-aware нул е невалиден за
            // седмични/месечни навици → принудително "0 / N" за всички.
            val boundary = crossedPeriodBoundary(dataDay)

            val count: String
            val percent: Int
            val streak: String
            when (state) {
                1 -> { // точно вчера → 0 / N (period-aware), серията остава
                    val cz = widgetData.getString("widget_count_line_zero", "0 / 0") ?: "0 / 0"
                    count = if (boundary) allZeroCount(cz) else cz
                    percent = if (boundary) 0 else widgetData.getInt("widget_percent_zero", 0)
                    streak = widgetData.getString("widget_streak_line", "") ?: ""
                }
                2 -> { // 2+ дни стари → 0 / N, серията се скрива (вече ненадеждна)
                    val cz = widgetData.getString("widget_count_line_zero", "0 / 0") ?: "0 / 0"
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
}

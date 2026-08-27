package com.ivoexp.habits

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen (launcher) widget for Навици. Renders today's progress that the
 * Flutter side pushes via home_widget (WidgetService). Tapping opens the app.
 * All display strings are computed + localized in Flutter, so this only paints
 * them into the RemoteViews.
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
            val date = widgetData.getString("widget_date", "") ?: ""
            val count = widgetData.getString("widget_count_line", "0 / 0") ?: "0 / 0"
            val percent = widgetData.getInt("widget_percent", 0)
            val streak = widgetData.getString("widget_streak_line", "") ?: ""

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_date, date)
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
}

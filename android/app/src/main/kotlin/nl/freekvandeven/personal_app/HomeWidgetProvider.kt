package nl.freekvandeven.personal_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider as HomeWidgetBaseProvider

class HomeWidgetProvider : HomeWidgetBaseProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widget(s)")

        val content = widgetData.getString("tasks_content", null) ?: "No tasks due today"
        val countStr = widgetData.getString("tasks_count", "0") ?: "0"
        val count = countStr.toIntOrNull() ?: 0

        Log.d(TAG, "Widget data — count=$count, content=$content")

        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.home_widget).apply {
                    setTextViewText(R.id.widget_content, content)
                    val suffix = if (count == 1) "task due" else "tasks due"
                    setTextViewText(R.id.widget_count, "$count $suffix")

                    val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                    )
                    setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
                Log.d(TAG, "Widget $widgetId updated successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", e)
            }
        }
    }

    companion object {
        private const val TAG = "HomeWidgetProvider"
    }
}

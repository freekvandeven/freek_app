package nl.freekvandeven.personal_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider as HomeWidgetBaseProvider

class WipItemsWidgetProvider : HomeWidgetBaseProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widget(s)")

        val content = widgetData.getString("wip_content", null) ?: "No items in progress"
        val countStr = widgetData.getString("wip_count", "0") ?: "0"
        val count = countStr.toIntOrNull() ?: 0
        val colorHex = widgetData.getString("widget_color", null)

        Log.d(TAG, "Widget data — count=$count, color=$colorHex, content=$content")

        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.wip_items_widget).apply {
                    setTextViewText(R.id.wip_widget_content, content)
                    val suffix = if (count == 1) "item" else "items"
                    setTextViewText(R.id.wip_widget_count, "$count $suffix")

                    if (!colorHex.isNullOrEmpty()) {
                        val colorInt = colorHex.toLongOrNull(16)?.toInt()
                        if (colorInt != null) {
                            setInt(R.id.wip_widget_container, "setBackgroundColor", colorInt)
                        }
                    }

                    val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("homewidget://wip"),
                    )
                    setOnClickPendingIntent(R.id.wip_widget_container, pendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
                Log.d(TAG, "Widget $widgetId updated successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", e)
            }
        }
    }

    companion object {
        private const val TAG = "WipItemsWidgetProvider"
    }
}

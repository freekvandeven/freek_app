# Keep AppWidgetProvider subclasses (referenced by name in AndroidManifest.xml)
-keep public class * extends android.appwidget.AppWidgetProvider

# Keep home_widget plugin classes used from native widget code
-keep class es.antonborri.home_widget.** { *; }

package nl.freekvandeven.personal_app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "nl.freekvandeven.personal_app/widgets",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPinWidget" -> {
                    val widgetName = call.argument<String>("widget")
                        ?: "DailyTaskWidgetProvider"
                    val providerClass = when (widgetName) {
                        "WipItemsWidgetProvider" -> WipItemsWidgetProvider::class.java
                        else -> DailyTaskWidgetProvider::class.java
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val manager = getSystemService(AppWidgetManager::class.java)
                        val provider = ComponentName(this, providerClass)
                        if (manager.isRequestPinAppWidgetSupported) {
                            manager.requestPinAppWidget(provider, null, null)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

# Home Screen Widgets

The app exposes native home-screen widgets backed by the [`home_widget`](https://pub.dev/packages/home_widget) package. Widget data is written from Flutter and rendered by native code on each platform.

## Widget Registry

| ID | Display Name | Status | Description |
|----|--------------|--------|-------------|
| `DailyTaskWidgetProvider` | Daily Task Preview | Available | Shows tasks due today + overdue tasks with bullet/warning prefixes |
| `WeeklyTaskWidgetProvider` | Weekly Task Preview | Planned | Will show tasks due in the next 7 days, grouped by day |
| `WipItemsWidgetProvider` | WIP Items | Planned | Will show items currently marked as Work-in-Progress across recipes, knowledge, and shopping |

## Architecture

```
┌──────────────┐      ┌──────────────────┐      ┌─────────────────┐
│ Flutter app  │ ───▶ │ SharedPreferences │ ───▶ │ Native Provider │
│ (WidgetService)      │ (HomeWidgetPrefs) │      │ (Kotlin/Swift)  │
└──────────────┘      └──────────────────┘      └─────────────────┘
```

1. The Flutter app writes key/value data using `HomeWidget.saveWidgetData<T>(key, value)`.
2. The `home_widget` package stores the data in the `HomeWidgetPreferences` SharedPreferences file (Android) or App Group container (iOS).
3. Calling `HomeWidget.updateWidget(androidName: ..., iOSName: ...)` triggers the native provider's `onUpdate` callback.
4. The native provider reads the data and inflates a `RemoteViews` (Android) or `WidgetKit` view (iOS).

## Triggering Updates

`WidgetService` is wired up in `lib/main.dart` to listen to:

- `taskListProvider` — updates the task content whenever tasks change.
- `customSeedColorProvider` — re-syncs widget background color whenever the user changes their accent color in Settings.

## Theming

The widget background color is tied to the user's chosen accent color (`UserSettings.customSeedColor`).

- Flutter writes the color hex to `widget_color` (8-char ARGB hex, e.g. `ff2d77bb`) or empty string for default.
- The native provider parses the hex and applies it via `RemoteViews.setInt(R.id.widget_container, "setBackgroundColor", colorInt)`.
- If no custom color is set, the widget falls back to the static `@drawable/widget_background` defined in XML.

## Data Keys

Keys written by `WidgetService.updateTaskWidget`:

| Key | Type | Description |
|-----|------|-------------|
| `tasks_content` | String | Newline-separated list of due tasks (max 5), prefixed with `⚠ ` (overdue) or `• ` (due today) |
| `tasks_count` | String | Total count of due/overdue tasks (stored as String to avoid 32-bit int overflow) |
| `widget_color` | String | ARGB hex of the user's seed color (8 chars, no `#`), or empty for default |

## Adding a New Widget

### Android

1. Create a new Kotlin class in `android/app/src/main/kotlin/nl/freekvandeven/personal_app/` extending `es.antonborri.home_widget.HomeWidgetProvider`.
2. Add a layout XML in `android/app/src/main/res/layout/` (only `RemoteViews`-compatible views — no bare `<View>`).
3. Add an `appwidget-provider` XML in `android/app/src/main/res/xml/`.
4. Register the provider in `AndroidManifest.xml` with a `<receiver>` block including `android:label="..."` for the picker.
5. Add a constant for the provider class name in `WidgetService` and a method to push data for it.

### iOS

1. Add a WidgetKit extension target in Xcode (`File → New → Target → Widget Extension`).
2. Implement the SwiftUI view in the new target, reading data via `UserDefaults(suiteName: "group.nl.freekvandeven.personal_app")`.
3. Add the App Group capability to both the main app target and the widget target.
4. Add a constant for the iOS widget name in `WidgetService` and call `HomeWidget.updateWidget(iOSName: ...)`.

### Flutter glue

1. Add a new method to `WidgetService` (e.g., `updateWeeklyTaskWidget`) that writes the data and calls `HomeWidget.updateWidget`.
2. Wire up a `ref.listen` in `lib/main.dart` to invoke it when relevant data changes.

## "Add to Home Screen" Shortcut

Settings → Widgets → "Add to Home Screen" calls `WidgetService.requestPinWidget()`, which goes through a `MethodChannel` to `MainActivity`. On Android API 26+, this invokes `AppWidgetManager.requestPinAppWidget()` which prompts the user to drop the widget on their home screen. On older Android versions or unsupported launchers, the request returns `false` and the user is shown a snackbar.

iOS does not support a programmatic "add widget" prompt — users must long-press the home screen and add widgets manually.

## RemoteViews Constraints (Android)

When designing widget layouts, only specific view types are allowed:

- ✅ Allowed: `LinearLayout`, `FrameLayout`, `RelativeLayout`, `GridLayout`, `TextView`, `ImageView`, `ImageButton`, `Button`, `ProgressBar`, `Chronometer`, `AnalogClock`, `ListView`, `GridView`, `ViewFlipper`, `StackView`, `AdapterViewFlipper`
- ❌ Not allowed: bare `<View>`, `CardView`, custom views, ConstraintLayout, fragments

A bare `<View>` element will cause a silent `InflateException` in the launcher process — symptom is "Can't load widget" with no logcat output from the app.

## ProGuard

Release builds keep widget-related classes via `android/app/proguard-rules.pro`:

```
-keep public class * extends android.appwidget.AppWidgetProvider
-keep class es.antonborri.home_widget.** { *; }
```

## Debugging

- Filter logcat by tag `DailyTaskWidgetProvider` (and other provider tags as added) to see `onUpdate` calls.
- Check `adb shell dumpsys appwidget` to see currently bound widgets.
- "Can't load widget" with no logs usually means an XML inflation error — review allowed view types above.

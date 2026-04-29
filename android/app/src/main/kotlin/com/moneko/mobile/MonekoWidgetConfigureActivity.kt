package com.moneko.mobile

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * Native configuration entry-point for the Moneko home screen widget.
 *
 * This Activity is referenced from `res/xml/widget_info.xml` via the
 * `android:configure` attribute so that:
 * - When the widget is first added.
 * - Or when the user long-presses the widget and chooses "Edit" / "Settings".
 *
 * Android will launch this Activity, which in turn forwards the user into
 * the existing Flutter configuration flow by using the same deep link that
 * the widget's settings button uses: `moneko://configure_widget?widgetId=<id>`.
 *
 * The actual configuration UI and persistence live in Flutter
 * (`_WidgetConfigurationDialog` + `WidgetService.saveWidgetConfiguration`).
 */
class MonekoWidgetConfigureActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            setResult(Activity.RESULT_CANCELED)
            finish()
            return
        }

        // Forward into the Flutter app using the HomeWidget deep-link helper,
        // so that `HomeWidget.initiallyLaunchedFromHomeWidget()` on the Dart
        // side receives the same URI and can trigger the configuration dialog.
        val configureIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("moneko://configure_widget?widgetId=$appWidgetId")
        ).apply {
            setClass(this@MonekoWidgetConfigureActivity, MainActivity::class.java)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(configureIntent)

        // Report a successful configuration launch back to the widget host
        // so that the widget can be placed. The actual widget content will
        // update once the user finishes configuration in the Flutter layer.
        val resultValue = Intent().apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        setResult(Activity.RESULT_OK, resultValue)

        finish()
    }
}

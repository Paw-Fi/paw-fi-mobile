package com.moneko.mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class MonekoWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                
                // 1. Determine Configuration
                val scope = widgetData.getString("config_scope_$widgetId", null)
                val currency = widgetData.getString("config_currency_$widgetId", null)
                
                var suffix = ""
                if (scope != null && currency != null) {
                    suffix = "_${scope}_${currency}"
                }
                
                // 2. Load Data
                val totalSpent = widgetData.getString("total_spent$suffix", "$0.00")
                val remainingBudget = widgetData.getString("remaining_budget$suffix", "$0.00")
                val progress = widgetData.getFloat("budget_progress$suffix", 0.0f)
                
                // 3. Update Views
                setTextViewText(R.id.widget_total_spent, totalSpent)
                setTextViewText(R.id.widget_remaining, "Left: $remainingBudget")
                setProgressBar(R.id.widget_progress_bar, 100, (progress * 100).toInt(), false)
                
                // 4. Setup Actions
                // Text Input
                val textIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("moneko://text")
                )
                setOnClickPendingIntent(R.id.widget_btn_text, textIntent)

                // Camera Input
                val cameraIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("moneko://camera")
                )
                setOnClickPendingIntent(R.id.widget_btn_camera, cameraIntent)
                
                // Settings (Configuration)
                val settingsIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("moneko://configure_widget?widgetId=$widgetId")
                )
                setOnClickPendingIntent(R.id.widget_btn_settings, settingsIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

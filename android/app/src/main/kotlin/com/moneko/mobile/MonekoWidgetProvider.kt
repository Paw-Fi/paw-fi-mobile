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
                // Open App on Widget Click - Text
                val pendingIntentText = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("moneko://text")
                )
                setOnClickPendingIntent(R.id.widget_btn_text, pendingIntentText)

                // Open App on Widget Click - Camera
                val pendingIntentCamera = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("moneko://camera")
                )
                setOnClickPendingIntent(R.id.widget_btn_camera, pendingIntentCamera)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

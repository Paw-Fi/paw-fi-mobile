package com.moneko.mobile

import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class MonekoWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget).apply {
                val scope = widgetData.getString("config_scope_$widgetId", null)
                val selectedCurrency = widgetData.getString("selected_widget_currency", null)
                val configuredCurrency = widgetData.getString("config_currency_$widgetId", null)
                val currency = selectedCurrency?.trim()?.uppercase()
                    ?: configuredCurrency?.trim()?.uppercase()
                val isConfigured = !scope.isNullOrBlank() && !currency.isNullOrBlank()

                applyTheme(context, isConfigured)

                if (!isConfigured) {
                    setViewVisibility(R.id.widget_setup, View.VISIBLE)
                    setViewVisibility(R.id.widget_content, View.GONE)

                    val configureIntent = activityPendingIntent(
                        context,
                        Uri.parse("moneko://configure_widget?widgetId=$widgetId"),
                        widgetId * 10 + 1,
                    )
                    setOnClickPendingIntent(R.id.widget_setup, configureIntent)
                    return@apply
                }

                setViewVisibility(R.id.widget_setup, View.GONE)
                setViewVisibility(R.id.widget_content, View.VISIBLE)

                val suffix = "_${scope}_${currency}"
                val totalSpent = widgetData.getString("total_spent$suffix", "$0.00") ?: "$0.00"
                val remainingBudget =
                    widgetData.getString("remaining_budget$suffix", "$0.00") ?: "$0.00"
                val progress =
                    readFloat(widgetData, "budget_progress$suffix", 0.0f).coerceIn(0.0f, 1.0f)

                setTextViewText(R.id.widget_total_spent, totalSpent)
                setTextViewText(R.id.widget_remaining, "Left: $remainingBudget")
                setProgressBar(R.id.widget_progress_bar, 100, (progress * 100).toInt(), false)

                val textIntent = activityPendingIntent(
                    context,
                    Uri.parse("moneko://text"),
                    widgetId * 10 + 2,
                )
                setOnClickPendingIntent(R.id.widget_btn_text, textIntent)

                val cameraIntent = activityPendingIntent(
                    context,
                    Uri.parse("moneko://camera"),
                    widgetId * 10 + 3,
                )
                setOnClickPendingIntent(R.id.widget_btn_camera, cameraIntent)

                val settingsIntent = activityPendingIntent(
                    context,
                    Uri.parse("moneko://configure_widget?widgetId=$widgetId"),
                    widgetId * 10 + 4,
                )
                setOnClickPendingIntent(R.id.widget_btn_settings, settingsIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun activityPendingIntent(
        context: Context,
        uri: Uri,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            setClass(context, MainActivity::class.java)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun RemoteViews.applyTheme(context: Context, isConfigured: Boolean) {
        val isDark =
            (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        val background = if (isDark) Color.parseColor("#111827") else Color.parseColor("#FFFFFF")
        val foreground = if (isDark) Color.parseColor("#F9FAFB") else Color.parseColor("#111827")
        val muted = if (isDark) Color.parseColor("#9CA3AF") else Color.parseColor("#6B7280")
        val accentBackground = if (isDark) Color.parseColor("#7458FF") else Color.parseColor("#7458FF")
        val accentForeground = Color.parseColor("#FFFFFF")
        val secondaryBackground = if (isDark) Color.parseColor("#27272A") else Color.parseColor("#EEF2FF")
        val secondaryForeground = if (isDark) Color.parseColor("#E5E7EB") else Color.parseColor("#4338CA")

        setInt(R.id.widget_root, "setBackgroundColor", background)
        setTextColor(R.id.widget_label_month, muted)
        setTextColor(R.id.widget_total_spent, foreground)
        setTextColor(R.id.widget_remaining, muted)
        setTextColor(R.id.widget_setup_title, foreground)
        setTextColor(R.id.widget_btn_settings, muted)
        setTextColor(R.id.widget_btn_text, accentForeground)
        setInt(R.id.widget_btn_text, "setBackgroundColor", accentBackground)
        setTextColor(R.id.widget_btn_camera, secondaryForeground)
        setInt(R.id.widget_btn_camera, "setBackgroundColor", secondaryBackground)

        if (isConfigured) {
            setTextColor(R.id.widget_setup_text, muted)
        } else {
            setTextColor(R.id.widget_setup_text, muted)
        }
    }

    private fun readFloat(
        widgetData: SharedPreferences,
        key: String,
        defaultValue: Float,
    ): Float {
        val value = widgetData.all[key]
        return when (value) {
            is Float -> value
            is Double -> value.toFloat()
            is Long -> value.toFloat()
            is Int -> value.toFloat()
            is String -> value.toFloatOrNull() ?: defaultValue
            else -> defaultValue
        }
    }
}

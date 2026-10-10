package com.moneko.mobile

import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class MonekoWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        MonekoWidgetRefreshWorker.ensureScheduled(context)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget).apply {
                val scope = widgetData.getString("config_scope_$widgetId", null)
                val selectedCurrency = widgetData.getString("selected_widget_currency", null)
                val configuredCurrency = widgetData.getString("config_currency_$widgetId", null)
                val currency = selectedCurrency?.trim()?.uppercase()
                    ?: configuredCurrency?.trim()?.uppercase()
                val isConfigured = !scope.isNullOrBlank() && !currency.isNullOrBlank()

                applyTheme(context, isConfigured)

                val owner = widgetData.getString("widget_user_id", null)
                val snapshot = if (isConfigured && !owner.isNullOrBlank()) {
                    MonekoWidgetStore.readSnapshot(widgetData.getString("widget_snapshot_${scope}_${currency}", null), owner, currency)
                } else null
                // Only use legacy keys until the new owner contract is present.
                val hasLegacyData = owner == null && isConfigured &&
                    widgetData.contains("total_spent_${scope}_${currency}") &&
                    widgetData.contains("remaining_budget_${scope}_${currency}")

                if (!isConfigured || (snapshot == null && !hasLegacyData)) {
                    setViewVisibility(R.id.widget_setup, View.VISIBLE)
                    setViewVisibility(R.id.widget_content, View.GONE)
                    setTextViewText(R.id.widget_setup_text, when {
                        !isConfigured -> context.getString(R.string.widget_setup)
                        owner.isNullOrBlank() -> context.getString(R.string.widget_sign_in)
                        else -> context.getString(R.string.widget_load)
                    })

                    val configureIntent = activityPendingIntent(
                        context,
                        Uri.parse("moneko://configure_widget?widgetId=$widgetId"),
                    )
                    setOnClickPendingIntent(R.id.widget_setup, configureIntent)
                    return@apply
                }

                setViewVisibility(R.id.widget_setup, View.GONE)
                setViewVisibility(R.id.widget_content, View.VISIBLE)

                val suffix = "_${scope}_${currency}"
                val totalSpent = snapshot?.getString("totalSpent")
                    ?: widgetData.getString("total_spent$suffix", "—") ?: "—"
                val remainingBudget =
                    snapshot?.getString("remainingBudget")
                    ?: widgetData.getString("remaining_budget$suffix", "—") ?: "—"
                val progress =
                    (snapshot?.optDouble("progress", 0.0)?.toFloat()
                    ?: readFloat(widgetData, "budget_progress$suffix", 0.0f))
                        .takeIf { it.isFinite() }?.coerceIn(0.0f, 1.0f) ?: 0.0f

                setTextViewText(R.id.widget_total_spent, totalSpent)
                setTextViewText(R.id.widget_remaining, context.getString(R.string.widget_remaining, remainingBudget))
                setTextViewText(R.id.widget_label_month, context.getString(
                    if (widgetData.getString("widget_refresh_status", "ready") == "ready")
                        R.string.widget_month else R.string.widget_cached
                ))
                setProgressBar(R.id.widget_progress_bar, 100, (progress * 100).toInt(), false)

                val textIntent = activityPendingIntent(
                    context,
                    Uri.parse("moneko://text"),
                )
                setOnClickPendingIntent(R.id.widget_btn_text, textIntent)

                val cameraIntent = activityPendingIntent(
                    context,
                    Uri.parse("moneko://camera"),
                )
                setOnClickPendingIntent(R.id.widget_btn_camera, cameraIntent)

                val settingsIntent = activityPendingIntent(
                    context,
                    Uri.parse("moneko://configure_widget?widgetId=$widgetId"),
                )
                setOnClickPendingIntent(R.id.widget_btn_settings, settingsIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        super.onAppWidgetOptionsChanged(context, manager, id, options)
        onUpdate(context, manager, intArrayOf(id))
    }

    override fun onRestored(context: Context, oldIds: IntArray, newIds: IntArray) {
        val data = HomeWidgetPlugin.getData(context)
        val editor = data.edit()
        oldIds.zip(newIds).forEach { (oldId, newId) ->
            listOf("scope", "currency").forEach { field ->
                data.getString("config_${field}_$oldId", null)?.let {
                    editor.putString("config_${field}_$newId", it)
                }
                editor.remove("config_${field}_$oldId")
            }
        }
        editor.commit()
        onUpdate(context, AppWidgetManager.getInstance(context), newIds)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        val editor = HomeWidgetPlugin.getData(context).edit()
        ids.forEach { editor.remove("config_scope_$it").remove("config_currency_$it") }
        editor.apply()
        super.onDeleted(context, ids)
    }

    override fun onDisabled(context: Context) {
        MonekoWidgetRefreshWorker.cancel(context)
        super.onDisabled(context)
    }

    private fun activityPendingIntent(
        context: Context,
        uri: Uri,
    ): PendingIntent {
        // The plugin helper also sets the Android 14/15 background-launch options.
        return HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
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

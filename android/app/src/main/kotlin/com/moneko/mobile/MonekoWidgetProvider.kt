package com.moneko.mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONArray
import java.text.NumberFormat
import java.util.Locale
import java.util.ArrayList

class MonekoWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                
                // 1. Determine Configuration
                val scope = widgetData.getString("config_scope_$widgetId", null)
                val currency = widgetData.getString("config_currency_$widgetId", null)
                
                // Check if we have legacy data (no suffix) if scope is missing?
                // But user wants "initially when the widget just added... prompt user".
                // So if scope/currency is missing, show setup.
                
                val isConfigured = scope != null && currency != null
                
                if (!isConfigured) {
                    setViewVisibility(R.id.widget_content, View.GONE)
                    setViewVisibility(R.id.widget_setup, View.VISIBLE)
                    
                    // Setup Theme for Setup View
                    val nightModeFlags = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                    val isDark = nightModeFlags == Configuration.UI_MODE_NIGHT_YES
                    
                    val bgColor = if (isDark) Color.parseColor("#0A0E1A") else Color.parseColor("#F9FAFB")
                    val mutedColor = if (isDark) Color.parseColor("#9CA3AF") else Color.parseColor("#6B7280")
                    
                    // We try to set background color. Note: This removes rounded corners from the drawable if any.
                    // Ideally we would use a tinted drawable, but for now this ensures readability.
                    setInt(R.id.widget_root, "setBackgroundColor", bgColor)
                    
                    setInt(R.id.widget_setup_icon, "setColorFilter", mutedColor)
                    setTextColor(R.id.widget_setup_text, mutedColor)
                    
                    // Settings Intent (to configure)
                    val settingsIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("moneko://configure_widget?widgetId=$widgetId")
                    )
                    // Allow users to tap the setup view to open the same
                    // configuration flow used by the settings button once
                    // the widget is configured. This mirrors the iOS flow,
                    // where the initial widget placement immediately surfaces
                    // configuration, instead of leaving the setup state inert.
                    setOnClickPendingIntent(R.id.widget_setup, settingsIntent)
                    
                } else {
                    setViewVisibility(R.id.widget_content, View.VISIBLE)
                    setViewVisibility(R.id.widget_setup, View.GONE)
                    
                    var suffix = "_${scope}_${currency}"
                    
                    // 2. Load Data
                    val totalSpent = widgetData.getString("total_spent$suffix", "$0.00")
                    val remainingBudget = widgetData.getString("remaining_budget$suffix", "$0.00")
                    val progress = widgetData.getFloat("budget_progress$suffix", 0.0f)
                    
                    // 3. Theme Support
                    val nightModeFlags = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                    val isDark = nightModeFlags == Configuration.UI_MODE_NIGHT_YES
                    
                    val bgColor = if (isDark) Color.parseColor("#0A0E1A") else Color.parseColor("#F9FAFB")
                    val fgColor = if (isDark) Color.parseColor("#F1F5F9") else Color.parseColor("#1F2937")
                    val mutedColor = if (isDark) Color.parseColor("#9CA3AF") else Color.parseColor("#6B7280")
                    
                    setInt(R.id.widget_root, "setBackgroundColor", bgColor)
                    
                    setTextColor(R.id.widget_label_month, mutedColor)
                    setTextColor(R.id.widget_total_spent, fgColor)
                    setTextColor(R.id.widget_remaining, mutedColor)
                    
                    setInt(R.id.widget_btn_settings, "setColorFilter", mutedColor)
                    
                    // Update Header
                    setTextViewText(R.id.widget_total_spent, totalSpent)
                    setTextViewText(R.id.widget_remaining, "Left: $remainingBudget")
                    
                    // 4. Parse Pockets Data for Top Spending Logic
                    val pocketsJson = widgetData.getString("pockets_data$suffix", "[]")
                    try {
                        val jsonArray = JSONArray(pocketsJson)
                        val pockets = ArrayList<Triple<String, Double, String>>() // Name, Spent, Color
                        
                        var maxSpent = 1.0 // avoiding div by zero

                        for (i in 0 until jsonArray.length()) {
                            val item = jsonArray.getJSONObject(i)
                            val name = item.optString("name", "Pocket")
                            val spent = item.optDouble("spent", 0.0)
                            val color = item.optString("color", "#7458FF")
                            
                            pockets.add(Triple(name, spent, color))
                            if (spent > maxSpent) maxSpent = spent
                        }
                        
                        // Sort by spent descending
                        pockets.sortByDescending { it.second }
                        
                        // Populate Top 3
                        val items = listOf(
                            Triple(R.id.widget_item_1, R.id.widget_item_1_name, R.id.widget_item_1_amount),
                            Triple(R.id.widget_item_2, R.id.widget_item_2_name, R.id.widget_item_2_amount),
                            Triple(R.id.widget_item_3, R.id.widget_item_3_name, R.id.widget_item_3_amount)
                        )
                        
                        // Helper to set item
                        for (i in 0 until 3) {
                            val viewsIds = items[i]
                            val containerId = viewsIds.first
                            
                            if (i < pockets.size) {
                                val pocket = pockets[i]
                                val spentVal = pocket.second
                                val colorHex = pocket.third
                                
                                setViewVisibility(containerId, View.VISIBLE)
                                setTextViewText(viewsIds.second, pocket.first)
                                
                                // Format currency (simplified)
                                setTextViewText(viewsIds.third, NumberFormat.getCurrencyInstance(Locale.US).format(spentVal)) // Defaults to US, ideally check currency code
                                
                                // Colors
                                setTextColor(viewsIds.second, fgColor)
                                
                                // Progress Bar
                                // We need IDs for progress bars: widget_item_1_progress, etc.
                                // I'll assume standard naming or use `views.setProgressBar` with resource search if needed, but resource IDs are ints.
                                // Let's correct the list above to include progress bar ID and icon ID.
                            } else {
                                setViewVisibility(containerId, View.GONE)
                            }
                        }
                        

                        // Detailed binding with correct IDs
                        // Item 1
                        if (pockets.size > 0) {
                            val p = pockets[0]
                            setTextViewText(R.id.widget_item_1_name, p.first)
                            setTextViewText(R.id.widget_item_1_amount, formatMoney(p.second))
                            setProgressBar(R.id.widget_item_1_progress, 100, ((p.second / maxSpent) * 100).toInt(), false)
                        }
                        
                        // Item 2
                        if (pockets.size > 1) {
                            val p = pockets[1]
                            setTextViewText(R.id.widget_item_2_name, p.first)
                            setTextViewText(R.id.widget_item_2_amount, formatMoney(p.second))
                            setProgressBar(R.id.widget_item_2_progress, 100, ((p.second / maxSpent) * 100).toInt(), false)
                        }
                        
                        // Item 3
                        if (pockets.size > 2) {
                            val p = pockets[2]
                            setTextViewText(R.id.widget_item_3_name, p.first)
                            setTextViewText(R.id.widget_item_3_amount, formatMoney(p.second))
                            setProgressBar(R.id.widget_item_3_progress, 100, ((p.second / maxSpent) * 100).toInt(), false)
                        }
                        
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }

                    
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
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
    
    private fun formatMoney(amount: Double): String {
       val format = NumberFormat.getCurrencyInstance(Locale.US)
       format.maximumFractionDigits = 0
       return format.format(amount)
    }

}

package com.moneko.mobile

import android.content.SharedPreferences
import org.json.JSONObject

/** Serializes foreground publication and the worker's compare-and-set boundary. */
internal object MonekoWidgetStore {
    private val lock = Any()

    fun synchronizeOwner(data: SharedPreferences, userId: String) = synchronized(lock) {
        if (data.getString("widget_user_id", null) == userId) return@synchronized
        check(data.edit().putString("widget_user_id", userId)
            .remove("selected_widget_currency").remove("widget_refresh_context")
            .putString("widget_refresh_status", "loading").commit())
    }

    fun configureRefresh(data: SharedPreferences, userId: String, settings: String) = synchronized(lock) {
        if (data.getString("widget_user_id", null) != userId) return@synchronized
        check(data.edit().putString("widget_refresh_context", settings).commit())
    }

    fun publishForeground(data: SharedPreferences, userId: String, key: String, snapshot: String, currency: String): Boolean = synchronized(lock) {
        if (data.getString("widget_user_id", null) != userId) return@synchronized false
        data.edit().putString(key, snapshot).putString("selected_widget_currency", currency)
            .putString("widget_refresh_status", "ready").commit()
    }

    fun publishBackground(data: SharedPreferences, userId: String, settings: String, key: String,
        previous: String?, snapshot: String, canPublish: () -> Boolean): Boolean = synchronized(lock) {
        if (data.getString("widget_user_id", null) != userId ||
            data.getString("widget_refresh_context", null) != settings ||
            data.getString(key, null) != previous || !canPublish()) return@synchronized false
        data.edit().putString(key, snapshot).putString("widget_refresh_status", "ready").commit()
    }

    fun readSnapshot(raw: String?, owner: String?, currency: String?): JSONObject? {
        if (owner.isNullOrBlank() || currency.isNullOrBlank() || raw == null) return null
        return runCatching {
            JSONObject(raw).takeIf {
                it.optInt("version") == 1 && it.optString("userId") == owner &&
                    it.optString("currency") == currency &&
                    it.get("totalSpent") is String && it.get("remainingBudget") is String &&
                    it.getDouble("progress").isFinite()
            }
        }.getOrNull()
    }
}

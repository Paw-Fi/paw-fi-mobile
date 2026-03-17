package com.moneko.mobile

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject

data class RecentNotificationApp(
    val packageName: String,
    val appLabel: String,
    val lastSeenAt: Long,
    val enabled: Boolean
)

class NotificationCaptureConfig(context: Context) {

    companion object {
        private const val PREFS_NAME = "moneko_notification_capture"
        private const val AUTH_PREFS_NAME = "moneko_notification_capture_auth"
        private const val KEY_ENABLED = "notification_capture_enabled"
        private const val KEY_SCOPE_ID = "notification_default_scope_id"
        private const val KEY_SCOPE_NAME = "notification_default_scope_name"
        private const val KEY_IS_PORTFOLIO = "notification_default_is_portfolio"
        private const val KEY_RECENT_APPS = "recent_notification_packages"
        private const val KEY_ENABLED_PACKAGES = "enabled_notification_packages"
        private const val KEY_SUPABASE_URL = "supabase_url"
        private const val KEY_SUPABASE_ANON_KEY = "supabase_anon_key"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_EXPIRES_AT = "expires_at"
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val authPrefs: SharedPreferences? = createEncryptedPreferences(context)

    val isAuthStorageAvailable: Boolean
        get() = authPrefs != null

    var isEnabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, false)
        set(value) = prefs.edit().putBoolean(KEY_ENABLED, value).apply()

    var scopeId: String
        get() = prefs.getString(KEY_SCOPE_ID, "personal") ?: "personal"
        set(value) = prefs.edit().putString(KEY_SCOPE_ID, value).apply()

    var scopeName: String
        get() = prefs.getString(KEY_SCOPE_NAME, "Personal") ?: "Personal"
        set(value) = prefs.edit().putString(KEY_SCOPE_NAME, value).apply()

    var isPortfolio: Boolean
        get() = prefs.getBoolean(KEY_IS_PORTFOLIO, false)
        set(value) = prefs.edit().putBoolean(KEY_IS_PORTFOLIO, value).apply()

    val supabaseUrl: String
        get() = authPrefs?.getString(KEY_SUPABASE_URL, "") ?: ""

    val supabaseAnonKey: String
        get() = authPrefs?.getString(KEY_SUPABASE_ANON_KEY, "") ?: ""

    val accessToken: String
        get() = authPrefs?.getString(KEY_ACCESS_TOKEN, "") ?: ""

    val refreshToken: String
        get() = authPrefs?.getString(KEY_REFRESH_TOKEN, "") ?: ""

    val userId: String
        get() = authPrefs?.getString(KEY_USER_ID, "") ?: ""

    val expiresAt: Long
        get() = authPrefs?.getLong(KEY_EXPIRES_AT, 0L) ?: 0L

    val isAccessTokenExpired: Boolean
        get() {
            val exp = expiresAt
            if (exp <= 0L) return false
            val now = System.currentTimeMillis() / 1000
            return now >= (exp - 30)
        }

    fun getEnabledPackages(): Set<String> {
        val json = prefs.getString(KEY_ENABLED_PACKAGES, "[]") ?: "[]"
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).map { arr.getString(it) }.toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    fun setEnabledPackages(packages: Set<String>) {
        val arr = JSONArray()
        packages.forEach { arr.put(it) }
        prefs.edit().putString(KEY_ENABLED_PACKAGES, arr.toString()).apply()
    }

    fun setPackageEnabled(packageName: String, enabled: Boolean) {
        val current = getEnabledPackages().toMutableSet()
        if (enabled) {
            current.add(packageName)
        } else {
            current.remove(packageName)
        }
        setEnabledPackages(current)
    }

    fun isPackageEnabled(packageName: String): Boolean {
        return getEnabledPackages().contains(packageName)
    }

    fun getRecentApps(): List<RecentNotificationApp> {
        val json = prefs.getString(KEY_RECENT_APPS, "[]") ?: "[]"
        return try {
            val arr = JSONArray(json)
            val enabledSet = getEnabledPackages()
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                RecentNotificationApp(
                    packageName = obj.getString("packageName"),
                    appLabel = obj.optString("appLabel", obj.getString("packageName")),
                    lastSeenAt = obj.optLong("lastSeenAt", 0L),
                    enabled = enabledSet.contains(obj.getString("packageName"))
                )
            }.sortedByDescending { it.lastSeenAt }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun recordRecentApp(packageName: String, appLabel: String) {
        val apps = getRecentApps().toMutableList()
        val now = System.currentTimeMillis()
        val existingIndex = apps.indexOfFirst { it.packageName == packageName }
        if (existingIndex >= 0) {
            val existing = apps[existingIndex]
            apps[existingIndex] = existing.copy(
                appLabel = appLabel,
                lastSeenAt = now
            )
        } else {
            apps.add(
                RecentNotificationApp(
                    packageName = packageName,
                    appLabel = appLabel,
                    lastSeenAt = now,
                    enabled = false
                )
            )
        }

        val arr = JSONArray()
        apps.sortedByDescending { it.lastSeenAt }.take(50).forEach { app ->
            val obj = JSONObject()
            obj.put("packageName", app.packageName)
            obj.put("appLabel", app.appLabel)
            obj.put("lastSeenAt", app.lastSeenAt)
            arr.put(obj)
        }
        prefs.edit().putString(KEY_RECENT_APPS, arr.toString()).apply()
    }

    fun toConfigMap(): Map<String, Any> {
        return mapOf(
            "enabled" to isEnabled,
            "scopeId" to scopeId,
            "scopeName" to scopeName,
            "isPortfolio" to isPortfolio,
            "hasAuthStorage" to isAuthStorageAvailable,
            "hasNotificationAccess" to false,
            "enabledPackages" to getEnabledPackages().toList(),
            "recentApps" to getRecentApps().map { app ->
                mapOf(
                    "packageName" to app.packageName,
                    "appLabel" to app.appLabel,
                    "lastSeenAt" to app.lastSeenAt,
                    "enabled" to app.enabled
                )
            }
        )
    }

    fun syncAuthContext(
        supabaseUrl: String,
        supabaseAnonKey: String,
        accessToken: String,
        refreshToken: String,
        userId: String,
        expiresAt: Long
    ) {
        val prefs = requireAuthPrefs()
        prefs.edit().apply {
            putString(KEY_SUPABASE_URL, supabaseUrl)
            putString(KEY_SUPABASE_ANON_KEY, supabaseAnonKey)
            putString(KEY_ACCESS_TOKEN, accessToken)
            putString(KEY_REFRESH_TOKEN, refreshToken)
            putString(KEY_USER_ID, userId)
            putLong(KEY_EXPIRES_AT, expiresAt)
            apply()
        }
    }

    fun updateRefreshedSession(
        accessToken: String,
        refreshToken: String?,
        expiresAt: Long
    ): Boolean {
        val prefs = authPrefs ?: return false
        prefs.edit().apply {
            putString(KEY_ACCESS_TOKEN, accessToken)
            if (!refreshToken.isNullOrBlank()) {
                putString(KEY_REFRESH_TOKEN, refreshToken)
            }
            putLong(KEY_EXPIRES_AT, expiresAt)
            apply()
        }
        return true
    }

    fun clearSessionTokens() {
        authPrefs?.edit()?.apply {
            remove(KEY_ACCESS_TOKEN)
            remove(KEY_REFRESH_TOKEN)
            remove(KEY_EXPIRES_AT)
            apply()
        }
    }

    fun clearAuthContext(): Boolean {
        val prefs = authPrefs ?: return false
        prefs.edit().apply {
            remove(KEY_SUPABASE_URL)
            remove(KEY_SUPABASE_ANON_KEY)
            remove(KEY_ACCESS_TOKEN)
            remove(KEY_REFRESH_TOKEN)
            remove(KEY_USER_ID)
            remove(KEY_EXPIRES_AT)
            apply()
        }
        return true
    }

    private fun requireAuthPrefs(): SharedPreferences {
        return authPrefs ?: throw IllegalStateException("AUTH_STORAGE_UNAVAILABLE")
    }

    private fun createEncryptedPreferences(context: Context): SharedPreferences? {
        return try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            EncryptedSharedPreferences.create(
                context,
                AUTH_PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (_: Exception) {
            null
        }
    }
}

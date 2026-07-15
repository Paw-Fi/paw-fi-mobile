package com.moneko.mobile

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import java.util.UUID

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
        private const val KEY_ACCOUNT_ID = "notification_default_account_id"
        private const val KEY_ACCOUNT_NAME = "notification_default_account_name"
        private const val KEY_ACCOUNT_CURRENCY = "notification_default_account_currency"
        private const val KEY_RECENT_APPS = "recent_notification_packages"
        private const val KEY_ENABLED_PACKAGES = "enabled_notification_packages"
        private const val KEY_SUPABASE_URL = "supabase_url"
        private const val KEY_SUPABASE_ANON_KEY = "supabase_anon_key"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_EXPIRES_AT = "expires_at"
        private const val KEY_AUTH_CONTEXT_VERSION = "auth_context_version"
        private const val KEY_PENDING_CAPTURES = "pending_captures"
        private const val CLEANUP_WORK_PREFIX = "notification_capture_cleanup_"
        private const val MAX_PENDING_CAPTURES = 100
        internal const val PENDING_CAPTURE_TTL_MS = 24 * 60 * 60 * 1_000L

        internal fun isPendingCaptureExpired(queuedAt: Long, now: Long): Boolean =
            queuedAt <= 0 || now - queuedAt >= PENDING_CAPTURE_TTL_MS
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val authPrefs: SharedPreferences? = createEncryptedPreferences(context)
    private val appContext = context.applicationContext

    init {
        scheduleExistingPendingCaptureCleanup()
    }

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

    var accountId: String
        get() = prefs.getString(KEY_ACCOUNT_ID, "") ?: ""
        set(value) = prefs.edit().putString(KEY_ACCOUNT_ID, value).apply()

    var accountName: String
        get() = prefs.getString(KEY_ACCOUNT_NAME, "") ?: ""
        set(value) = prefs.edit().putString(KEY_ACCOUNT_NAME, value).apply()

    var accountCurrency: String
        get() = prefs.getString(KEY_ACCOUNT_CURRENCY, "") ?: ""
        set(value) = prefs.edit().putString(KEY_ACCOUNT_CURRENCY, value.trim().uppercase()).apply()

    val supabaseUrl: String
        get() = authPrefs?.getString(KEY_SUPABASE_URL, "") ?: ""

    val supabaseAnonKey: String
        get() = authPrefs?.getString(KEY_SUPABASE_ANON_KEY, "") ?: ""

    val accessToken: String
        get() = authPrefs?.getString(KEY_ACCESS_TOKEN, "") ?: ""

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

    val hasCredentials: Boolean
        get() = supabaseUrl.isNotBlank() &&
            supabaseAnonKey.isNotBlank() &&
            accessToken.isNotBlank() &&
            userId.isNotBlank() &&
            authPrefs?.getInt(KEY_AUTH_CONTEXT_VERSION, 0) == 2

    val isReady: Boolean
        get() = isAuthStorageAvailable && hasCredentials

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
            "accountId" to accountId,
            "accountName" to accountName,
            "accountCurrency" to accountCurrency,
            "hasAuthStorage" to isAuthStorageAvailable,
            "hasCredentials" to hasCredentials,
            "isReady" to isReady,
            "expiresAt" to expiresAt,
            "isAccessTokenExpired" to isAccessTokenExpired,
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
        userId: String,
        expiresAt: Long
    ) {
        val prefs = requireAuthPrefs()
        val previousUserId = prefs.getString(KEY_USER_ID, "") ?: ""
        prefs.edit().apply {
            putString(KEY_SUPABASE_URL, supabaseUrl)
            putString(KEY_SUPABASE_ANON_KEY, supabaseAnonKey)
            putString(KEY_ACCESS_TOKEN, accessToken)
            remove(KEY_REFRESH_TOKEN)
            putString(KEY_USER_ID, userId)
            putLong(KEY_EXPIRES_AT, expiresAt)
            putInt(KEY_AUTH_CONTEXT_VERSION, 2)
            if (previousUserId.isNotBlank() && previousUserId != userId) {
                remove(KEY_PENDING_CAPTURES)
            }
            apply()
        }
    }

    fun clearLegacyNativeSession() {
        authPrefs?.edit()?.apply {
            remove(KEY_ACCESS_TOKEN)
            remove(KEY_REFRESH_TOKEN)
            remove(KEY_EXPIRES_AT)
            remove(KEY_AUTH_CONTEXT_VERSION)
            apply()
        }
    }

    @Synchronized
    fun enqueuePendingCapture(body: JSONObject, idempotencyKey: String): Boolean {
        val prefs = authPrefs ?: return false
        val records = readPendingCaptures()
        if ((0 until records.length()).any {
                records.optJSONObject(it)?.optString("idempotencyKey") == idempotencyKey
            }) {
            return true
        }
        if (records.length() >= MAX_PENDING_CAPTURES) return false

        val recordId = UUID.randomUUID().toString()
        val queuedAt = System.currentTimeMillis()
        records.put(JSONObject().apply {
            put("id", recordId)
            put("idempotencyKey", idempotencyKey)
            put("userId", userId)
            put("queuedAt", queuedAt)
            put("body", body)
        })
        val persisted = prefs.edit().putString(KEY_PENDING_CAPTURES, records.toString()).commit()
        if (!persisted) return false
        if (!schedulePendingCaptureCleanup(recordId, queuedAt)) {
            removePendingCaptures(setOf(recordId))
            return false
        }
        return true
    }

    @Synchronized
    fun getPendingCaptures(): List<Map<String, Any?>> {
        val records = readPendingCaptures()
        return (0 until records.length()).mapNotNull { index ->
            val record = records.optJSONObject(index) ?: return@mapNotNull null
            val body = record.optJSONObject("body") ?: return@mapNotNull null
            mapOf(
                "id" to record.optString("id"),
                "idempotencyKey" to record.optString("idempotencyKey"),
                "userId" to record.optString("userId"),
                "queuedAt" to record.optLong("queuedAt"),
                "body" to body.toString()
            )
        }
    }

    @Synchronized
    fun removePendingCaptures(ids: Set<String>) {
        if (ids.isEmpty()) return
        val prefs = authPrefs ?: return
        val records = readPendingCaptures()
        val remaining = JSONArray()
        for (index in 0 until records.length()) {
            val record = records.optJSONObject(index) ?: continue
            if (!ids.contains(record.optString("id"))) remaining.put(record)
        }
        prefs.edit().putString(KEY_PENDING_CAPTURES, remaining.toString()).commit()
    }

    @Synchronized
    fun removePendingCaptureByIdempotencyKey(idempotencyKey: String) {
        if (idempotencyKey.isBlank()) return
        val prefs = authPrefs ?: return
        val records = readPendingCaptures()
        val remaining = JSONArray()
        for (index in 0 until records.length()) {
            val record = records.optJSONObject(index) ?: continue
            if (record.optString("idempotencyKey") != idempotencyKey) remaining.put(record)
        }
        prefs.edit().putString(KEY_PENDING_CAPTURES, remaining.toString()).commit()
    }

    private fun readPendingCaptures(): JSONArray {
        val json = authPrefs?.getString(KEY_PENDING_CAPTURES, "[]") ?: "[]"
        val records = try {
            JSONArray(json)
        } catch (_: Exception) {
            JSONArray()
        }
        val now = System.currentTimeMillis()
        val retained = JSONArray()
        for (index in 0 until records.length()) {
            val record = records.optJSONObject(index) ?: continue
            if (!isPendingCaptureExpired(record.optLong("queuedAt"), now)) {
                retained.put(record)
            }
        }
        if (retained.length() != records.length()) {
            authPrefs?.edit()?.putString(KEY_PENDING_CAPTURES, retained.toString())?.commit()
        }
        return retained
    }

    internal fun pruneExpiredPendingCaptures() {
        readPendingCaptures()
    }

    private fun scheduleExistingPendingCaptureCleanup() {
        val records = readPendingCaptures()
        for (index in 0 until records.length()) {
            val record = records.optJSONObject(index) ?: continue
            val recordId = record.optString("id")
            val queuedAt = record.optLong("queuedAt")
            if (recordId.isNotBlank() && queuedAt > 0) {
                schedulePendingCaptureCleanup(recordId, queuedAt)
            }
        }
    }

    private fun schedulePendingCaptureCleanup(recordId: String, queuedAt: Long): Boolean {
        return try {
            val delayMs = (queuedAt + PENDING_CAPTURE_TTL_MS - System.currentTimeMillis())
                .coerceAtLeast(0L)
            val work = OneTimeWorkRequestBuilder<NotificationCaptureCleanupWorker>()
                .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
                .build()
            WorkManager.getInstance(appContext).enqueueUniqueWork(
                "$CLEANUP_WORK_PREFIX$recordId",
                ExistingWorkPolicy.KEEP,
                work,
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    fun clearSessionTokens() {
        authPrefs?.edit()?.apply {
            remove(KEY_ACCESS_TOKEN)
            remove(KEY_REFRESH_TOKEN)
            remove(KEY_EXPIRES_AT)
            remove(KEY_AUTH_CONTEXT_VERSION)
            remove(KEY_PENDING_CAPTURES)
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
            remove(KEY_AUTH_CONTEXT_VERSION)
            remove(KEY_PENDING_CAPTURES)
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

package com.moneko.mobile

import android.app.Notification
import android.content.pm.PackageManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Listens for incoming notifications and auto-captures transaction data
 * from user-enabled banking/finance apps.
 *
 * Flow:
 * 1. Record every notification source in the recent-apps registry.
 * 2. For enabled packages, extract notification text and parse.
 * 3. If parse succeeds with sufficient confidence, call save-wallet-transaction.
 * 4. Local dedup prevents re-sending identical notification content.
 */
class TransactionNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "MonekoCaptureService"
        private const val DEDUP_WINDOW_MS = 60_000L  // 60-second local dedup window
        private const val MAX_DEDUP_ENTRIES = 200
    }

    /** Background executor for HTTP calls — avoids blocking the main thread. */
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    /**
     * Local dedup cache: SHA-256(packageName + title + text + amount) → timestamp.
     * Prevents sending the same notification twice within [DEDUP_WINDOW_MS].
     */
    private val recentHashes = ConcurrentHashMap<String, Long>()

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        // Ignore our own notifications
        if (packageName == applicationContext.packageName) return

        val config = NotificationCaptureConfig(applicationContext)

        // Always record the source app in recent-apps registry
        val appLabel = resolveAppLabel(packageName)
        config.recordRecentApp(packageName, appLabel)

        // Gate: global capture must be enabled
        if (!config.isEnabled) return

        // Gate: this specific package must be enabled by the user
        if (!config.isPackageEnabled(packageName)) return

        // Extract notification text
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()

        // Must have at least some text to parse
        if (title.isNullOrBlank() && text.isNullOrBlank() && bigText.isNullOrBlank()) return

        // Parse
        val parsed = NotificationTransactionParser.parse(title, text, bigText) ?: return

        // Local dedup
        val dedupKey = makeDedupKey(packageName, title, text, parsed.amount)
        if (isDuplicate(dedupKey)) {
            Log.d(TAG, "Duplicate notification blocked locally: $packageName")
            return
        }

        // Mark as seen
        recentHashes[dedupKey] = System.currentTimeMillis()
        pruneOldHashes()

        // Send to backend on background thread
        executor.submit {
            try {
                sendToBackend(config, parsed, packageName, dedupKey)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send transaction to backend: ${e.message}")
                // Remove dedup entry on failure so retry is possible
                recentHashes.remove(dedupKey)
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No action needed on removal
    }

    override fun onDestroy() {
        super.onDestroy()
        executor.shutdownNow()
    }

    // ── HTTP transport ───────────────────────────────────────────────────

    private fun sendToBackend(
        config: NotificationCaptureConfig,
        parsed: ParsedTransaction,
        packageName: String,
        dedupKey: String
    ) {
        val supabaseUrl = config.supabaseUrl
        val accessToken = getValidAccessToken(config) ?: run {
            Log.w(TAG, "No valid access token available — skipping capture")
            return
        }

        val scopeId = config.scopeId
        val isPortfolio = config.isPortfolio

        // Build request body
        val body = JSONObject().apply {
            put("captureSource", "android_notification_listener")
            put("idempotencyKey", buildRequestIdempotencyKey(dedupKey, scopeId, isPortfolio))
            put("clientCreatedAt", java.time.Instant.now().toString())
            put("transaction", JSONObject().apply {
                put("merchantName", parsed.merchantName ?: "")
                put("amount", parsed.amount)
                put("currency", parsed.currencyCode)
                put("date", parsed.transactionDate)
                put("packageName", packageName)
                put("note", parsed.rawText)
            })
            if (scopeId != "personal") {
                put("householdId", scopeId)
                put("isPortfolio", isPortfolio)
            }
        }

        val url = URL("$supabaseUrl/functions/v1/save-wallet-transaction")
        val conn = url.openConnection() as HttpURLConnection

        try {
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $accessToken")
            conn.setRequestProperty("apikey", config.supabaseAnonKey)
            conn.doOutput = true
            conn.connectTimeout = 15_000
            conn.readTimeout = 15_000

            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(body.toString())
            }

            val responseCode = conn.responseCode
            val responseBody = try {
                BufferedReader(InputStreamReader(
                    if (responseCode in 200..299) conn.inputStream else conn.errorStream,
                    Charsets.UTF_8
                )).use { it.readText() }
            } catch (_: Exception) { "" }

            when (responseCode) {
                200, 201 -> {
                    Log.d(TAG, "Transaction captured successfully from $packageName")
                }
                409 -> {
                    Log.d(TAG, "Duplicate transaction detected server-side for $packageName")
                }
                401 -> {
                    Log.w(TAG, "Auth rejected — clearing tokens")
                    config.accessToken = ""
                    config.refreshToken = ""
                    config.expiresAt = 0L
                }
                else -> {
                    Log.w(TAG, "Backend error $responseCode: $responseBody")
                }
            }
        } finally {
            conn.disconnect()
        }
    }

    // ── Auth helpers ─────────────────────────────────────────────────────

    /**
     * Returns a valid access token, refreshing if expired.
     */
    private fun getValidAccessToken(config: NotificationCaptureConfig): String? {
        val token = config.accessToken
        if (token.isBlank()) return null

        if (!config.isAccessTokenExpired) return token

        // Attempt refresh
        return refreshAccessToken(config)
    }

    /**
     * Refreshes the Supabase access token using the stored refresh token.
     */
    private fun refreshAccessToken(config: NotificationCaptureConfig): String? {
        val refreshToken = config.refreshToken
        if (refreshToken.isBlank()) return null

        val supabaseUrl = config.supabaseUrl
        val anonKey = config.supabaseAnonKey
        if (supabaseUrl.isBlank() || anonKey.isBlank()) return null

        val url = URL("$supabaseUrl/auth/v1/token?grant_type=refresh_token")
        val conn = url.openConnection() as HttpURLConnection

        try {
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("apikey", anonKey)
            conn.doOutput = true
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000

            val body = JSONObject().apply {
                put("refresh_token", refreshToken)
            }

            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(body.toString())
            }

            if (conn.responseCode == 200) {
                val responseBody = BufferedReader(
                    InputStreamReader(conn.inputStream, Charsets.UTF_8)
                ).use { it.readText() }

                val json = JSONObject(responseBody)
                val newAccess = json.optString("access_token", "")
                val newRefresh = json.optString("refresh_token", "")
                val expiresIn = json.optLong("expires_in", 3600)

                if (newAccess.isNotBlank()) {
                    config.accessToken = newAccess
                    if (newRefresh.isNotBlank()) {
                        config.refreshToken = newRefresh
                    }
                    config.expiresAt = (System.currentTimeMillis() / 1000) + expiresIn
                    Log.d(TAG, "Token refreshed successfully")
                    return newAccess
                }
            } else {
                Log.w(TAG, "Token refresh failed: ${conn.responseCode}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Token refresh error: ${e.message}")
        } finally {
            conn.disconnect()
        }

        return null
    }

    // ── Dedup helpers ────────────────────────────────────────────────────

    private fun makeDedupKey(
        packageName: String,
        title: String?,
        text: String?,
        amount: Double
    ): String {
        val raw = "$packageName|${title.orEmpty()}|${text.orEmpty()}|$amount"
        val digest = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun buildRequestIdempotencyKey(
        dedupKey: String,
        scopeId: String,
        isPortfolio: Boolean
    ): String {
        val scopeKey = if (scopeId == "personal") "personal" else "$scopeId|$isPortfolio"
        return "android_notification_listener|$scopeKey|$dedupKey"
    }

    private fun isDuplicate(key: String): Boolean {
        val lastSeen = recentHashes[key] ?: return false
        return (System.currentTimeMillis() - lastSeen) < DEDUP_WINDOW_MS
    }

    private fun pruneOldHashes() {
        if (recentHashes.size <= MAX_DEDUP_ENTRIES) return
        val cutoff = System.currentTimeMillis() - DEDUP_WINDOW_MS
        recentHashes.entries.removeAll { it.value < cutoff }
    }

    // ── Utility ──────────────────────────────────────────────────────────

    private fun resolveAppLabel(packageName: String): String {
        return try {
            val pm = applicationContext.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName.substringAfterLast('.')
                .replaceFirstChar { it.titlecase() }
        }
    }
}

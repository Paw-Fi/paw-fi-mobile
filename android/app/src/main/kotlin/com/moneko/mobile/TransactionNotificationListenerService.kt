package com.moneko.mobile

import android.app.Notification
import android.content.pm.PackageManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.google.firebase.crashlytics.FirebaseCrashlytics
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

    private data class BackendCaptureResponse(
        val statusCode: Int,
        val responseBody: String
    )

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
        val dedupKey = makeDedupKey(
            packageName = packageName,
            notificationKey = sbn.key,
            title = title,
            text = text,
            bigText = bigText,
            amount = parsed.amount,
            transactionType = parsed.transactionType
        )
        if (isDuplicate(dedupKey)) {
            Log.d(TAG, "Duplicate notification blocked locally: $packageName")
            return
        }

        // Mark as seen
        recentHashes[dedupKey] = System.currentTimeMillis()
        pruneOldHashes()

        recordCaptureTelemetry(
            action = "capture_attempted",
            details = mapOf(
                "transactionType" to parsed.transactionType,
                "accessTokenExpired" to config.isAccessTokenExpired,
                "expiresAt" to config.expiresAt,
                "enabledPackagesCount" to config.getEnabledPackages().size
            )
        )

        // Send to backend on background thread
        executor.submit {
            try {
                sendToBackend(
                    config,
                    parsed,
                    packageName,
                    appLabel,
                    sbn.key,
                    sbn.postTime,
                    dedupKey
                )
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
        appLabel: String,
        notificationKey: String?,
        notificationPostTimeMillis: Long,
        dedupKey: String
    ) {
        if (!config.isAuthStorageAvailable) {
            Log.w(TAG, "Secure auth storage unavailable - skipping capture")
            recordCaptureTelemetry("auth_storage_unavailable")
            return
        }

        val supabaseUrl = config.supabaseUrl
        val anonKey = config.supabaseAnonKey
        if (supabaseUrl.isBlank() || anonKey.isBlank()) {
            Log.w(TAG, "Supabase config missing - skipping capture")
            recordCaptureTelemetry("supabase_config_missing")
            return
        }

        val scopeId = config.scopeId
        val isPortfolio = config.isPortfolio
        val accountId = config.accountId
        val accountCurrency = config.accountCurrency

        // Build request body
        val body = JSONObject().apply {
            put("captureSource", "android_notification_listener")
            put(
                "idempotencyKey",
                buildRequestIdempotencyKey(
                    dedupKey,
                    scopeId,
                    isPortfolio,
                    parsed.transactionType,
                )
            )
            put("clientCreatedAt", java.time.Instant.now().toString())
            put("transaction", JSONObject().apply {
                if (!parsed.merchantName.isNullOrBlank()) {
                    put("merchantName", parsed.merchantName)
                } else {
                    put("rawMerchant", parsed.rawText)
                }
                put("type", parsed.transactionType)
                put("amount", parsed.amount)
                put("currency", parsed.currencyCode)
                if (!parsed.currencyEvidenceRaw.isNullOrBlank()) {
                    put("currencyEvidenceRaw", parsed.currencyEvidenceRaw)
                }
                put("currencyEvidenceType", parsed.currencyEvidenceType)
                put("currencyAmbiguous", parsed.currencyAmbiguous)
                if (accountCurrency.isNotBlank()) {
                    put("accountCurrency", accountCurrency)
                }
                put("date", parsed.transactionDate)
                put("packageName", packageName)
                put("sourceAppLabel", appLabel)
                if (!notificationKey.isNullOrBlank()) {
                    put("notificationKey", notificationKey)
                    put("externalSourceId", notificationKey)
                }
                if (notificationPostTimeMillis > 0) {
                    put(
                        "notificationPostTime",
                        java.time.Instant.ofEpochMilli(notificationPostTimeMillis).toString()
                    )
                }
                put("note", parsed.rawText)
            })
            if (scopeId != "personal") {
                put("householdId", scopeId)
                put("isPortfolio", isPortfolio)
            }
            if (accountId.isNotBlank()) {
                put("accountId", accountId)
            }
        }

        val accessToken = getValidAccessToken(config) ?: run {
            queueCapture(config, body, dedupKey, "access_token_unavailable")
            return
        }

        val url = URL("$supabaseUrl/functions/v1/save-wallet-transaction")
        val initialResponse = try {
            executeCaptureRequest(url, accessToken, anonKey, body)
        } catch (error: Exception) {
            queueCapture(config, body, dedupKey, "capture_network_error")
            return
        }

        when (initialResponse.statusCode) {
            200, 201 -> {
                Log.d(TAG, "Transaction captured successfully from $packageName")
                recordCaptureTelemetry(
                    action = "capture_success",
                    details = mapOf("statusCode" to initialResponse.statusCode)
                )
            }
            409 -> {
                if (isRequestInProgressResponse(initialResponse.responseBody)) {
                    Log.w(TAG, "Capture still in progress for $packageName - releasing local dedup for retry")
                    recentHashes.remove(dedupKey)
                } else {
                    Log.d(TAG, "Duplicate transaction detected server-side for $packageName")
                }
            }
            401, 408, 429 -> {
                queueCapture(
                    config,
                    body,
                    dedupKey,
                    "capture_http_${initialResponse.statusCode}"
                )
            }
            in 500..599 -> {
                queueCapture(
                    config,
                    body,
                    dedupKey,
                    "capture_http_${initialResponse.statusCode}"
                )
            }
            else -> {
                Log.w(TAG, "Backend error ${initialResponse.statusCode}: ${initialResponse.responseBody}")
            }
        }
    }

    private fun executeCaptureRequest(
        url: URL,
        accessToken: String,
        anonKey: String,
        body: JSONObject
    ): BackendCaptureResponse {
        val conn = url.openConnection() as HttpURLConnection

        return try {
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $accessToken")
            conn.setRequestProperty("apikey", anonKey)
            conn.doOutput = true
            conn.connectTimeout = 15_000
            conn.readTimeout = 15_000

            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(body.toString())
            }

            val responseCode = conn.responseCode
            val responseBody = try {
                BufferedReader(
                    InputStreamReader(
                        if (responseCode in 200..299) conn.inputStream else conn.errorStream,
                        Charsets.UTF_8
                    )
                ).use { it.readText() }
            } catch (_: Exception) {
                ""
            }

            BackendCaptureResponse(responseCode, responseBody)
        } finally {
            conn.disconnect()
        }
    }

    private fun isRequestInProgressResponse(responseBody: String): Boolean {
        return responseBody.contains("REQUEST_IN_PROGRESS", ignoreCase = true)
    }

    // ── Auth helpers ─────────────────────────────────────────────────────

    /** Returns the current access token without rotating the app session. */
    private fun getValidAccessToken(config: NotificationCaptureConfig): String? {
        val token = config.accessToken
        if (token.isBlank()) return null
        return token.takeUnless { config.isAccessTokenExpired }
    }

    private fun queueCapture(
        config: NotificationCaptureConfig,
        body: JSONObject,
        dedupKey: String,
        reason: String
    ) {
        val queued = config.enqueuePendingCapture(body, body.optString("idempotencyKey", dedupKey))
        if (!queued) recentHashes.remove(dedupKey)
        recordCaptureTelemetry(
            action = if (queued) "capture_queued" else "capture_queue_full",
            details = mapOf(
                "reason" to reason,
                "accessTokenExpired" to config.isAccessTokenExpired,
                "expiresAt" to config.expiresAt
            )
        )
    }

    private fun recordCaptureTelemetry(
        action: String,
        details: Map<String, Any?> = emptyMap()
    ) {
        val safeDetails = JSONObject()
        details.forEach { (key, value) ->
            if (value != null) {
                safeDetails.put(key, value)
            }
        }
        val message = "android_native_capture action=$action details=$safeDetails"
        Log.d(TAG, message)

        try {
            val crashlytics = FirebaseCrashlytics.getInstance()
            crashlytics.log(message)
            crashlytics.setCustomKey("android_capture_last_action", action)
            (details["statusCode"] as? Int)?.let {
                crashlytics.setCustomKey("android_capture_last_status", it)
            }
            (details["reason"] as? String)?.let {
                crashlytics.setCustomKey("android_capture_last_reason", it)
            }
        } catch (_: Exception) {
            // Telemetry must never block notification capture.
        }
    }

    // ── Dedup helpers ────────────────────────────────────────────────────

    private fun makeDedupKey(
        packageName: String,
        notificationKey: String?,
        title: String?,
        text: String?,
        bigText: String?,
        amount: Double,
        transactionType: String
    ): String {
        val contentKey = if (!notificationKey.isNullOrBlank()) {
            "notification:$notificationKey"
        } else {
            listOf(title, text, bigText)
                .joinToString("|") { it.orEmpty().trim().replace(Regex("""\s+"""), " ") }
        }
        val raw = "$packageName|$contentKey|$transactionType|$amount"
        val digest = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun buildRequestIdempotencyKey(
        dedupKey: String,
        scopeId: String,
        isPortfolio: Boolean,
        transactionType: String,
    ): String {
        val scopeKey = if (scopeId == "personal") "personal" else "$scopeId|$isPortfolio"
        return "android_notification_listener|$scopeKey|$transactionType|$dedupKey"
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

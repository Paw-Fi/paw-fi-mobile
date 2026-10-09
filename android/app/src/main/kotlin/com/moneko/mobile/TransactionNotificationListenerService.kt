package com.moneko.mobile

import android.content.ComponentName
import android.app.Notification
import android.content.pm.PackageManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.google.firebase.crashlytics.FirebaseCrashlytics
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap

/**
 * Listens for incoming notifications and auto-captures transaction data
 * from user-enabled banking/finance apps.
 *
 * Flow:
 * 1. Record every notification source in the recent-apps registry.
 * 2. For enabled packages, collect bounded visible notification text.
 * 3. Send non-empty candidates to the backend AI classifier for semantic review.
 * 4. Local dedup prevents re-sending identical notification content.
 */
class TransactionNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "MonekoCaptureService"
        private const val DEDUP_WINDOW_MS = 60_000L  // 60-second local dedup window
        private const val MAX_DEDUP_ENTRIES = 200
    }

    /**
     * Local dedup cache: SHA-256(packageName + notification key + visible content) → timestamp.
     * Prevents sending the same notification twice within [DEDUP_WINDOW_MS].
     */
    private val recentHashes = ConcurrentHashMap<String, Long>()

    override fun onCreate() {
        super.onCreate()
        NotificationCaptureConfig(applicationContext).pruneExpiredPendingCaptures()
    }

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
        val captureUserId = config.userId
        if (captureUserId.isBlank()) return

        // Extract notification text
        val extras = sbn.notification?.extras ?: return
        val isGroupSummary =
            (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
        val summaryText = extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString()
        val infoText = extras.getCharSequence(Notification.EXTRA_INFO_TEXT)?.toString()
        val conversationTitle =
            extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString()
        val tickerText = sbn.notification?.tickerText?.toString()
        val textLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.map(CharSequence::toString)
            ?: emptyList()
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            ?.let(Notification.MessagingStyle.Message::getMessagesFromBundleArray)
            ?.mapNotNull { message -> message.text?.toString() }
            ?: emptyList()
        val additionalText = extras.keySet()
            .asSequence()
            .filterNot { key -> key.startsWith("android.") }
            .flatMap { key ->
                when (val value = extras.get(key)) {
                    is CharSequence -> sequenceOf(value.toString())
                    is Array<*> -> value.asSequence()
                        .filterIsInstance<CharSequence>()
                        .map(CharSequence::toString)
                    else -> emptySequence()
                }
            }
            .map(String::trim)
            .filter(String::isNotEmpty)
            .distinct()
            .take(20)
            .toList()

        // Must have at least some text to parse
        val content = NotificationCaptureCandidate.buildContent(
            title = title,
            text = text,
            bigText = bigText,
            subText = subText,
            textLines = textLines,
            summaryText = summaryText,
            infoText = infoText,
            conversationTitle = conversationTitle,
            tickerText = tickerText,
            messages = messages,
            additionalText = additionalText,
        )
        if (!NotificationCaptureCandidate.shouldAnalyze(content)) return

        // Local dedup
        val dedupKey = NotificationCaptureCandidate.buildEventFingerprint(
            packageName = packageName,
            notificationKey = sbn.key,
            content = content,
            notificationPostTimeMillis = sbn.postTime,
        )
        if (isDuplicate(dedupKey)) {
            return
        }

        // Mark as seen
        recentHashes[dedupKey] = System.currentTimeMillis()
        pruneOldHashes()

        recordCaptureTelemetry(
            action = "capture_attempted",
            details = mapOf(
                "accessTokenExpired" to config.isAccessTokenExpired,
                "expiresAt" to config.expiresAt,
                "enabledPackagesCount" to config.getEnabledPackages().size
            )
        )

        val body = buildCaptureRequestBody(
            config = config,
            packageName = packageName,
            appLabel = appLabel,
            notificationKey = sbn.key,
            notificationPostTimeMillis = sbn.postTime,
            dedupKey = dedupKey,
            title = title,
            text = text,
            bigText = bigText,
            subText = subText,
            textLines = textLines,
            summaryText = summaryText,
            infoText = infoText,
            conversationTitle = conversationTitle,
            tickerText = tickerText,
            messages = messages,
            additionalText = additionalText,
            isGroupSummary = isGroupSummary,
        )
        body.put("userId", captureUserId)
        body.put("idempotencyKey", "$captureUserId|${body.optString("idempotencyKey")}")
        val queued = config.enqueuePendingCapture(
            body,
            body.optString("idempotencyKey", dedupKey),
        )
        if (!queued) {
            recentHashes.remove(dedupKey)
            recordCaptureTelemetry("capture_queue_unavailable")
            return
        }

        // All entry points share the same transport and in-process drain lock.
        val context = applicationContext
        NotificationCaptureDispatcher.executor.submit {
            NotificationCaptureDispatcher.drain(NotificationCaptureConfig(context), captureUserId)
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        val context = applicationContext
        NotificationCaptureDispatcher.executor.submit {
            val config = NotificationCaptureConfig(context)
            NotificationCaptureDispatcher.drain(config, config.userId)
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        runCatching {
            requestRebind(ComponentName(this, TransactionNotificationListenerService::class.java))
        }.onFailure { Log.w(TAG, "Notification listener rebind unavailable") }
    }

    private fun buildCaptureRequestBody(
        config: NotificationCaptureConfig,
        packageName: String,
        appLabel: String,
        notificationKey: String?,
        notificationPostTimeMillis: Long,
        dedupKey: String,
        title: String?,
        text: String?,
        bigText: String?,
        subText: String?,
        textLines: List<String>,
        summaryText: String?,
        infoText: String?,
        conversationTitle: String?,
        tickerText: String?,
        messages: List<String>,
        additionalText: List<String>,
        isGroupSummary: Boolean,
    ): JSONObject {
        val scopeId = config.scopeId
        val isPortfolio = config.isPortfolio
        return JSONObject().apply {
            put("captureSource", "android_notification_listener")
            put(
                "idempotencyKey",
                buildRequestIdempotencyKey(dedupKey, scopeId, isPortfolio),
            )
            put("clientCreatedAt", java.time.Instant.now().toString())
            put("notification", JSONObject().apply {
                put("packageName", packageName)
                put("sourceAppLabel", appLabel)
                put("isGroupSummary", isGroupSummary)
                if (!notificationKey.isNullOrBlank()) {
                    put("notificationKey", notificationKey)
                    put("externalSourceId", notificationKey)
                }
                if (notificationPostTimeMillis > 0) {
                    put(
                        "notificationPostTime",
                        java.time.Instant.ofEpochMilli(notificationPostTimeMillis).toString(),
                    )
                }
                title?.takeIf { it.isNotBlank() }?.let { put("title", it.take(2_000)) }
                text?.takeIf { it.isNotBlank() }?.let { put("text", it.take(2_000)) }
                bigText?.takeIf { it.isNotBlank() }?.let { put("bigText", it.take(2_000)) }
                subText?.takeIf { it.isNotBlank() }?.let { put("subText", it.take(2_000)) }
                summaryText?.takeIf { it.isNotBlank() }?.let {
                    put("summaryText", it.take(2_000))
                }
                infoText?.takeIf { it.isNotBlank() }?.let { put("infoText", it.take(2_000)) }
                conversationTitle?.takeIf { it.isNotBlank() }?.let {
                    put("conversationTitle", it.take(2_000))
                }
                tickerText?.takeIf { it.isNotBlank() }?.let {
                    put("tickerText", it.take(2_000))
                }
                if (textLines.isNotEmpty()) {
                    put("textLines", org.json.JSONArray(textLines.take(20).map { it.take(500) }))
                }
                if (messages.isNotEmpty()) {
                    put("messages", org.json.JSONArray(messages.take(20).map { it.take(500) }))
                }
                if (additionalText.isNotEmpty()) {
                    put(
                        "additionalText",
                        org.json.JSONArray(additionalText.take(20).map { it.take(500) }),
                    )
                }
            })
            if (scopeId != "personal") {
                put("householdId", scopeId)
                put("isPortfolio", isPortfolio)
            }
            if (config.accountId.isBlank()) {
                put("accountId", JSONObject.NULL)
            } else {
                put("accountId", config.accountId)
            }
            config.accountCurrency.takeIf { it.isNotBlank() }?.let {
                put("accountCurrency", it)
            }
        }
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

    private fun buildRequestIdempotencyKey(
        dedupKey: String,
        scopeId: String,
        isPortfolio: Boolean,
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

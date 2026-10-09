package com.moneko.mobile

import android.util.Log
import com.google.firebase.crashlytics.FirebaseCrashlytics
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/** One transport for live notifications, WorkManager recovery and Flutter replay. */
internal object NotificationCaptureDispatcher {
    private const val TAG = "MonekoCaptureDispatcher"
    private val drainLock = Any()
    val executor = Executors.newSingleThreadExecutor()

    @Volatile
    var onCaptured: ((String, Long) -> Unit)? = null

    fun drain(
        config: NotificationCaptureConfig,
        userId: String,
        recordId: String? = null,
    ): Map<String, Any> = synchronized(drainLock) {
        var synced = 0
        var requiresSessionRefresh = false
        val startedAt = System.currentTimeMillis()
        if (userId.isNotBlank() && config.userId == userId) {
            for (record in config.getPendingCaptures()) {
                if (recordId != null && record["id"] != recordId) continue
                if (config.userId != userId || record["userId"] != userId) break
                if (System.currentTimeMillis() - startedAt >= 90_000) break
                val id = record["id"] as? String ?: continue
                // The record can have been removed while this drain waited for the lock.
                val body = runCatching { JSONObject(record["body"] as String) }.getOrNull()
                    ?: continue
                if (body.optString("userId") != userId) continue
                val token = config.accessTokenForUser(userId)
                if (token == null || config.supabaseUrl.isBlank() || config.supabaseAnonKey.isBlank()) {
                    requiresSessionRefresh = true
                    trace(id, "waiting_for_auth", record)
                    break
                }
                val requestStartedAt = System.currentTimeMillis()
                trace(id, "processing", record)
                val response = try {
                    // Freeze the actor's token. Never retry an old body with a new actor.
                    if (config.userId != userId) break
                    send(config.supabaseUrl, config.supabaseAnonKey, token, body)
                } catch (_: Exception) {
                    trace(id, "retryable_network_failure", record, requestStartedAt)
                    break
                }
                val payload = runCatching { JSONObject(response.second) }.getOrNull()
                val savedId = payload?.optJSONObject("data")?.opt("id") as? String
                val confirmed = response.first in 200..201 && payload?.opt("success") == true &&
                    (payload.opt("ignored") == true || payload.opt("duplicate") == true ||
                        !savedId.isNullOrBlank())
                val terminal = response.first in setOf(400, 403, 422) ||
                    (response.first == 409 && payload?.optString("code") != "REQUEST_IN_PROGRESS" &&
                        !response.second.contains("REQUEST_IN_PROGRESS"))
                if (!confirmed && !terminal) {
                    requiresSessionRefresh = response.first == 401
                    trace(id, "retryable_response", record, requestStartedAt, response.first)
                    break
                }
                val saved = confirmed && payload?.opt("ignored") != true
                val revision = config.completePendingCapture(id, userId, saved)
                if (revision == null) break
                trace(id, if (saved) "saved" else if (confirmed) "ignored" else "rejected",
                    record, requestStartedAt, response.first)
                if (saved) {
                    synced += 1
                    runCatching { onCaptured?.invoke(userId, revision) }
                }
            }
        }
        mapOf(
            "userId" to userId,
            "synced" to synced,
            "requiresSessionRefresh" to requiresSessionRefresh,
            "revision" to (if (config.userId == userId) config.captureRevision else 0L),
            "remaining" to config.getPendingCaptures().count {
                it["userId"] == userId && (recordId == null || it["id"] == recordId)
            },
        )
    }

    private fun send(baseUrl: String, anonKey: String, token: String, body: JSONObject): Pair<Int, String> {
        // Legacy queued wallet payloads remain replayable during upgrades.
        val function = if (body.optJSONObject("notification") != null) {
            "classify-notification-capture"
        } else {
            "save-wallet-transaction"
        }
        val connection = URL("$baseUrl/functions/v1/$function").openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("apikey", anonKey)
            connection.doOutput = true
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.outputStream.bufferedWriter(Charsets.UTF_8).use { it.write(body.toString()) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            status to text
        } finally {
            connection.disconnect()
        }
    }

    private fun trace(
        id: String,
        stage: String,
        record: Map<String, Any?>,
        startedAt: Long? = null,
        status: Int? = null,
    ) {
        val now = System.currentTimeMillis()
        val age = now - ((record["queuedAt"] as? Number)?.toLong() ?: now)
        val message = "android_native_capture id=$id stage=$stage ageMs=$age " +
            "elapsedMs=${startedAt?.let { now - it } ?: 0} status=$status"
        Log.i(TAG, message)
        runCatching { FirebaseCrashlytics.getInstance().log(message) }
    }
}

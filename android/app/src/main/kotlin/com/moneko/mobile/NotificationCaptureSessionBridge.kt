package com.moneko.mobile

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/** Access tokens only cross this bridge; Flutter remains the refresh-token owner. */
internal object NotificationCaptureSessionBridge {
    fun recoverAccessToken(config: NotificationCaptureConfig, userId: String, forceRefresh: Boolean): String? {
        check(Looper.myLooper() != Looper.getMainLooper()) { "Session recovery must not block main" }
        val generation = config.authGeneration
        if (config.userId != userId || Thread.currentThread().isInterrupted) return null
        val completed = CountDownLatch(1)
        val active = AtomicBoolean(true)
        val response = AtomicReference<Map<*, *>?>(null)
        val handler = Handler(Looper.getMainLooper())
        handler.post {
            if (!active.get()) return@post
            try {
                val channel = NotificationCaptureRuntime.captureChannel(config.appContext)
                NotificationCaptureSessionRequest(
                    invoke = { reply ->
                        channel.invokeMethod("getCurrentSessionForNotificationCapture",
                            mapOf("userId" to userId, "forceRefresh" to forceRefresh), reply)
                    },
                    schedule = { delay, task -> handler.postDelayed(task, delay) },
                    isActive = { active.get() && config.userId == userId && config.authGeneration == generation },
                    completion = { payload -> response.set(payload); completed.countDown() },
                ).start()
            } catch (_: Exception) {
                completed.countDown()
            }
        }
        try {
            if (!completed.await(15, TimeUnit.SECONDS)) return null
            val payload = response.get() ?: return null
            if (payload["userId"] != userId) return null
            val token = payload["accessToken"] as? String ?: return null
            val expiry = (payload["expiresAt"] as? Number)?.toLong() ?: return null
            if (Thread.currentThread().isInterrupted ||
                !config.updateAccessTokenForUser(userId, generation, token, expiry)) return null
            return config.accessTokenForUser(userId)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            return null
        } finally {
            active.set(false)
        }
    }
}

/** Main-thread, one-shot request. Only handler-startup absence is retried. */
internal class NotificationCaptureSessionRequest(
    private val invoke: (MethodChannel.Result) -> Unit,
    private val schedule: (Long, () -> Unit) -> Unit,
    private val isActive: () -> Boolean,
    private val completion: (Map<*, *>?) -> Unit,
) {
    private var finished = false

    fun start() {
        schedule(12_000) { finish(null) }
        attempt()
    }

    private fun attempt() {
        if (finished) return
        if (!isActive()) { finish(null); return }
        invoke(object : MethodChannel.Result {
            override fun success(result: Any?) = finish(result as? Map<*, *>)
            override fun error(code: String, message: String?, details: Any?) = finish(null)
            override fun notImplemented() {
                if (!finished) schedule(200) { attempt() }
            }
        })
    }

    private fun finish(payload: Map<*, *>?) {
        if (finished) return
        finished = true
        completion(if (isActive()) payload else null)
    }
}

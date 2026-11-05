package com.moneko.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal data class AiAnalysisNotice(
    val id: String, val messages: Map<String, String>, var background: Boolean,
    var stage: String = "analyzing", var outcome: String? = null,
)

/** Native execution lease; no financial data or a second save implementation. */
object AiAnalysisBackgroundBridge {
    private var channel: MethodChannel? = null
    internal var notice: AiAnalysisNotice? = null
    private const val CHANNEL = "moneko_ai_analysis"
    internal const val NOTIFICATION_ID = 7104

    fun register(context: Context, messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "moneko/ai_background_execution").also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                val args = call.arguments as? Map<*, *>
                val id = args?.get("id") as? String
                if (id == null) {
                    result.error("INVALID_AI_EXECUTION", "Missing execution identity", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "start" -> {
                        val messages = (args["messages"] as? Map<*, *>)?.entries
                            ?.mapNotNull { (key, value) -> if (key is String && value is String) key to value else null }
                            ?.toMap().orEmpty()
                        val next = AiAnalysisNotice(id, messages, args["background"] == true)
                        notice = next
                        try {
                            ensureChannel(context, next)
                            ContextCompat.startForegroundService(context, Intent(context, AiAnalysisForegroundService::class.java).putExtra("id", id))
                            result.success(true)
                        } catch (_: Exception) {
                            notice = null
                            result.success(false)
                        }
                    }
                    "update" -> {
                        val current = notice?.takeIf { it.id == id }
                        if (current != null) {
                            current.background = args["background"] as? Boolean ?: current.background
                            val stage = args["stage"] as? String
                            if (stage == "analyzing" || stage == "saving") current.stage = stage
                            if (current.outcome == null || current.background) publish(context, current)
                        }
                        result.success(null)
                    }
                    "finish" -> {
                        val current = notice?.takeIf { it.id == id }
                        if (current != null) {
                            current.background = args["background"] as? Boolean ?: current.background
                            current.outcome = args["outcome"] as? String ?: "paused"
                            context.stopService(Intent(context, AiAnalysisForegroundService::class.java))
                            if (current.background && current.outcome != "cancelled") publish(context, current)
                            else manager(context).cancel(NOTIFICATION_ID)
                            if (current.outcome == "cancelled") notice = null
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun detach(context: Context) {
        notice?.let { expire(context, it.id) }
        channel?.setMethodCallHandler(null)
        channel = null
    }

    internal fun expire(context: Context, id: String) {
        val current = notice?.takeIf { it.id == id && it.outcome == null } ?: return
        current.outcome = "paused"
        channel?.invokeMethod("expired", id)
        context.stopService(Intent(context, AiAnalysisForegroundService::class.java))
        if (current.background) publish(context, current)
    }

    internal fun serviceStopped(context: Context, id: String) {
        val current = notice?.takeIf { it.id == id && it.outcome != null } ?: return
        if (current.background && current.outcome != "cancelled") publish(context, current)
    }

    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)

    private fun ensureChannel(context: Context, state: AiAnalysisNotice) {
        if (Build.VERSION.SDK_INT >= 26) {
            manager(context).createNotificationChannel(NotificationChannel(CHANNEL,
                state.messages["channel"] ?: state.messages["title"], NotificationManager.IMPORTANCE_LOW))
        }
    }

    internal fun notification(context: Context, state: AiAnalysisNotice): Notification {
        ensureChannel(context, state)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            ?: Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(context, NOTIFICATION_ID, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val ongoing = state.outcome == null
        return NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher_monochrome)
            .setContentTitle(state.messages["title"] ?: "Moneko")
            .setContentText(state.messages[state.outcome ?: state.stage] ?: state.messages["paused"])
            .setContentIntent(pending).setOnlyAlertOnce(true).setSilent(true)
            .setOngoing(ongoing).setAutoCancel(!ongoing)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setProgress(0, 0, ongoing).build()
    }

    private fun publish(context: Context, state: AiAnalysisNotice) {
        try { manager(context).notify(NOTIFICATION_ID, notification(context, state)) }
        catch (_: SecurityException) { /* Notifications remain user-controlled. */ }
    }
}

class AiAnalysisForegroundService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var id: String? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val timeout = Runnable { id?.let { AiAnalysisBackgroundBridge.expire(this, it) } }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val incomingId = intent?.getStringExtra("id")
        val state = AiAnalysisBackgroundBridge.notice?.takeIf { it.outcome == null }
        if (state == null) { stopSelf(startId); return START_NOT_STICKY }
        // A delayed start for an old token must not stop or re-arm a newer job.
        if (state.id != incomingId) return START_NOT_STICKY
        id = state.id
        val notification = AiAnalysisBackgroundBridge.notification(this, state)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(AiAnalysisBackgroundBridge.NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else { startForeground(AiAnalysisBackgroundBridge.NOTIFICATION_ID, notification) }
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "moneko:ai-analysis")
            .apply { acquire(6 * 60 * 1000L) }
        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, 6 * 60 * 1000L)
        return START_NOT_STICKY
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        id?.let { AiAnalysisBackgroundBridge.expire(this, it) }
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacks(timeout)
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        id?.let { AiAnalysisBackgroundBridge.expire(this, it) }
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
        id?.let { AiAnalysisBackgroundBridge.serviceStopped(this, it) }
    }
}

package com.moneko.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.net.Uri
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

internal data class AiAnalysisNotice(
    val id: String, val messages: Map<String, String>, var background: Boolean,
    var stage: String = "analyzing", var outcome: String? = null,
    val userId: String = "", val captureId: String = "",
    var successUntil: Long? = null,
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
                if (call.method == "pendingStops" || call.method == "pendingFailures") {
                    try { result.success(if (call.method == "pendingStops") pendingStops(context) else pendingFailures(context)) }
                    catch (_: Exception) { result.error("AI_STOP_STORAGE", "Could not read cancellation", null) }
                    return@setMethodCallHandler
                }
                val args = call.arguments as? Map<*, *>
                val id = args?.get("id") as? String
                if (id == null) {
                    result.error("INVALID_AI_EXECUTION", "Missing execution identity", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "acknowledgeStop" -> {
                        try { acknowledgeStop(context, id); result.success(null) }
                        catch (_: Exception) { result.error("AI_STOP_STORAGE", "Could not acknowledge cancellation", null) }
                    }
                    "acknowledgeFailure" -> {
                        try { acknowledgeFailure(context, id); result.success(null) }
                        catch (_: Exception) { result.error("AI_ATTENTION_STORAGE", "Could not acknowledge analysis failure", null) }
                    }
                    "start" -> {
                        val messages = (args["messages"] as? Map<*, *>)?.entries
                            ?.mapNotNull { (key, value) -> if (key is String && value is String) key to value else null }
                            ?.toMap().orEmpty()
                        val next = AiAnalysisNotice(id, messages, args["background"] == true,
                            outcome = args["outcome"] as? String,
                            userId = args["userId"] as? String ?: "", captureId = args["captureId"] as? String ?: "")
                        notice = next
                        if (next.outcome != null) {
                            publish(context, next)
                            result.success(false)
                            return@setMethodCallHandler
                        }
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
                        if (current != null && current.outcome != "cancelled") {
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
                            if (current.outcome != "cancelled") current.outcome = args["outcome"] as? String ?: "paused"
                            if (current.outcome == "queued" || current.outcome == "review") current.successUntil = SystemClock.elapsedRealtime() + 5000L
                            if (current.outcome == "error" || current.outcome == "paused") recordFailure(context, current)
                            context.stopService(Intent(context, AiAnalysisForegroundService::class.java))
                            if (current.outcome != "cancelled") publish(context, current)
                            else manager(context).cancel(NOTIFICATION_ID)
                            if (current.outcome == "cancelled") { acknowledgeFailure(context, id); notice = null }
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
        current.outcome = "error"
        recordFailure(context, current)
        channel?.invokeMethod("expired", id)
        context.stopService(Intent(context, AiAnalysisForegroundService::class.java))
        publish(context, current)
    }

    internal fun serviceStopped(context: Context, id: String) {
        val current = notice?.takeIf { it.id == id && it.outcome != null } ?: return
        if (current.outcome != "cancelled") publish(context, current)
    }

    internal fun pendingStops(context: Context): List<Map<String, String>> =
        context.getSharedPreferences("ai_analysis_stops", Context.MODE_PRIVATE).all.map { (_, value) ->
            val record = JSONObject(value as String)
            mapOf("id" to record.getString("id"), "captureId" to record.getString("captureId"),
                "userId" to record.getString("userId"))
        }

    internal fun acknowledgeStop(context: Context, id: String) {
        check(context.getSharedPreferences("ai_analysis_stops", Context.MODE_PRIVATE).edit().remove(id).commit())
    }

    internal fun pendingFailures(context: Context): List<Map<String, String>> =
        context.getSharedPreferences("ai_analysis_errors", Context.MODE_PRIVATE).all.map { (_, value) ->
            val record = JSONObject(value as String)
            mapOf("id" to record.getString("id"), "captureId" to record.getString("captureId"), "userId" to record.getString("userId"))
        }

    internal fun acknowledgeFailure(context: Context, id: String) {
        check(context.getSharedPreferences("ai_analysis_errors", Context.MODE_PRIVATE).edit().remove(id).commit())
    }

    private fun recordFailure(context: Context, state: AiAnalysisNotice) {
        if (state.userId.isEmpty() || state.captureId.isEmpty()) return
        val record = JSONObject(mapOf("id" to state.id, "captureId" to state.captureId, "userId" to state.userId)).toString()
        if (!context.getSharedPreferences("ai_analysis_errors", Context.MODE_PRIVATE).edit().putString(state.id, record).commit()) {
            android.util.Log.w("MonekoAnalysis", "Could not persist analysis failure metadata")
        }
    }

    internal fun stop(context: Context, id: String, captureId: String, userId: String) {
        require(id.isNotEmpty() && captureId.isNotEmpty() && userId.isNotEmpty())
        val record = JSONObject(mapOf("id" to id, "captureId" to captureId, "userId" to userId)).toString()
        // Synchronous disk commit precedes Dart delivery and notification removal.
        check(context.getSharedPreferences("ai_analysis_stops", Context.MODE_PRIVATE).edit().putString(id, record).commit())
        acknowledgeFailure(context, id)
        notice?.takeIf { it.id == id }?.let {
            it.outcome = "cancelled"
            context.stopService(Intent(context, AiAnalysisForegroundService::class.java))
            manager(context).cancel(NOTIFICATION_ID)
        }
        channel?.invokeMethod("stopped", id)
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
        // Avoid ACTION_VIEW: receive_sharing_intent treats those URLs as files.
        launch.action = "com.moneko.mobile.OPEN_AI_ANALYSIS"
        launch.data = Uri.Builder().scheme("moneko").authority("ai-analysis")
            .appendQueryParameter("captureId", state.captureId).appendQueryParameter("userId", state.userId)
            .appendQueryParameter("executionId", state.id).build()
        val pending = PendingIntent.getActivity(context, NOTIFICATION_ID, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val ongoing = state.outcome == null
        val success = state.outcome == "queued" || state.outcome == "review"
        val confirmation = state.outcome == "needsInput"
        val titleKey = if (ongoing) "loadingTitle" else if (success) "successTitle" else if (confirmation) "confirmationTitle" else "errorTitle"
        val icon = if (ongoing) R.mipmap.ic_launcher_monochrome else if (success) R.drawable.ai_analysis_success else if (confirmation) R.drawable.ai_analysis_confirmation else R.drawable.ai_analysis_error
        val builder = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(icon)
            .setContentTitle(state.messages[titleKey] ?: state.messages["title"] ?: "Moneko")
            .setContentText(state.messages[if (state.outcome == "paused") "error" else state.outcome ?: state.stage] ?: state.messages["paused"])
            .setContentIntent(pending).setOnlyAlertOnce(true).setSilent(true)
            .setOngoing(ongoing).setAutoCancel(success)
            .setCategory(if (ongoing) NotificationCompat.CATEGORY_PROGRESS else if (success) NotificationCompat.CATEGORY_STATUS else NotificationCompat.CATEGORY_ERROR)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setProgress(0, 0, ongoing)
            .setTimeoutAfter(if (success) (state.successUntil?.minus(SystemClock.elapsedRealtime()) ?: 5000L).coerceAtLeast(1L) else 0L)
        if (!success && state.userId.isNotEmpty() && state.captureId.isNotEmpty()) {
            val stop = Intent(context, AiAnalysisStopReceiver::class.java)
                .setData(Uri.parse("moneko-ai-stop:${Uri.encode(state.id)}"))
                .putExtra("id", state.id).putExtra("captureId", state.captureId).putExtra("userId", state.userId)
            builder.addAction(android.R.drawable.ic_media_pause, state.messages["stop"] ?: "Stop",
                PendingIntent.getBroadcast(context, 0, stop, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }
        return builder.build()
    }

    private fun publish(context: Context, state: AiAnalysisNotice) {
        if (state.successUntil?.let { it <= SystemClock.elapsedRealtime() } == true) {
            manager(context).cancel(NOTIFICATION_ID)
            return
        }
        try { manager(context).notify(NOTIFICATION_ID, notification(context, state)) }
        catch (_: SecurityException) { /* Notifications remain user-controlled. */ }
    }
}

/** Private, immutable notification action; works even without a Flutter engine. */
class AiAnalysisStopReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: return
        val capture = intent.getStringExtra("captureId") ?: return
        val user = intent.getStringExtra("userId") ?: return
        try { AiAnalysisBackgroundBridge.stop(context, id, capture, user) }
        catch (_: Exception) { /* Keep progress visible if durable Stop failed. */ }
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

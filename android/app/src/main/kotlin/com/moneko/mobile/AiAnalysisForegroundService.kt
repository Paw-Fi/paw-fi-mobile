package com.moneko.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.net.Uri
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PersistableBundle
import android.os.PowerManager
import android.os.SystemClock
import androidx.annotation.RequiresApi
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
    /** Last localized copy, for the placeholder a superseded service start must still show. */
    private var lastMessages: Map<String, String> = emptyMap()
    /**
     * True between startForegroundService() and the service's onStartCommand().
     * Stopping the service in that window would skip the mandatory
     * startForeground() call, so the service stops itself instead.
     */
    internal var foregroundStartPending = false
    /** True while the service is promoted and owns [NOTIFICATION_ID]. */
    internal var serviceActive = false
    /**
     * While the service owns the notification ID, stopping it removes whatever
     * that ID shows, so final states are published from onDestroy instead.
     * Publishing both would alert twice.
     */
    private val serviceOwnsNotification get() = serviceActive || foregroundStartPending
    /**
     * Android 14+ runs execution as a user-initiated data transfer job, the
     * platform's recommended replacement for a dataSync foreground service for
     * user-triggered uploads. Its progress lives on [JOB_NOTIFICATION_ID], so
     * final states on [NOTIFICATION_ID] never race the job's notification removal.
     */
    internal var usingTransferJob = false
    internal var activeJob: AiAnalysisTransferJobService? = null
    private const val CHANNEL = "moneko_ai_analysis"
    private const val ATTENTION_CHANNEL = "moneko_ai_analysis_attention"
    internal const val NOTIFICATION_ID = 7104
    internal const val JOB_NOTIFICATION_ID = 7105
    internal const val JOB_ID = 7104
    internal val progressNotificationId get() = if (usingTransferJob) JOB_NOTIFICATION_ID else NOTIFICATION_ID

    fun register(context: Context, messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "moneko/ai_background_execution").also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                if (call.method == "clear") {
                    clear(context)
                    result.success(null)
                    return@setMethodCallHandler
                }
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
                        lastMessages = messages
                        if (next.outcome != null) {
                            publish(context, next)
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        ensureChannels(context, messages)
                        if (Build.VERSION.SDK_INT >= 34 && scheduleTransferJob(context, id)) {
                            usingTransferJob = true
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        usingTransferJob = false
                        try {
                            ContextCompat.startForegroundService(context, Intent(context, AiAnalysisForegroundService::class.java).putExtra("id", id))
                            foregroundStartPending = true
                            result.success(true)
                        } catch (_: Exception) {
                            // e.g. ForegroundServiceStartNotAllowedException; foreground
                            // processing and durable resume continue without a lease.
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
                            val ownedByService = serviceOwnsNotification
                            stopExecution(context)
                            if (current.outcome == "cancelled") manager(context).cancel(NOTIFICATION_ID)
                            else if (!ownedByService) publish(context, current)
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
        val ownedByService = serviceOwnsNotification
        stopExecution(context)
        if (!ownedByService) publish(context, current)
    }

    /** Removes presentation no in-memory attempt owns (actor or consent change). */
    internal fun clear(context: Context) {
        notice = null
        stopExecution(context)
        manager(context).cancel(NOTIFICATION_ID)
    }

    private fun stopExecution(context: Context) {
        if (usingTransferJob && Build.VERSION.SDK_INT >= 34) {
            // A running job reports completion; a job still waiting for its
            // network constraint is cancelled before it can start.
            activeJob?.complete() ?: context.getSystemService(JobScheduler::class.java).cancel(JOB_ID)
            manager(context).cancel(JOB_NOTIFICATION_ID)
            return
        }
        if (!foregroundStartPending) context.stopService(Intent(context, AiAnalysisForegroundService::class.java))
    }

    @RequiresApi(34)
    private fun scheduleTransferJob(context: Context, id: String): Boolean = try {
        val job = JobInfo.Builder(JOB_ID, ComponentName(context, AiAnalysisTransferJobService::class.java))
            .setUserInitiated(true)
            // Required for user-initiated jobs; analysis needs the network anyway.
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setExtras(PersistableBundle().apply { putString("id", id) })
            .build()
        // Scheduling the same job ID replaces any older attempt's job.
        context.getSystemService(JobScheduler::class.java).schedule(job) == JobScheduler.RESULT_SUCCESS
    } catch (_: Exception) {
        // Not visible / not permitted: fall back to the foreground service.
        false
    }

    internal fun serviceStopped(context: Context, id: String, promotionFailed: Boolean = false) {
        val current = notice?.takeIf { it.id == id && (promotionFailed || it.outcome != null) } ?: return
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
            stopExecution(context)
            manager(context).cancel(NOTIFICATION_ID)
        }
        channel?.invokeMethod("stopped", id)
    }

    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)

    private fun ensureChannels(context: Context, messages: Map<String, String>) {
        if (Build.VERSION.SDK_INT >= 26) {
            val progressName = messages["channel"] ?: messages["title"] ?: "Moneko"
            manager(context).createNotificationChannels(listOf(
                NotificationChannel(CHANNEL, progressName, NotificationManager.IMPORTANCE_LOW),
                // Errors/confirmation reached while Moneko is not visible peek once,
                // silently; users can tune this channel independently of progress.
                NotificationChannel(ATTENTION_CHANNEL, messages["attentionChannel"] ?: progressName,
                    NotificationManager.IMPORTANCE_HIGH).apply {
                    setSound(null, null)
                    enableVibration(false)
                },
            ))
        }
    }

    /** Minimal content for a service start whose attempt already finished or was replaced. */
    internal fun placeholder(context: Context): Notification {
        ensureChannels(context, lastMessages)
        return NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher_monochrome)
            .setColor(ContextCompat.getColor(context, R.color.notification_color))
            .setContentTitle(lastMessages["title"] ?: "Moneko")
            .setSilent(true).setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    internal fun notification(context: Context, state: AiAnalysisNotice): Notification {
        ensureChannels(context, state.messages)
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
        val attention = !ongoing && !success
        // Alert only while in-app UI cannot present the state; onlyAlertOnce
        // keeps later lifecycle republishes of the same state quiet.
        val alerting = attention && state.background
        val titleKey = if (ongoing) "loadingTitle" else if (success) "successTitle" else if (confirmation) "confirmationTitle" else "errorTitle"
        val icon = if (ongoing) R.mipmap.ic_launcher_monochrome else if (success) R.drawable.ai_analysis_success else if (confirmation) R.drawable.ai_analysis_confirmation else R.drawable.ai_analysis_error
        val text = state.messages[if (state.outcome == "paused") "error" else state.outcome ?: state.stage] ?: state.messages["paused"]
        val builder = NotificationCompat.Builder(context, if (alerting) ATTENTION_CHANNEL else CHANNEL)
            .setSmallIcon(icon)
            .setColor(ContextCompat.getColor(context, R.color.notification_color))
            .setContentTitle(state.messages[titleKey] ?: state.messages["title"] ?: "Moneko")
            .setContentText(text)
            .setContentIntent(pending).setOnlyAlertOnce(true)
            // NotificationCompat's silent mode also suppresses heads-up, so the
            // alerting channel is silenced at the channel level instead.
            .setSilent(!alerting)
            .setPriority(if (alerting) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_LOW)
            .setOngoing(ongoing).setAutoCancel(success).setShowWhen(!ongoing)
            .setCategory(if (ongoing) NotificationCompat.CATEGORY_PROGRESS else if (confirmation || success) NotificationCompat.CATEGORY_STATUS else NotificationCompat.CATEGORY_ERROR)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setProgress(0, 0, ongoing)
            // Android 16 Live Update while the user-started analysis runs: the
            // status chip shows the small icon for indeterminate progress.
            // Ignored on older versions or when the user disables promotion.
            .setRequestPromotedOngoing(ongoing)
            .setTimeoutAfter(if (success) (state.successUntil?.minus(SystemClock.elapsedRealtime()) ?: 5000L).coerceAtLeast(1L) else 0L)
        // Long translations stay readable when expanded instead of being cut to one line.
        if (!ongoing && text != null) builder.setStyle(NotificationCompat.BigTextStyle().bigText(text))
        if (!success && state.userId.isNotEmpty() && state.captureId.isNotEmpty()) {
            val stop = Intent(context, AiAnalysisStopReceiver::class.java)
                .setData(Uri.parse("moneko-ai-stop:${Uri.encode(state.id)}"))
                .putExtra("id", state.id).putExtra("captureId", state.captureId).putExtra("userId", state.userId)
            // Same durable Stop; nothing is running in attention states, so it reads as Cancel.
            val label = if (ongoing) state.messages["stop"] else state.messages["cancel"] ?: state.messages["stop"]
            builder.addAction(R.drawable.ai_analysis_stop, label ?: "Stop",
                PendingIntent.getBroadcast(context, 0, stop, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }
        return builder.build()
    }

    private fun publish(context: Context, state: AiAnalysisNotice) {
        if (state.successUntil?.let { it <= SystemClock.elapsedRealtime() } == true) {
            manager(context).cancel(NOTIFICATION_ID)
            return
        }
        val target = if (state.outcome == null) progressNotificationId else NOTIFICATION_ID
        try { manager(context).notify(target, notification(context, state)) }
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
        AiAnalysisBackgroundBridge.foregroundStartPending = false
        val current = AiAnalysisBackgroundBridge.notice
        val state = current?.takeIf { it.outcome == null }
        // Every startForegroundService() must be answered by startForeground(),
        // even when the attempt finished or was replaced before this delivery.
        val notification = if (state != null) AiAnalysisBackgroundBridge.notification(this, state)
            else AiAnalysisBackgroundBridge.placeholder(this)
        if (!promote(notification)) {
            // Promotion can be refused (e.g. the app left the foreground first).
            // Keep the user-visible notice; the Dart lease continues in foreground.
            state?.let { AiAnalysisBackgroundBridge.serviceStopped(this, it.id, promotionFailed = true) }
            stopSelf(startId)
            return START_NOT_STICKY
        }
        AiAnalysisBackgroundBridge.serviceActive = true
        if (state == null) {
            // Finished during the start window; onDestroy restores its final state.
            stopSelf()
            return START_NOT_STICKY
        }
        // A delayed start for an old token must not stop or re-arm a newer job.
        if (state.id != incomingId) return START_NOT_STICKY
        id = state.id
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "moneko:ai-analysis")
            .apply { acquire(6 * 60 * 1000L) }
        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, 6 * 60 * 1000L)
        return START_NOT_STICKY
    }

    private fun promote(notification: Notification): Boolean = try {
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(AiAnalysisBackgroundBridge.NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else { startForeground(AiAnalysisBackgroundBridge.NOTIFICATION_ID, notification) }
        true
    } catch (_: Exception) {
        // ForegroundServiceStartNotAllowedException / SecurityException.
        false
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
        AiAnalysisBackgroundBridge.serviceActive = false
        super.onDestroy()
        // Removing the foreground notification also removes the shared ID's
        // final state; restore it (no-op while an attempt is still running).
        AiAnalysisBackgroundBridge.notice?.let { AiAnalysisBackgroundBridge.serviceStopped(this, it.id) }
    }
}

/**
 * User-initiated data transfer job (Android 14+). The Flutter engine performs
 * the transfer; this job keeps the process eligible to run while backgrounded
 * and owns the progress notification for the attempt it was scheduled for.
 */
@RequiresApi(34)
class AiAnalysisTransferJobService : JobService() {
    private val handler = Handler(Looper.getMainLooper())
    private var params: JobParameters? = null
    private var id: String? = null
    private val timeout = Runnable { id?.let { AiAnalysisBackgroundBridge.expire(this, it) } }

    override fun onStartJob(params: JobParameters): Boolean {
        val state = AiAnalysisBackgroundBridge.notice
            ?.takeIf { it.outcome == null && it.id == params.extras.getString("id") }
        // A user-initiated job must provide its notification as soon as it starts.
        val notification = state?.let { AiAnalysisBackgroundBridge.notification(this, it) }
            ?: AiAnalysisBackgroundBridge.placeholder(this)
        setNotification(params, AiAnalysisBackgroundBridge.JOB_NOTIFICATION_ID, notification,
            JOB_END_NOTIFICATION_POLICY_REMOVE)
        // The attempt finished or was replaced before the job started.
        if (state == null) return false
        this.params = params
        id = state.id
        AiAnalysisBackgroundBridge.activeJob = this
        // Same bounded lifetime as the foreground-service path.
        handler.postDelayed(timeout, 6 * 60 * 1000L)
        return true
    }

    /** Called by the bridge when the attempt ends; jobFinished removes the job notification. */
    fun complete() {
        val current = params ?: return
        release()
        jobFinished(current, false)
    }

    override fun onStopJob(params: JobParameters): Boolean {
        // System or user stop (e.g. network loss, Task Manager). Treated like
        // expiry; a no-op when the attempt already finished or was replaced.
        val stopped = id
        release()
        stopped?.let { AiAnalysisBackgroundBridge.expire(this, it) }
        return false
    }

    private fun release() {
        handler.removeCallbacks(timeout)
        if (AiAnalysisBackgroundBridge.activeJob === this) AiAnalysisBackgroundBridge.activeJob = null
        params = null
        id = null
    }
}

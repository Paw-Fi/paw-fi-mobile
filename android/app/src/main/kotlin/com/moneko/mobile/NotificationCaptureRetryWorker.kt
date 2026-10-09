package com.moneko.mobile

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

/** Request bodies stay in encrypted storage, never in WorkManager input data. */
class NotificationCaptureRetryWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    override fun doWork(): Result {
        return try {
            val config = NotificationCaptureConfig(applicationContext)
            val recordId = inputData.getString("captureId") ?: return Result.success()
            val record = config.getPendingCaptures().firstOrNull { it["id"] == recordId }
                ?: return Result.success()
            val userId = record["userId"] as? String ?: return Result.success()
            if (isStopped || config.userId != userId) return Result.success()
            val result = NotificationCaptureDispatcher.drain(config, userId, recordId)
            if (result["remaining"] == 0) Result.success() else Result.retry()
        } catch (_: Exception) {
            Result.retry()
        }
    }
}

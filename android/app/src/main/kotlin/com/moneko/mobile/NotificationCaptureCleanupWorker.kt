package com.moneko.mobile

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

class NotificationCaptureCleanupWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {

    override fun doWork(): Result = try {
        NotificationCaptureConfig(applicationContext).pruneExpiredPendingCaptures()
        Result.success()
    } catch (_: Exception) {
        Result.retry()
    }
}

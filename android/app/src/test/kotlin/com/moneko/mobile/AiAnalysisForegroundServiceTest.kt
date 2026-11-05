package com.moneko.mobile

import android.app.Application
import android.app.Notification
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Looper
import android.os.Build
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], application = Application::class)
class AiAnalysisForegroundServiceTest {
    private val context get() = RuntimeEnvironment.getApplication()
    private val messages = mapOf("title" to "Moneko", "channel" to "Analysis", "analyzing" to "Analyzing",
        "saving" to "Preparing", "paused" to "Open to continue", "needsInput" to "Open to answer", "queued" to "Queued to sync")

    @After fun clear() {
        AiAnalysisBackgroundBridge.notice = null
        context.getSharedPreferences("ai_analysis_stops", 0).edit().clear().commit()
        context.getSharedPreferences("ai_analysis_errors", 0).edit().clear().commit()
    }

    @Test fun stopActionPersistsBeforeEngineDeliveryAndSurvivesBridgeDetach() {
        val state = AiAnalysisNotice("attempt", messages + ("stop" to "Stop"), true,
            userId = "owner", captureId = "capture")
        AiAnalysisBackgroundBridge.notice = state
        val action = AiAnalysisBackgroundBridge.notification(context, state).actions.single()
        assertEquals("Stop", action.title)
        action.actionIntent.send()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals("cancelled", state.outcome)
        AiAnalysisBackgroundBridge.detach(context)
        assertEquals(listOf(mapOf("id" to "attempt", "userId" to "owner", "captureId" to "capture")),
            AiAnalysisBackgroundBridge.pendingStops(context))
        AiAnalysisBackgroundBridge.acknowledgeStop(context, "attempt")
        assertTrue(AiAnalysisBackgroundBridge.pendingStops(context).isEmpty())
    }

    @Test fun staleStopCannotEndNewerNativeAttemptOrEraseAnotherJournalRecord() {
        val state = AiAnalysisNotice("new", messages, true, userId = "owner", captureId = "capture")
        AiAnalysisBackgroundBridge.notice = state
        AiAnalysisBackgroundBridge.stop(context, "old", "capture", "owner")
        assertNull(state.outcome)
        AiAnalysisBackgroundBridge.stop(context, "another", "other-capture", "owner")
        AiAnalysisBackgroundBridge.acknowledgeStop(context, "old")
        assertEquals("another", AiAnalysisBackgroundBridge.pendingStops(context).single()["id"])
    }

    @Test fun activeNotificationIsOngoingIndeterminateAndContainsNoFinancialSource() {
        val state = AiAnalysisNotice("capture:attempt", messages, true)
        val notification = AiAnalysisBackgroundBridge.notification(context, state)
        assertTrue(notification.flags and Notification.FLAG_ONGOING_EVENT != 0)
        assertTrue(notification.extras.getBoolean(Notification.EXTRA_PROGRESS_INDETERMINATE))
        assertEquals("Analyzing", notification.extras.getCharSequence(Notification.EXTRA_TEXT).toString())
        assertNotNull(notification.contentIntent)
        state.outcome = "needsInput"
        val attention = AiAnalysisBackgroundBridge.notification(context, state)
        assertEquals(0, attention.flags and Notification.FLAG_ONGOING_EVENT)
        assertEquals("Open to answer", attention.extras.getCharSequence(Notification.EXTRA_TEXT).toString())
    }

    @Test fun staleExpirationCannotStopANewerAttempt() {
        val next = AiAnalysisNotice("new", messages, true)
        AiAnalysisBackgroundBridge.notice = next
        AiAnalysisBackgroundBridge.expire(context, "old")
        assertNull(next.outcome)
        AiAnalysisBackgroundBridge.expire(context, "new")
        assertEquals("error", next.outcome)
    }

    @Test fun successHasFiveSecondTimeoutWhileErrorsAndConfirmationRemainActionable() {
        for (outcome in listOf("queued", "review", "error", "paused", "needsInput")) {
            val state = AiAnalysisNotice("capture:attempt", messages + mapOf(
                "error" to "Open Moneko to retry or cancel", "confirmationTitle" to "Confirmation required",
                "errorTitle" to "Analysis failed", "successTitle" to "Analysis complete"), true,
                outcome = outcome, userId = "owner", captureId = "capture")
            val notification = AiAnalysisBackgroundBridge.notification(context, state)
            val success = outcome == "queued" || outcome == "review"
            assertEquals(if (success) 5000L else 0L, notification.timeoutAfter)
            assertFalse(notification.extras.getBoolean(Notification.EXTRA_PROGRESS_INDETERMINATE))
            assertEquals(success, notification.flags and Notification.FLAG_AUTO_CANCEL != 0)
            val launch = shadowOf(notification.contentIntent).savedIntent
            assertEquals("moneko", launch.data?.scheme)
            assertEquals("ai-analysis", launch.data?.host)
            assertEquals("capture", launch.data?.getQueryParameter("captureId"))
            if (outcome == "needsInput") assertEquals("Confirmation required", notification.extras.getString(Notification.EXTRA_TITLE))
            if (outcome == "error" || outcome == "paused") assertEquals("Analysis failed", notification.extras.getString(Notification.EXTRA_TITLE))
        }
    }

    @Test fun expiryJournalsAnErrorBeforeTheEngineCanResumeAndStopClearsIt() {
        val state = AiAnalysisNotice("attempt", messages, true, userId = "owner", captureId = "capture")
        AiAnalysisBackgroundBridge.notice = state
        AiAnalysisBackgroundBridge.expire(context, state.id)
        assertEquals(listOf(mapOf("id" to "attempt", "userId" to "owner", "captureId" to "capture")),
            AiAnalysisBackgroundBridge.pendingFailures(context))
        AiAnalysisBackgroundBridge.stop(context, state.id, state.captureId, state.userId)
        assertTrue(AiAnalysisBackgroundBridge.pendingFailures(context).isEmpty())
    }

    @Test fun staleStartIntentCannotStopANewerRunningAttempt() {
        val current = AiAnalysisNotice("new-attempt", messages, true)
        AiAnalysisBackgroundBridge.notice = current
        val controller = Robolectric.buildService(AiAnalysisForegroundService::class.java).create()
        val service = controller.get()
        service.onStartCommand(Intent().putExtra("id", current.id), 0, 2)
        service.onStartCommand(Intent().putExtra("id", "old-attempt"), 0, 1)
        assertFalse(shadowOf(service).isStoppedBySelf)
        assertNull(current.outcome)
        controller.destroy()
    }

    @Test fun boundedExecutionExpiresWithoutRestartingOrClaimingCompletion() {
        val state = AiAnalysisNotice("capture", messages, true)
        AiAnalysisBackgroundBridge.notice = state
        val controller = Robolectric.buildService(AiAnalysisForegroundService::class.java).create()
        val service = controller.get()
        service.onStartCommand(Intent().putExtra("id", state.id), 0, 1)
        assertNotNull(shadowOf(service).lastForegroundNotification)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(6))
        assertEquals("error", state.outcome)
        controller.destroy()
    }

    @Test fun manifestServiceIsPrivateAndDeclaresDataSync() {
        val info = context.packageManager.getServiceInfo(ComponentName(context, AiAnalysisForegroundService::class.java), 0)
        assertFalse(info.exported)
        if (Build.VERSION.SDK_INT >= 29) {
            assertEquals(ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC, info.foregroundServiceType)
        }
    }
}

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

    @After fun clear() { AiAnalysisBackgroundBridge.notice = null }

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
        assertEquals("paused", next.outcome)
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
        assertEquals("paused", state.outcome)
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

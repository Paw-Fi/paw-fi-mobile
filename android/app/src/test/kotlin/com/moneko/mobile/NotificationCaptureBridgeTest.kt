package com.moneko.mobile

import android.app.Application
import android.content.Intent
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.nio.ByteBuffer

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class NotificationCaptureBridgeTest {
    private val context get() = RuntimeEnvironment.getApplication()
    private val messenger = CaptureMessenger()
    private val gate = NotificationCaptureForegroundGate()

    @After fun clearCallback() {
        NotificationCaptureDispatcher.onCaptured = null
    }

    @Test fun channelDefersForegroundReplyAndKeepsItsHandlerAfterReadiness() {
        NotificationCaptureBridge(context, messenger, gate)
        var replies = 0
        messenger.call("awaitForegroundHost") { value ->
            assertEquals(true, value)
            replies++
        }
        assertEquals(0, replies)
        gate.markReady()
        gate.markReady()
        assertEquals(1, replies)
        messenger.call("awaitForegroundHost") { replies++ }
        assertEquals(2, replies)
        assertEquals(1, messenger.registrations)
    }

    @Test fun settingsLaunchIsExplicitAndUsesApplicationNewTask() {
        NotificationCaptureBridge(context, messenger, gate)
        assertNull(shadowOf(context).nextStartedActivity)
        messenger.call("openNotificationSettings") { assertEquals(true, it) }
        val intent = shadowOf(context).nextStartedActivity
        assertEquals(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS, intent.action)
        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
    }

    @Test fun sessionRequestEndpointDoesNotReplaceTheCaptureHandler() {
        NotificationCaptureBridge(context, messenger, gate)
        val sessionEndpoint = MethodChannel(messenger, "moneko/notification_capture")
        sessionEndpoint.invokeMethod("getCurrentSessionForNotificationCapture",
            mapOf("userId" to "owner", "forceRefresh" to true))
        assertEquals("getCurrentSessionForNotificationCapture", messenger.outgoing.single().method)
        assertEquals(mapOf("userId" to "owner", "forceRefresh" to true),
            messenger.outgoing.single().arguments)
        gate.markReady()
        var replies = 0
        messenger.call("awaitForegroundHost") { replies++ }
        assertEquals(1, replies)
        assertEquals(1, messenger.registrations)
    }

    @Test fun captureCallbacksContinueWithoutAnyActivityAndUseMainMessenger() {
        NotificationCaptureBridge(context, messenger, gate)
        val worker = Thread { NotificationCaptureDispatcher.onCaptured?.invoke("owner", 42L) }
        worker.start()
        worker.join()
        shadowOf(Looper.getMainLooper()).idle()
        val call = messenger.outgoing.single()
        assertEquals("capturesChanged", call.method)
        assertEquals(mapOf("userId" to "owner", "revision" to 42L), call.arguments)
        gate.markReady()
        NotificationCaptureDispatcher.onCaptured?.invoke("owner", 43L)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(2, messenger.outgoing.size)
    }

    @Test fun configHandlersKeepTheirExistingContractWithoutAnActivity() {
        NotificationCaptureBridge(context, messenger, gate)
        messenger.call("setConfig", mapOf("enabled" to true, "scopeId" to "space",
            "accountId" to "wallet", "accountCurrency" to "EUR")) { assertEquals(true, it) }
        messenger.call("getConfig") { value ->
            val config = value as Map<*, *>
            assertEquals(true, config["enabled"])
            assertEquals("space", config["scopeId"])
            assertEquals("wallet", config["accountId"])
            assertEquals("EUR", config["accountCurrency"])
            assertEquals(false, config["hasNotificationAccess"])
        }
    }

    private class CaptureMessenger : BinaryMessenger {
        private val codec = StandardMethodCodec.INSTANCE
        private var handler: BinaryMessenger.BinaryMessageHandler? = null
        var registrations = 0
        val outgoing = mutableListOf<MethodCall>()

        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            assertEquals("moneko/notification_capture", channel)
            registrations++
            this.handler = handler
        }

        override fun send(channel: String, message: ByteBuffer?) = send(channel, message, null)

        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
            assertSame(Looper.getMainLooper(), Looper.myLooper())
            assertEquals("moneko/notification_capture", channel)
            outgoing.add(codec.decodeMethodCall(readable(requireNotNull(message))))
        }

        fun call(method: String, arguments: Any? = null, reply: (Any?) -> Unit) {
            val message = readable(codec.encodeMethodCall(MethodCall(method, arguments)))
            requireNotNull(handler).onMessage(message) { response ->
                reply(response?.let { codec.decodeEnvelope(readable(it)) })
            }
        }

        private fun readable(buffer: ByteBuffer): ByteBuffer = buffer.duplicate().apply { flip() }
    }
}

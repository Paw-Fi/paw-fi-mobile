package com.moneko.mobile

import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test

class NotificationCaptureSessionRequestTest {
    private val scheduled = mutableListOf<Pair<Long, () -> Unit>>()
    private val replies = mutableListOf<MethodChannel.Result>()
    private val results = mutableListOf<Map<*, *>?>()
    private var active = true
    private val request = NotificationCaptureSessionRequest(
        invoke = { replies.add(it) },
        schedule = { delay, task -> scheduled.add(delay to task) },
        isActive = { active },
        completion = { results.add(it) },
    )

    @Test
    fun coldDartHandlerRetriesUntilReadyThenCompletesOnlyOnce() {
        request.start()
        replies.single().notImplemented()
        scheduled.single { it.first == 200L }.second()
        assertEquals(2, replies.size)
        val credentials = mapOf("userId" to "actor", "accessToken" to "token", "expiresAt" to 123L)
        replies.last().success(credentials)
        scheduled.single { it.first == 12_000L }.second()
        assertEquals(listOf(credentials), results)
    }

    @Test
    fun expiredDeadlineRejectsLateReplyAndStopsStartupRetries() {
        request.start()
        replies.single().notImplemented()
        scheduled.single { it.first == 12_000L }.second()
        scheduled.single { it.first == 200L }.second()
        replies.single().success(mapOf("accessToken" to "late"))
        assertEquals(1, replies.size)
        assertEquals(listOf(null), results)
    }

    @Test
    fun accountChangeOrWorkerCancellationDiscardsPendingSessionReply() {
        request.start()
        active = false
        replies.single().success(mapOf("accessToken" to "old-actor-token"))
        assertEquals(listOf(null), results)
    }

    @Test
    fun authAndNetworkErrorsDoNotRetryInsideTheRequest() {
        request.start()
        replies.single().error("capture_session_unavailable", "", null)
        scheduled.single().second()
        assertEquals(listOf(null), results)
        assertEquals(1, replies.size)
    }

    @Test
    fun malformedSuccessDoesNotSupplyCredentials() {
        request.start()
        replies.single().success("not credentials")
        assertEquals(listOf(null), results)
    }
}

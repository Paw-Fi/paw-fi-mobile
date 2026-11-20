package com.moneko.mobile

import android.content.Context
import org.robolectric.RuntimeEnvironment
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class NotificationCaptureDispatcherTest {
    private lateinit var config: NotificationCaptureConfig
    private val sent = mutableListOf<String>()
    private val requests = mutableListOf<String>()
    private val refreshes = mutableListOf<Boolean>()

    @Before
    fun setUp() {
        val context = RuntimeEnvironment.getApplication()
        val storage = context.getSharedPreferences("capture-test", Context.MODE_PRIVATE)
        storage.edit().clear().commit()
        config = NotificationCaptureConfig(context, storage)
        signIn("expired", -60)
        assertTrue(config.enqueuePendingCapture(JSONObject().apply {
            put("userId", "actor-1")
            put("idempotencyKey", "original-event")
            put("notification", JSONObject().put("text", "تم استلام ١٠ ر.س من أحمد"))
        }, "original-event"))
    }

    private fun signIn(token: String, remainingSeconds: Long, userId: String = "actor-1") {
        config.syncAuthContext("https://example.test", "anon", token, userId,
            System.currentTimeMillis() / 1000 + remainingSeconds)
    }

    private fun recover(config: NotificationCaptureConfig, userId: String, force: Boolean): String? {
        refreshes.add(force)
        assertTrue(config.updateAccessTokenForUser(userId, config.authGeneration,
            "fresh", System.currentTimeMillis() / 1000 + 3600))
        return config.accessTokenForUser(userId)
    }

    private fun send(url: String, key: String, token: String, body: JSONObject): Pair<Int, String> {
        assertEquals("https://example.test", url)
        assertEquals("anon", key)
        sent.add(token)
        requests.add(body.toString())
        return 200 to """{"success":true,"data":{"id":"saved-row"}}"""
    }

    @Test
    fun expiredSessionSavesWithoutActivityOrForegroundReplay() {
        val original = config.getPendingCaptures().single()["body"]
        val result = NotificationCaptureDispatcher.drain(config, "actor-1",
            recoverAccessToken = ::recover, sendRequest = ::send)
        assertEquals(listOf(false), refreshes)
        assertEquals(listOf("fresh"), sent)
        assertEquals(listOf(original), requests)
        assertEquals(1, result["synced"])
        assertEquals(0, result["remaining"])
        assertEquals(1L, config.captureRevision)
    }

    @Test
    fun usableTokenDoesNotBootFlutter() {
        signIn("valid", 3600)
        NotificationCaptureDispatcher.drain(config, "actor-1",
            recoverAccessToken = { _, _, _ -> error("Must not start auth runtime") },
            sendRequest = ::send)
        assertEquals(listOf("valid"), sent)
    }

    @Test
    fun serverRejectionRefreshesOnceAndRetriesTheExactRequest() {
        signIn("rejected", 3600)
        NotificationCaptureDispatcher.drain(config, "actor-1",
            recoverAccessToken = ::recover,
            sendRequest = { url, key, token, body ->
                val response = send(url, key, token, body)
                if (sent.size == 1) 401 to "{}" else response
            })
        assertEquals(listOf(true), refreshes)
        assertEquals(listOf("rejected", "fresh"), sent)
        assertEquals(requests.first(), requests.last())
        assertTrue(config.getPendingCaptures().isEmpty())
    }

    @Test
    fun repeated401RemainsQueuedWithoutRefreshLoop() {
        val result = NotificationCaptureDispatcher.drain(config, "actor-1",
            recoverAccessToken = ::recover,
            sendRequest = { url, key, token, body -> send(url, key, token, body); 401 to "{}" })
        assertEquals(listOf(false, true), refreshes)
        assertEquals(2, sent.size)
        assertEquals(1, result["remaining"])
        assertEquals(true, result["requiresSessionRefresh"])
        assertEquals(0L, config.captureRevision)
    }

    @Test
    fun offlineSessionRecoveryRetainsOriginalRecordForLaterRetry() {
        val before = config.getPendingCaptures()
        NotificationCaptureDispatcher.drain(config, "actor-1",
            recoverAccessToken = { _, _, _ -> null }, sendRequest = ::send)
        assertEquals(before, config.getPendingCaptures())
        assertTrue(sent.isEmpty())
        NotificationCaptureDispatcher.drain(config, "actor-1",
            recoverAccessToken = ::recover, sendRequest = ::send)
        assertTrue(config.getPendingCaptures().isEmpty())
    }

    @Test
    fun accountSwitchDuringRecoveryCannotDispatchOrRestoreOldCredentials() {
        val generation = config.authGeneration
        NotificationCaptureDispatcher.drain(config, "actor-1",
            recoverAccessToken = { _, _, _ ->
                signIn("other", 3600, "actor-2")
                assertFalse(config.updateAccessTokenForUser("actor-1", generation,
                    "stale", System.currentTimeMillis() / 1000 + 3600))
                "stale"
            }, sendRequest = ::send)
        assertTrue(sent.isEmpty())
        assertEquals("other", config.accessToken)
    }

    @Test
    fun logoutAndSameAccountLoginInvalidateTheOldGeneration() {
        val generation = config.authGeneration
        NotificationCaptureDispatcher.drain(config, "actor-1",
            recoverAccessToken = { _, _, _ ->
                config.clearAuthContext()
                signIn("new-login", 3600)
                assertFalse(config.updateAccessTokenForUser("actor-1", generation,
                    "stale", System.currentTimeMillis() / 1000 + 3600))
                "stale"
            }, sendRequest = ::send)
        assertTrue(sent.isEmpty())
        assertEquals("new-login", config.accessToken)
    }

    @Test
    fun stoppedWorkerCannotSendAfterSessionRecovery() {
        var stopped = false
        NotificationCaptureDispatcher.drain(config, "actor-1",
            recoverAccessToken = { cfg, actor, force ->
                recover(cfg, actor, force).also { stopped = true }
            }, sendRequest = ::send, isStopped = { stopped })
        assertTrue(sent.isEmpty())
        assertEquals(1, config.getPendingCaptures().size)
    }

    @Test
    fun failedSessionTransitionRetainsQueuedCaptureForTheOriginalActor() {
        val before = config.getPendingCaptures()
        val generation = config.authGeneration
        config.suspendAuthContext()
        assertNull(config.accessTokenForUser("actor-1"))
        assertFalse(config.updateAccessTokenForUser("actor-1", generation,
            "late-token", System.currentTimeMillis() / 1000 + 3600))
        assertEquals(before, config.getPendingCaptures())
        signIn("same-actor", 3600)
        NotificationCaptureDispatcher.drain(config, "actor-1", sendRequest = ::send)
        assertEquals(listOf("same-actor"), sent)
        assertTrue(config.getPendingCaptures().isEmpty())
    }

    @Test
    fun transientAndMalformedResponsesRetainRecordsButTerminalRejectionRetiresThem() {
        signIn("valid", 3600)
        for (response in listOf(503 to "{}", 429 to "{}", 409 to "REQUEST_IN_PROGRESS",
                200 to "{\"success\":true}")) {
            NotificationCaptureDispatcher.drain(config, "actor-1",
                sendRequest = { _, _, _, _ -> response })
            assertEquals(1, config.getPendingCaptures().size)
        }
        NotificationCaptureDispatcher.drain(config, "actor-1",
            sendRequest = { _, _, _, _ -> 403 to "{}" })
        assertTrue(config.getPendingCaptures().isEmpty())
        assertEquals(0L, config.captureRevision)
    }
}

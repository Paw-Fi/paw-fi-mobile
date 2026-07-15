package com.moneko.mobile

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationCaptureCandidateTest {

    @Test
    fun sendsPricePromotionsToAiForSemanticRejection() {
        val content = NotificationCaptureCandidate.buildContent(
            title = "Weekend sale",
            text = "Save 50% on shoes now $49.99",
            bigText = null,
            subText = "Shop",
            textLines = emptyList(),
        )

        assertTrue(NotificationCaptureCandidate.shouldAnalyze(content))
    }

    @Test
    fun acceptsMultilingualMonetaryEvidence() {
        val content = NotificationCaptureCandidate.buildContent(
            title = "Remboursement confirmé",
            text = "Votre remboursement de 12,34€ a été effectué",
            bigText = null,
            subText = null,
            textLines = emptyList(),
        )

        assertTrue(NotificationCaptureCandidate.shouldAnalyze(content))
    }

    @Test
    fun acceptsEveryBackendSupportedCurrencyCode() {
        val content = NotificationCaptureCandidate.buildContent(
            title = "Payment completed",
            text = "BDT 1,250.00 paid to Dhaka Market",
            bigText = null,
            subText = null,
            textLines = emptyList(),
        )

        assertTrue(NotificationCaptureCandidate.shouldAnalyze(content))
    }

    @Test
    fun acceptsAlphabeticCurrencySymbolsOnlyAsStandaloneTokens() {
        assertTrue(NotificationCaptureCandidate.shouldAnalyze("Paid R 250.00 at Market"))
        assertTrue(NotificationCaptureCandidate.shouldAnalyze("Paid Q100.00 at Market"))
        assertFalse(NotificationCaptureCandidate.shouldAnalyze("Your order 100 arrives Friday"))
        assertFalse(NotificationCaptureCandidate.shouldAnalyze("Free trial for 100 days"))
    }

    @Test
    fun rejectsOrdinaryMessagesWithoutMoney() {
        val content = NotificationCaptureCandidate.buildContent(
            title = "Dinner tonight",
            text = "Are we still meeting at seven?",
            bigText = null,
            subText = null,
            textLines = emptyList(),
        )

        assertFalse(NotificationCaptureCandidate.shouldAnalyze(content))
    }

    @Test
    fun keepsSensitiveSecurityMessagesOnDevice() {
        val content = NotificationCaptureCandidate.buildContent(
            title = "Security code",
            text = "Your OTP is 123456. Do not share it. Purchase limit $500.00",
            bigText = null,
            subText = null,
            textLines = emptyList(),
        )

        assertFalse(NotificationCaptureCandidate.shouldAnalyze(content))
    }

    @Test
    fun includesDistinctExpandedNotificationFields() {
        val content = NotificationCaptureCandidate.buildContent(
            title = "Payment received",
            text = "Short preview",
            bigText = "You received USD 120.00 from Acme",
            subText = "Inbox",
            textLines = listOf("Invoice paid", "Short preview"),
        )

        assertTrue(content.contains("Payment received"))
        assertTrue(content.contains("You received USD 120.00 from Acme"))
        assertTrue(content.contains("Invoice paid"))
        assertTrue(content.split("Short preview").size - 1 == 1)
    }

    @Test
    fun expiresPendingNotificationContentAfterRetentionWindow() {
        val queuedAt = 1_000L
        val justBeforeExpiry = queuedAt + NotificationCaptureConfig.PENDING_CAPTURE_TTL_MS - 1
        val atExpiry = queuedAt + NotificationCaptureConfig.PENDING_CAPTURE_TTL_MS

        assertFalse(NotificationCaptureConfig.isPendingCaptureExpired(queuedAt, justBeforeExpiry))
        assertTrue(NotificationCaptureConfig.isPendingCaptureExpired(queuedAt, atExpiry))
    }
}

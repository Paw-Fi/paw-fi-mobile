package com.moneko.mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class NotificationTransactionParserTest {

    @Test
    fun parsesStandardUsdNotification() {
        val parsed = NotificationTransactionParser.parse(
            "Payment alert",
            "Card charged at Starbucks for $5.45",
            null,
        )

        assertNotNull(parsed)
        assertEquals("USD", parsed!!.currencyCode)
        assertEquals(5.45, parsed.amount, 0.001)
    }

    @Test
    fun parsesEuropeanAmountFormat() {
        val parsed = NotificationTransactionParser.parse(
            "Paiement",
            "Paiement chez Carrefour pour 12,34€",
            null,
        )

        assertNotNull(parsed)
        assertEquals("EUR", parsed!!.currencyCode)
        assertEquals(12.34, parsed.amount, 0.001)
    }

    @Test
    fun rejectsOtpNotifications() {
        val parsed = NotificationTransactionParser.parse(
            "Security Code",
            "Your OTP is 123456 for card verification",
            null,
        )

        assertNull(parsed)
    }
}

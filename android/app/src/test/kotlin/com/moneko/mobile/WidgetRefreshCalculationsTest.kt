package com.moneko.mobile

import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.*
import org.junit.Test

class WidgetRefreshCalculationsTest {
    @Test fun timezonePreferenceSupportsDeviceTravelIanaAndFixedOffsets() {
        val device = ZoneId.of("Asia/Tokyo")
        assertEquals(device, WidgetRefreshCalculations.resolveZone(null, 60, device))
        assertEquals(device, WidgetRefreshCalculations.resolveZone("", 60, device))
        assertEquals(ZoneId.of("America/New_York"), WidgetRefreshCalculations.resolveZone("America/New_York", 60, device))
        assertEquals(28800, WidgetRefreshCalculations.resolveZone("UTC+08:00", 480, device).rules.getOffset(java.time.Instant.EPOCH).totalSeconds)
    }

    @Test fun financialCycleClampsShortMonthsAndUsesPreviousMonth() {
        assertEquals(LocalDate.parse("2026-02-28"), WidgetRefreshCalculations.cycleStart(LocalDate.parse("2026-03-01"), 31))
        assertEquals(LocalDate.parse("2026-06-25"), WidgetRefreshCalculations.cycleStart(LocalDate.parse("2026-07-09"), 25))
        assertEquals(LocalDate.parse("2028-02-29"), WidgetRefreshCalculations.cycleStart(LocalDate.parse("2028-02-29"), 31))
        assertEquals(LocalDate.parse("2026-03-01"), WidgetRefreshCalculations.cycleStart(LocalDate.parse("2026-03-10"), 0))
    }

    @Test fun convertsAggregateBudgetsAndSpendingBeforeSumming() {
        val result = WidgetRefreshCalculations.aggregate(listOf(
            WidgetCurrencyTotals("EUR", 1000.0, 100000.0),
            WidgetCurrencyTotals("USD", 20000.0, 10000.0)
        ), "EUR", mapOf("USD" to 1.0, "EUR" to 0.85))
        assertEquals(180.0, result.first, 0.00001)
        assertEquals(1085.0, result.second, 0.00001)
    }

    @Test fun zeroBudgetDoesNotEraseSpend() {
        assertEquals(24.5 to 0.0, WidgetRefreshCalculations.aggregate(
            listOf(WidgetCurrencyTotals("USD", 2450.0, 0.0)), "USD", emptyMap()))
    }

    @Test fun missingRatesAndNonFiniteMoneyFailWithoutPublishingZero() {
        assertThrows(IllegalStateException::class.java) {
            WidgetRefreshCalculations.aggregate(listOf(WidgetCurrencyTotals("EUR", 100.0, 0.0)), "USD", emptyMap())
        }
        assertThrows(IllegalArgumentException::class.java) {
            WidgetRefreshCalculations.aggregate(listOf(WidgetCurrencyTotals("USD", Double.NaN, 0.0)), "USD", emptyMap())
        }
    }
}

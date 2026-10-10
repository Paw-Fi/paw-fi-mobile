package com.moneko.mobile

import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

data class WidgetCurrencyTotals(val currency: String, val spentCents: Double, val budgetCents: Double)

object WidgetRefreshCalculations {
    fun resolveZone(preferred: String?, fallbackOffsetMinutes: Int, deviceZone: ZoneId = ZoneId.systemDefault()): ZoneId {
        if (preferred.isNullOrBlank() || preferred == "null") return deviceZone
        return runCatching { ZoneId.of(preferred) }
            .getOrElse { ZoneOffset.ofTotalSeconds(fallbackOffsetMinutes * 60) }
    }

    fun cycleStart(today: LocalDate, startDay: Int): LocalDate {
        val day = startDay.takeIf { it in 1..31 } ?: 1
        val thisStart = today.withDayOfMonth(day.coerceAtMost(today.lengthOfMonth()))
        if (!today.isBefore(thisStart)) return thisStart
        val previous = today.minusMonths(1)
        return previous.withDayOfMonth(day.coerceAtMost(previous.lengthOfMonth()))
    }

    fun aggregate(rows: List<WidgetCurrencyTotals>, displayCurrency: String, rates: Map<String, Double>): Pair<Double, Double> {
        fun convert(cents: Double, source: String): Double {
            require(cents.isFinite())
            if (source == displayCurrency) return cents / 100.0
            val from = rates[source] ?: error("Missing source currency rate")
            val to = rates[displayCurrency] ?: error("Missing display currency rate")
            require(from.isFinite() && to.isFinite() && from > 0 && to > 0)
            return cents / 100.0 / from * to
        }
        val result = rows.sumOf { convert(it.spentCents, it.currency) } to
            rows.sumOf { convert(it.budgetCents, it.currency) }
        require(result.first.isFinite() && result.second.isFinite())
        return result
    }
}

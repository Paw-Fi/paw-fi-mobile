package com.moneko.mobile

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

data class ParsedTransaction(
    val merchantName: String?,
    val amount: Double,
    val currencyCode: String,
    val transactionDate: String,
    val confidence: Float,
    val rawText: String
)

/**
 * Stateless parser that extracts structured transaction data from notification text.
 *
 * Design principles:
 * - Favour precision over recall (reject ambiguous notifications rather than create false positives)
 * - Normalise currency symbols to ISO 4217 codes
 * - Handle international decimal/thousands separators
 * - No Android framework dependencies — pure Kotlin for testability
 */
object NotificationTransactionParser {

    /** Minimum confidence required to consider a parse result actionable. */
    const val MIN_CONFIDENCE = 0.7f

    // ── Currency symbol → ISO mapping ────────────────────────────────────
    private val MULTI_CHAR_CURRENCY_PREFIXES = listOf(
        "HK$" to "HKD", "NZ$" to "NZD", "A$" to "AUD",
        "C$" to "CAD", "S$" to "SGD", "R$" to "BRL",
        "RM" to "MYR", "Kč" to "CZK"
    )

    private val SYMBOL_TO_ISO = mapOf(
        "$" to "USD", "€" to "EUR", "£" to "GBP",
        "¥" to "JPY", "₹" to "INR", "₩" to "KRW",
        "฿" to "THB", "₫" to "VND", "₱" to "PHP",
        "zł" to "PLN", "Ft" to "HUF", "₴" to "UAH",
        "₺" to "TRY", "kr" to "SEK", "lei" to "RON",
        "CHF" to "CHF"
    )

    /** All known 3-letter ISO codes we accept. */
    private val ISO_CODES = setOf(
        "USD", "EUR", "GBP", "JPY", "CNY", "INR", "KRW", "THB",
        "VND", "PHP", "BRL", "MYR", "SGD", "HKD", "AUD", "CAD",
        "NZD", "SEK", "NOK", "DKK", "PLN", "HUF", "CZK", "CHF",
        "RON", "UAH", "TRY", "IDR", "ZAR", "AED", "SAR", "QAR",
        "KWD", "BHD", "OMR", "EGP", "NGN", "KES", "GHS", "MAD",
        "CLP", "COP", "PEN", "ARS", "MXN", "TWD", "ILS", "RUB"
    )

    // ── Transaction signal keywords ──────────────────────────────────────
    private val TRANSACTION_KEYWORDS = listOf(
        "payment", "purchase", "debit", "debited", "charged",
        "spent", "transaction", "withdrawal", "transfer",
        "paid", "bought", "order", "receipt", "billing",
        "charge", "sale", "pos", "ecom", "online",
        // Common non-English equivalents
        "pagamento", "compra", "pago", "achat", "zahlung",
        "pembayaran", "transaksi"
    )

    // ── Merchant extraction patterns (order matters — first match wins) ─
    private val MERCHANT_PATTERNS = listOf(
        Regex("""(?:at|@)\s+(.+?)(?:\s+(?:for|on|with|card|ending)\b|\.\s|$)""", RegexOption.IGNORE_CASE),
        Regex("""(?:to|from)\s+(.+?)(?:\s+(?:for|on|with|card|ending|of|amount)\b|\.\s|$)""", RegexOption.IGNORE_CASE),
        Regex("""(?:merchant|payee|vendor)[:\s]+(.+?)(?:\s+(?:for|on|with|card|amount)\b|\.\s|$)""", RegexOption.IGNORE_CASE),
        Regex("""(?:at|chez|en|bei|di)\s+(.+?)(?:\.\s|$)""", RegexOption.IGNORE_CASE)
    )

    // ── Amount regex ─────────────────────────────────────────────────────
    // Matches: 1234.56 | 1,234.56 | 1.234,56 | 1234,56 | 1'234.56
    private val AMOUNT_PATTERN = Regex(
        """(\d{1,3}(?:[',.\s]\d{3})*(?:[.,]\d{1,2})?)"""
    )

    // ── ISO date in notification (rare but supported) ────────────────────
    private val DATE_PATTERN = Regex(
        """(\d{4}-\d{2}-\d{2}|\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})"""
    )

    // ── Rejection patterns (non-transaction notifications) ───────────────
    private val REJECTION_PATTERNS = listOf(
        Regex("""(?:OTP|otp|one.time.password|verification.code|security.code)"""),
        Regex("""(?:balance|available|remaining)\s*(?:is|:)\s""", RegexOption.IGNORE_CASE),
        Regex("""(?:reminder|due\s+date|bill\s+due|pay\s+by)""", RegexOption.IGNORE_CASE),
        Regex("""(?:credit(?:ed)?|received|refund)""", RegexOption.IGNORE_CASE),
        Regex("""(?:promo|offer|cashback|reward|coupon|discount)""", RegexOption.IGNORE_CASE),
        Regex("""(?:login|log\s*in|sign\s*in|password|reset)""", RegexOption.IGNORE_CASE)
    )

    /**
     * Attempt to parse a notification into a structured transaction.
     *
     * @param title  Notification title (may be null)
     * @param text   Notification body text (primary)
     * @param bigText  Expanded notification text (may be null)
     * @return parsed transaction or null if confidence is below threshold
     */
    fun parse(title: String?, text: String?, bigText: String?): ParsedTransaction? {
        val combined = buildString {
            title?.let { append(it); append(" ") }
            // Prefer bigText as it usually has more detail
            val body = if (!bigText.isNullOrBlank()) bigText else text
            body?.let { append(it) }
        }.trim()

        if (combined.length < 5) return null

        // Reject non-transaction notifications
        if (REJECTION_PATTERNS.any { it.containsMatchIn(combined) }) return null

        // Check for transaction signal words
        val hasTransactionKeyword = TRANSACTION_KEYWORDS.any { keyword ->
            combined.contains(keyword, ignoreCase = true)
        }

        // Extract currency + amount
        val currencyAmount = extractCurrencyAndAmount(combined) ?: return null
        val (amount, currencyCode) = currencyAmount
        if (amount <= 0.0) return null

        // Extract merchant
        val merchant = extractMerchant(combined, currencyCode, amount)

        // Compute confidence
        var confidence = 0.0f
        confidence += 0.4f  // amount found
        confidence += 0.3f  // currency found (always present if we got here)
        if (merchant != null) confidence += 0.2f
        if (hasTransactionKeyword) confidence += 0.1f

        if (confidence < MIN_CONFIDENCE) return null

        // Date: try to extract from text, fall back to now
        val dateStr = extractDate(combined)

        return ParsedTransaction(
            merchantName = merchant,
            amount = amount,
            currencyCode = currencyCode,
            transactionDate = dateStr,
            confidence = confidence,
            rawText = combined
        )
    }

    // ── Internal helpers ─────────────────────────────────────────────────

    private data class CurrencyAmount(val amount: Double, val currencyCode: String)

    /**
     * Extracts currency and amount from text. Tries multi-char prefixes first,
     * then single-char symbols, then ISO codes near amounts.
     */
    private fun extractCurrencyAndAmount(text: String): CurrencyAmount? {
        // Strategy 1: multi-char currency prefix/suffix near an amount
        for ((symbol, iso) in MULTI_CHAR_CURRENCY_PREFIXES) {
            val result = findAmountNearSymbol(text, symbol, iso)
            if (result != null) return result
        }

        // Strategy 2: ISO code near an amount (e.g. "USD 45.99" or "45.99 USD")
        for (iso in ISO_CODES) {
            val pattern = Regex(
                """(?:$iso)\s*(\d{1,3}(?:[',.\s]\d{3})*(?:[.,]\d{1,2})?)""" +
                """|(\d{1,3}(?:[',.\s]\d{3})*(?:[.,]\d{1,2})?)\s*(?:$iso)""",
                RegexOption.IGNORE_CASE
            )
            val match = pattern.find(text)
            if (match != null) {
                val rawAmount = (match.groupValues[1].ifEmpty { null }
                    ?: match.groupValues[2].ifEmpty { null }) ?: continue
                val amount = normalizeAmount(rawAmount)
                if (amount != null && amount > 0.0) {
                    return CurrencyAmount(amount, iso)
                }
            }
        }

        // Strategy 3: single-char symbols
        for ((symbol, iso) in SYMBOL_TO_ISO) {
            val result = findAmountNearSymbol(text, symbol, iso)
            if (result != null) return result
        }

        return null
    }

    /**
     * Find an amount adjacent to a currency symbol (prefix or suffix).
     */
    private fun findAmountNearSymbol(
        text: String,
        symbol: String,
        iso: String
    ): CurrencyAmount? {
        val escaped = Regex.escape(symbol)
        // Prefix: symbol then amount (e.g. "$45.99")
        val prefixPattern = Regex(
            """$escaped\s*(\d{1,3}(?:[',.\s]\d{3})*(?:[.,]\d{1,2})?)"""
        )
        val prefixMatch = prefixPattern.find(text)
        if (prefixMatch != null) {
            val amount = normalizeAmount(prefixMatch.groupValues[1])
            if (amount != null && amount > 0.0) return CurrencyAmount(amount, iso)
        }

        // Suffix: amount then symbol (e.g. "45,99€")
        val suffixPattern = Regex(
            """(\d{1,3}(?:[',.\s]\d{3})*(?:[.,]\d{1,2})?)\s*$escaped"""
        )
        val suffixMatch = suffixPattern.find(text)
        if (suffixMatch != null) {
            val amount = normalizeAmount(suffixMatch.groupValues[1])
            if (amount != null && amount > 0.0) return CurrencyAmount(amount, iso)
        }

        return null
    }

    /**
     * Normalises a raw amount string to a Double, handling international formats:
     * - "1,234.56" → 1234.56 (US/UK)
     * - "1.234,56" → 1234.56 (EU)
     * - "1234,56"  → 1234.56 (EU no-thousands)
     * - "1'234.56" → 1234.56 (Swiss)
     * - "1234.5"   → 1234.5
     * - "1234"     → 1234.0
     */
    internal fun normalizeAmount(raw: String): Double? {
        if (raw.isBlank()) return null
        val cleaned = raw.replace("\\s".toRegex(), "")

        // Count dots and commas
        val dotCount = cleaned.count { it == '.' }
        val commaCount = cleaned.count { it == ',' }

        val normalized = when {
            // No separators or only one type
            dotCount == 0 && commaCount == 0 -> cleaned.replace("'", "")
            // "1,234.56" — comma is thousands, dot is decimal
            dotCount == 1 && commaCount >= 1 && cleaned.lastIndexOf('.') > cleaned.lastIndexOf(',') ->
                cleaned.replace(",", "").replace("'", "")
            // "1.234,56" — dot is thousands, comma is decimal
            commaCount == 1 && dotCount >= 1 && cleaned.lastIndexOf(',') > cleaned.lastIndexOf('.') ->
                cleaned.replace(".", "").replace(",", ".").replace("'", "")
            // "1234,56" — comma as decimal (no thousands separator)
            commaCount == 1 && dotCount == 0 -> {
                val parts = cleaned.split(",")
                if (parts.size == 2 && parts[1].length <= 2) {
                    cleaned.replace(",", ".")
                } else {
                    // Comma as thousands only (e.g. "1,234")
                    cleaned.replace(",", "")
                }
            }
            // "1234.56" — standard dot-decimal
            dotCount == 1 && commaCount == 0 -> cleaned.replace("'", "")
            // Multiple dots, no comma — dots are thousands (e.g. "1.234.567")
            dotCount > 1 && commaCount == 0 -> cleaned.replace(".", "").replace("'", "")
            // Multiple commas, no dot — commas are thousands
            commaCount > 1 && dotCount == 0 -> cleaned.replace(",", "").replace("'", "")
            // Fallback: strip everything except digits and last decimal separator
            else -> cleaned.replace("'", "").replace(",", "")
        }

        return try {
            val value = normalized.toDouble()
            if (value.isFinite() && value > 0.0 && value < 100_000_000.0) value else null
        } catch (_: NumberFormatException) {
            null
        }
    }

    /**
     * Tries to extract a merchant name from common notification patterns.
     */
    private fun extractMerchant(
        text: String,
        currencyCode: String,
        amount: Double
    ): String? {
        for (pattern in MERCHANT_PATTERNS) {
            val match = pattern.find(text)
            if (match != null) {
                val candidate = match.groupValues[1].trim()
                val cleaned = cleanMerchant(candidate)
                if (cleaned != null) return cleaned
            }
        }
        return null
    }

    /**
     * Cleans and validates a merchant name candidate.
     */
    private fun cleanMerchant(raw: String): String? {
        // Remove trailing punctuation and amounts
        var cleaned = raw
            .replace(Regex("""[.,;:!?]+$"""), "")
            .replace(Regex("""\s+"""), " ")
            .trim()

        // Reject if too short or too long
        if (cleaned.length < 2 || cleaned.length > 100) return null

        // Reject if it's purely numeric
        if (cleaned.all { it.isDigit() || it == '.' || it == ',' }) return null

        // Reject if it looks like a card number
        if (Regex("""\d{4}\s?\d{4}""").containsMatchIn(cleaned)) return null

        // Title-case normalisation: if all-upper, convert to title case
        if (cleaned == cleaned.uppercase(Locale.ROOT) && cleaned.length > 3) {
            cleaned = cleaned.lowercase(Locale.ROOT)
                .replaceFirstChar { it.titlecase(Locale.ROOT) }
        }

        return cleaned
    }

    /**
     * Extracts a date from the notification text or falls back to today.
     */
    private fun extractDate(text: String): String {
        val match = DATE_PATTERN.find(text)
        if (match != null) {
            // Try to parse and normalise to ISO
            val raw = match.groupValues[1]
            val parsed = tryParseDate(raw)
            if (parsed != null) return parsed
        }
        // Fallback: today in UTC
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        sdf.timeZone = TimeZone.getDefault()
        return sdf.format(Date())
    }

    private fun tryParseDate(raw: String): String? {
        val formats = listOf(
            "yyyy-MM-dd",
            "dd/MM/yyyy", "MM/dd/yyyy",
            "dd-MM-yyyy", "MM-dd-yyyy",
            "dd.MM.yyyy",
            "dd/MM/yy", "MM/dd/yy"
        )
        val outFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        outFormat.timeZone = TimeZone.getDefault()

        for (fmt in formats) {
            try {
                val sdf = SimpleDateFormat(fmt, Locale.US)
                sdf.isLenient = false
                sdf.timeZone = TimeZone.getDefault()
                val date = sdf.parse(raw) ?: continue
                return outFormat.format(date)
            } catch (_: Exception) {
                continue
            }
        }
        return null
    }
}

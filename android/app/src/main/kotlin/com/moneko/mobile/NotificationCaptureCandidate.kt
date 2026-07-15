package com.moneko.mobile

import java.security.MessageDigest

object NotificationCaptureCandidate {
    private const val MAX_FIELD_LENGTH = 2_000
    private const val MAX_CONTENT_LENGTH = 6_000

    private val SECURITY_PATTERN = Regex(
        """\b(?:otp|one[ -]?time password|verification code|security code|password reset|reset code|sign[ -]?in code|login code|authentication code)\b""",
        RegexOption.IGNORE_CASE,
    )

    private val SUPPORTED_CURRENCY_CODES = setOf(
        "AED", "ARS", "AUD", "BBD", "BDT", "BIF", "BND", "BRL", "BSD", "BZD",
        "CAD", "CDF", "CHF", "CLP", "CNY", "COP", "CRC", "CZK", "DJF", "DKK",
        "DOP", "DZD", "EGP", "ETB", "EUR", "FJD", "FKP", "GBP", "GHS", "GIP",
        "GNF", "GTQ", "GYD", "HKD", "HUF", "IDR", "ILS", "INR", "ISK", "JMD",
        "JOD", "JPY", "KES", "KPW", "KRW", "KYD", "LBP", "LKR", "LRD", "MMK",
        "MOP", "MUR", "MWK", "MXN", "MYR", "NAD", "NGN", "NOK", "NPR", "NZD",
        "PEN", "PHP", "PKR", "PLN", "PYG", "RON", "RSD", "RUB", "RWF", "SAR",
        "SCR", "SDG", "SEK", "SGD", "SHP", "SRD", "SSP", "SYP", "THB", "TRY",
        "TTD", "TWD", "UAH", "USD", "VND", "XAF", "XCD", "XOF", "XPF", "ZAR",
        "ZMW",
    )
    private val SUPPORTED_CURRENCY_SYMBOLS = setOf(
        "د.إ", "ARS\$", "A\$", "Bds\$", "৳", "Fr", "B\$", "BZ\$", "R\$", "C\$",
        "CHF", "CLP\$", "¥", "COP\$", "Kč", "kr", "RD\$", "د.ج", "E£", "Br",
        "€", "FJ\$", "£", "₵", "Q", "G\$", "HK\$", "Ft", "J\$", "Rp", "₪",
        "₹", "د.أ", "KSh", "₩", "CI\$", "ل.ل", "L\$", "Rs", "MOP\$", "Ks",
        "RM", "MK", "MX\$", "N\$", "₦", "रू", "NZ\$", "₱", "S/", "zł", "₨",
        "₲", "Дин.", "RON", "₽", "ر.س", "SDG", "S\$", "SRD", "SSP", "£S",
        "฿", "TT\$", "NT\$", "₺", "₴", "\$", "₫", "R", "ZK", "CFA", "FCFA",
        "EC\$", "₣", "₡",
    )
    private val CURRENCY_TOKEN = (SUPPORTED_CURRENCY_CODES + SUPPORTED_CURRENCY_SYMBOLS)
        .sortedByDescending(String::length)
        .joinToString("|", prefix = "(?:", postfix = ")") { token ->
            val escaped = Regex.escape(token)
            if (token.any(Char::isLetter)) {
                "(?<!\\p{L})$escaped(?!\\p{L})"
            } else {
                escaped
            }
        }
    private val AMOUNT_TOKEN = """\d{1,3}(?:[',.\s]\d{3})*(?:[.,]\d{1,2})?"""
    private val MONEY_PATTERN = Regex(
        """(?:$CURRENCY_TOKEN\s*$AMOUNT_TOKEN|$AMOUNT_TOKEN\s*$CURRENCY_TOKEN)""",
        RegexOption.IGNORE_CASE,
    )

    fun buildContent(
        title: String?,
        text: String?,
        bigText: String?,
        subText: String?,
        textLines: List<String>,
    ): String {
        val values = linkedSetOf<String>()
        listOf(title, text, bigText, subText)
            .plus(textLines)
            .mapNotNull { value ->
                value
                    ?.replace(Regex("""\s+"""), " ")
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
                    ?.take(MAX_FIELD_LENGTH)
            }
            .forEach(values::add)
        return values.joinToString("\n").take(MAX_CONTENT_LENGTH)
    }

    fun shouldAnalyze(content: String): Boolean {
        if (content.isBlank()) return false
        if (SECURITY_PATTERN.containsMatchIn(content)) return false
        return MONEY_PATTERN.containsMatchIn(content)
    }

    fun buildEventFingerprint(
        packageName: String,
        notificationKey: String?,
        content: String,
    ): String {
        val normalizedContent = content.trim().replace(Regex("""\s+"""), " ")
        val raw = "$packageName|${notificationKey.orEmpty()}|$normalizedContent"
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(raw.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }
}

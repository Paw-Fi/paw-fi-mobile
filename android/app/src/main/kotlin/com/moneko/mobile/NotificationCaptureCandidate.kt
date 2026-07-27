package com.moneko.mobile

import java.security.MessageDigest

object NotificationCaptureCandidate {
    private const val MAX_FIELD_LENGTH = 2_000
    private const val MAX_CONTENT_LENGTH = 6_000

    fun buildContent(
        title: String?,
        text: String?,
        bigText: String?,
        subText: String?,
        textLines: List<String>,
        summaryText: String? = null,
        infoText: String? = null,
        conversationTitle: String? = null,
        tickerText: String? = null,
        messages: List<String> = emptyList(),
        additionalText: List<String> = emptyList(),
    ): String {
        val values = linkedSetOf<String>()
        listOf(
            title,
            text,
            bigText,
            subText,
            summaryText,
            infoText,
            conversationTitle,
            tickerText,
        )
            .plus(textLines)
            .plus(messages)
            .plus(additionalText)
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
        return content.isNotBlank()
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

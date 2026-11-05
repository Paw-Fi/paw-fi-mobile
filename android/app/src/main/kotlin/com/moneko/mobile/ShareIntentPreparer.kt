package com.moneko.mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import java.util.UUID

/** Snapshot granted share URIs before the plugin resolves them by display name. */
object ShareIntentPreparer {
    private const val PREPARED = "com.moneko.mobile.SHARE_PREPARED"

    @Suppress("DEPRECATION")
    fun prepare(context: Context, intent: Intent) {
        if (intent.getBooleanExtra(PREPARED, false)) return
        val multiple = intent.action == Intent.ACTION_SEND_MULTIPLE
        if (!multiple && intent.action != Intent.ACTION_SEND) return
        val uris = if (multiple) intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            else intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { arrayListOf(it) }
        if (uris.isNullOrEmpty()) return
        val declaredTypes = intent.getStringArrayExtra(Intent.EXTRA_MIME_TYPES)
        val mimeTypes = uris.mapIndexed { index, uri ->
            try { context.contentResolver.getType(uri) } catch (_: Exception) { null }
                ?: declaredTypes?.getOrNull(index) ?: intent.type
        }
        val copies = ArrayList(uris.mapIndexed { index, uri ->
            copy(context, uri, mimeTypes[index])
        })
        if (intent.type.isNullOrBlank()) {
            intent.type = mimeTypes.filterNotNull().distinct().singleOrNull() ?: "*/*"
        }
        if (multiple) {
            intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, copies)
            intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
        } else {
            intent.putExtra(Intent.EXTRA_STREAM, copies.single())
        }
        intent.putExtra(PREPARED, true)
    }

    private fun copy(context: Context, uri: Uri, mimeType: String?): Uri {
        val id = UUID.randomUUID().toString()
        val directory = File(context.cacheDir, "incoming_shares")
        var target = File(directory, "$id.bin")
        try {
            check(directory.isDirectory || directory.mkdirs())
            require(uri.scheme == "content" || uri.scheme == "file")
            val name = if (uri.scheme == "file") uri.lastPathSegment else {
                try {
                    context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                        if (it.moveToFirst()) it.getString(it.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME)) else null
                    }
                } catch (_: Exception) { null }
            }
            val namedExtension = name?.substringAfterLast('.', "")?.lowercase()
            val extension = namedExtension?.takeIf { it in supportedExtensions }
                ?: extensionForMime(mimeType) ?: "bin"
            target = File(directory, "$id.$extension")
            val input = if (uri.scheme == "file") File(requireNotNull(uri.path)).inputStream()
                else requireNotNull(context.contentResolver.openInputStream(uri))
            input.use { source -> target.outputStream().use { source.copyTo(it) } }
        } catch (_: Exception) {
            // Return a missing local path so the shared Home handler presents its
            // normal file-read error, rather than crashing inside the plugin.
            target.delete()
        }
        return Uri.fromFile(target)
    }

    private val supportedExtensions = setOf("jpg", "jpeg", "png", "heic", "heif", "webp", "pdf", "csv", "xls", "xlsx")

    private fun extensionForMime(mimeType: String?): String? = when (mimeType) {
        "text/csv" -> "csv"
        "application/pdf" -> "pdf"
        "application/vnd.ms-excel" -> "xls"
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -> "xlsx"
        else -> mimeType?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
            ?.takeIf { it in supportedExtensions }
    }
}

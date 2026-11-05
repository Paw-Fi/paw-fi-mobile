package com.moneko.mobile

import android.app.Application
import android.app.Activity
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import com.kasem.receive_sharing_intent.ReceiveSharingIntentPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import org.json.JSONArray
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import java.lang.reflect.Proxy

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], application = Application::class)
class ShareIntentPreparerTest {
    private val context get() = RuntimeEnvironment.getApplication()

    @Test fun sameNamedContentAttachmentsRemainDistinctAndEnterTheRealPlugin() {
        Robolectric.buildContentProvider(ShareTestProvider::class.java).create("share-test")
        val originals = arrayListOf(Uri.parse("content://share-test/first"), Uri.parse("content://share-test/second"))
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).setType("image/jpeg")
            .putParcelableArrayListExtra(Intent.EXTRA_STREAM, originals)
        ShareIntentPreparer.prepare(context, intent)
        val files = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)!!
        assertEquals(2, files.size)
        assertNotEquals(files[0], files[1])
        assertEquals("first", File(files[0].path!!).readText())
        assertEquals("second", File(files[1].path!!).readText())

        val events = mutableListOf<String>()
        val plugin = ReceiveSharingIntentPlugin()
        ReceiveSharingIntentPlugin::class.java.getDeclaredField("applicationContext").apply {
            isAccessible = true
            set(plugin, context)
        }
        plugin.onListen(null, object : EventChannel.EventSink {
            override fun success(event: Any?) { events.add(event as String) }
            override fun error(code: String, message: String?, details: Any?) { fail(message) }
            override fun endOfStream() {}
        })
        plugin.onNewIntent(intent)
        val media = JSONArray(events.single())
        assertEquals(2, media.length())
        assertEquals(files[0].path, media.getJSONObject(0).getString("path"))
        assertEquals("image/jpeg", media.getJSONObject(0).getString("mimeType"))
    }

    @Test fun documentMimeAndExtensionSurviveEvenWhenTheProviderNameHasNoExtension() {
        Robolectric.buildContentProvider(ShareTestProvider::class.java).create("share-test")
        for ((name, mime) in listOf("pdf" to "application/pdf", "csv" to "text/csv",
            "xls" to "application/vnd.ms-excel",
            "xlsx" to "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")) {
            val intent = Intent(Intent.ACTION_SEND).setType(mime)
                .putExtra(Intent.EXTRA_STREAM, Uri.parse("content://share-test/$name"))
            ShareIntentPreparer.prepare(context, intent)
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)!!
            assertEquals("file", uri.scheme)
            assertTrue(uri.path!!.endsWith(".$name"))
            assertEquals(mime, intent.type)
            assertEquals(name, File(uri.path!!).readText())
        }
    }

    @Test fun fileUrlsAreCopiedAndNonShareDeepLinksAreUntouched() {
        val source = File(context.cacheDir, "receipt.png").apply { writeText("image") }
        val share = Intent(Intent.ACTION_SEND).setType("image/png")
            .putExtra(Intent.EXTRA_STREAM, Uri.fromFile(source))
        ShareIntentPreparer.prepare(context, share)
        val copy = share.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)!!
        assertNotEquals(Uri.fromFile(source), copy)
        assertEquals("image", File(copy.path!!).readText())
        val link = Intent(Intent.ACTION_VIEW, Uri.parse("moneko://auth/callback"))
        ShareIntentPreparer.prepare(context, link)
        assertEquals("moneko://auth/callback", link.dataString)
        assertNull(link.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
    }

    @Test fun repeatedDeliveryIsStableButANewShareGetsANewCopy() {
        val source = File(context.cacheDir, "receipt.png").apply { writeText("image") }
        fun intent() = Intent(Intent.ACTION_SEND).setType("image/png")
            .putExtra(Intent.EXTRA_STREAM, Uri.fromFile(source))
        val first = intent()
        ShareIntentPreparer.prepare(context, first)
        val copy = first.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        ShareIntentPreparer.prepare(context, first)
        assertEquals(copy, first.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
        val next = intent()
        ShareIntentPreparer.prepare(context, next)
        assertNotEquals(copy, next.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
    }

    @Test fun unavailableContentBecomesAMissingLocalFileInsteadOfCrashingThePlugin() {
        val intent = Intent(Intent.ACTION_SEND).setType("application/pdf")
            .putExtra(Intent.EXTRA_STREAM, Uri.parse("content://unavailable/missing.pdf"))
        ShareIntentPreparer.prepare(context, intent)
        val file = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)!!
        assertEquals("file", file.scheme)
        assertFalse(File(file.path!!).exists())
    }

    @Test fun manifestAcceptsSupportedSingleAndMixedMultipleShares() {
        for ((action, mime) in listOf(
            Intent.ACTION_SEND to "image/jpeg", Intent.ACTION_SEND to "application/pdf",
            Intent.ACTION_SEND to "text/csv", Intent.ACTION_SEND to "application/vnd.ms-excel",
            Intent.ACTION_SEND to "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            Intent.ACTION_SEND_MULTIPLE to "*/*")) {
            val intent = Intent(action).setType(mime).addCategory(Intent.CATEGORY_DEFAULT)
            val matches = context.packageManager.queryIntentActivities(intent, 0)
            assertTrue("No share target for $action $mime", matches.any { it.activityInfo.name == MainActivity::class.java.name })
        }
    }

    @Test fun coldShareIsAvailableBeforeTheDartStreamSubscribes() {
        val source = File(context.cacheDir, "statement.pdf").apply { writeText("statement") }
        val intent = Intent(Intent.ACTION_SEND).setType("application/pdf")
            .putExtra(Intent.EXTRA_STREAM, Uri.fromFile(source))
        ShareIntentPreparer.prepare(context, intent)
        val activity = Robolectric.buildActivity(Activity::class.java, intent).get()
        val plugin = ReceiveSharingIntentPlugin()
        ReceiveSharingIntentPlugin::class.java.getDeclaredField("applicationContext").apply {
            isAccessible = true
            set(plugin, context)
        }
        val binding = Proxy.newProxyInstance(ActivityPluginBinding::class.java.classLoader,
            arrayOf(ActivityPluginBinding::class.java)) { _, method, _ ->
            if (method.name == "getActivity") activity else null
        } as ActivityPluginBinding
        plugin.onAttachedToActivity(binding)
        var initial: String? = null
        plugin.onMethodCall(MethodCall("getInitialMedia", null), object : MethodChannel.Result {
            override fun success(result: Any?) { initial = result as String }
            override fun error(code: String, message: String?, details: Any?) { fail(message) }
            override fun notImplemented() { fail("Initial media must be implemented") }
        })
        val media = JSONArray(initial)
        assertEquals("application/pdf", media.getJSONObject(0).getString("mimeType"))
        assertEquals("statement", File(media.getJSONObject(0).getString("path")).readText())
        plugin.onDetachedFromActivity()
    }

    @Test fun missingIntentMimeAndUnavailableOptionalMetadataUseTheContentType() {
        Robolectric.buildContentProvider(ShareTestProvider::class.java).create("share-test")
        val intent = Intent(Intent.ACTION_SEND)
            .putExtra(Intent.EXTRA_STREAM, Uri.parse("content://share-test/bad-metadata"))
        ShareIntentPreparer.prepare(context, intent)
        val file = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)!!
        assertEquals("application/pdf", intent.type)
        assertTrue(file.path!!.endsWith(".pdf"))
        assertEquals("bad-metadata", File(file.path!!).readText())
    }
}

class ShareTestProvider : ContentProvider() {
    override fun onCreate() = true
    override fun getType(uri: Uri): String = when (uri.lastPathSegment) {
        "pdf", "bad-metadata" -> "application/pdf"
        "csv" -> "text/csv"
        "xls" -> "application/vnd.ms-excel"
        "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        else -> "image/jpeg"
    }
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
        if (uri.lastPathSegment == "bad-metadata") throw IllegalArgumentException("No display name")
        return MatrixCursor(arrayOf(OpenableColumns.DISPLAY_NAME)).apply { addRow(arrayOf("same-name")) }
    }
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        val file = File(context!!.cacheDir, "provider-${uri.lastPathSegment}")
            .apply { writeText(uri.lastPathSegment!!) }
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = 0
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
}

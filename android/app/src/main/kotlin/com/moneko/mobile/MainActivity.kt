package com.moneko.mobile

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import es.antonborri.home_widget.HomeWidgetPlugin

class MainActivity : FlutterFragmentActivity() {

    private var configuredEngine: FlutterEngine? = null

    override fun provideFlutterEngine(context: Context): FlutterEngine =
        NotificationCaptureRuntime.getEngine(context)

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        ShareIntentPreparer.prepare(this, intent)
        super.onCreate(savedInstanceState)
        NotificationCaptureConfig(applicationContext).pruneExpiredPendingCaptures()
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun onNewIntent(intent: Intent) {
        ShareIntentPreparer.prepare(this, intent)
        super.onNewIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // The process-owned engine already registered plugins in its constructor.
        AiAnalysisBackgroundBridge.register(applicationContext, flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "moneko/widgets")
            .setMethodCallHandler { call, result ->
                val data = HomeWidgetPlugin.getData(applicationContext)
                try {
                    val args = call.arguments as? Map<*, *>
                    when (call.method) {
                        "synchronizeOwner" -> {
                            MonekoWidgetStore.synchronizeOwner(data, call.arguments as String)
                            result.success(null)
                        }
                        "configureRefresh" -> {
                            requireNotNull(args)
                            MonekoWidgetStore.configureRefresh(data, args["userId"] as String, args["context"] as String)
                            result.success(null)
                        }
                        "publishSnapshot" -> {
                            requireNotNull(args)
                            result.success(MonekoWidgetStore.publishForeground(
                                data, args["userId"] as String, args["key"] as String,
                                args["snapshot"] as String, args["currency"] as String))
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("WIDGET_STORAGE_FAILED", "Widget data could not be saved.", null)
                }
            }
        configuredEngine = flutterEngine
    }

    override fun onPostResume() {
        super.onPostResume()
        // Plugin attachment and Activity-only channels are ready before Dart builds UI.
        configuredEngine?.let { NotificationCaptureRuntime.onForegroundHostReady(it) }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        configuredEngine = null
        AiAnalysisBackgroundBridge.detach(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "moneko/widgets")
            .setMethodCallHandler(null)
        // Capture callbacks, the startup latch and Dart's session owner outlive this host.
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

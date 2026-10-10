package com.moneko.mobile

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import es.antonborri.home_widget.HomeWidgetPlugin

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "moneko/notification_capture"
    }

    private var captureChannel: MethodChannel? = null
    private var captureCallback: ((String, Long) -> Unit)? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NotificationCaptureConfig(applicationContext).pruneExpiredPendingCaptures()
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        captureChannel = channel
        val callback: (String, Long) -> Unit = { userId, revision ->
            mainHandler.post {
                if (captureChannel === channel) {
                    channel.invokeMethod("capturesChanged", mapOf("userId" to userId, "revision" to revision))
                }
            }
        }
        captureCallback = callback
        NotificationCaptureDispatcher.onCaptured = callback
        channel.setMethodCallHandler { call, result ->
            val config = NotificationCaptureConfig(applicationContext)

            when (call.method) {
                "syncAuthContext" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("INVALID_ARGS", "Expected map argument", null)
                        return@setMethodCallHandler
                    }
                    val expiresAt = args["expiresAt"]
                    val expiresAtValue = when (expiresAt) {
                        is Long -> expiresAt
                        is Int -> expiresAt.toLong()
                        is Double -> expiresAt.toLong()
                        else -> 0L
                    }
                    try {
                        config.syncAuthContext(
                            supabaseUrl = args["supabaseUrl"] as? String ?: "",
                            supabaseAnonKey = args["supabaseAnonKey"] as? String ?: "",
                            accessToken = args["accessToken"] as? String ?: "",
                            userId = args["userId"] as? String ?: "",
                            expiresAt = expiresAtValue,
                        )
                        result.success(true)
                    } catch (e: IllegalStateException) {
                        result.error(
                            "AUTH_STORAGE_UNAVAILABLE",
                            "Secure auth storage is unavailable on this device.",
                            null
                        )
                    }
                }

                "getConfig" -> {
                    val configMap = config.toConfigMap().toMutableMap()
                    configMap["hasNotificationAccess"] = isNotificationListenerEnabled()
                    result.success(configMap)
                }

                "clearAuthContext" -> {
                    config.clearAuthContext()
                    result.success(true)
                }

                "clearLegacyNativeSession" -> {
                    config.clearLegacyNativeSession()
                    result.success(true)
                }

                "getPendingCaptureStatus" -> {
                    result.success(mapOf(
                        "userId" to config.userId,
                        "revision" to config.captureRevision,
                        "remaining" to config.getPendingCaptures().size,
                    ))
                }

                "syncPendingCaptures" -> {
                    val userId = (call.arguments as? Map<*, *>)?.get("userId") as? String ?: ""
                    NotificationCaptureDispatcher.executor.submit {
                        try {
                            val status = NotificationCaptureDispatcher.drain(config, userId)
                            mainHandler.post { result.success(status) }
                        } catch (_: Exception) {
                            mainHandler.post {
                                result.error("CAPTURE_RETRY_FAILED", "Capture remains queued for retry.", null)
                            }
                        }
                    }
                }

                "getPendingCaptures" -> {
                    result.success(config.getPendingCaptures())
                }

                "removePendingCaptures" -> {
                    val args = call.arguments as? Map<*, *>
                    val ids = (args?.get("ids") as? List<*>)
                        ?.mapNotNull { it as? String }
                        ?.toSet()
                        ?: emptySet()
                    config.removePendingCaptures(ids)
                    result.success(true)
                }

                "setConfig" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("INVALID_ARGS", "Expected map argument", null)
                        return@setMethodCallHandler
                    }
                    (args["enabled"] as? Boolean)?.let { config.isEnabled = it }
                    (args["scopeId"] as? String)?.let { config.scopeId = it }
                    (args["scopeName"] as? String)?.let { config.scopeName = it }
                    (args["isPortfolio"] as? Boolean)?.let { config.isPortfolio = it }
                    if (args.containsKey("accountId")) {
                        config.accountId = (args["accountId"] as? String).orEmpty()
                    }
                    if (args.containsKey("accountName")) {
                        config.accountName = (args["accountName"] as? String).orEmpty()
                    }
                    if (args.containsKey("accountCurrency")) {
                        config.accountCurrency = (args["accountCurrency"] as? String).orEmpty()
                    }
                    result.success(true)
                }

                "setPackageEnabled" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("INVALID_ARGS", "Expected map argument", null)
                        return@setMethodCallHandler
                    }
                    val packageName = args["packageName"] as? String
                    val enabled = args["enabled"] as? Boolean
                    if (packageName == null || enabled == null) {
                        result.error("INVALID_ARGS", "packageName and enabled required", null)
                        return@setMethodCallHandler
                    }
                    config.setPackageEnabled(packageName, enabled)
                    result.success(true)
                }

                "getRecentApps" -> {
                    val apps = config.getRecentApps().map { app ->
                        mapOf(
                            "packageName" to app.packageName,
                            "appLabel" to app.appLabel,
                            "lastSeenAt" to app.lastSeenAt,
                            "enabled" to app.enabled
                        )
                    }
                    result.success(apps)
                }

                "checkNotificationAccess" -> {
                    result.success(isNotificationListenerEnabled())
                }

                "openNotificationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error(
                            "SETTINGS_ERROR",
                            "Could not open notification settings: ${e.message}",
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (NotificationCaptureDispatcher.onCaptured === captureCallback) {
            NotificationCaptureDispatcher.onCaptured = null
        }
        captureCallback = null
        captureChannel?.setMethodCallHandler(null)
        captureChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /**
     * Checks whether Moneko's NotificationListenerService is enabled
     * in the system Notification Access settings.
     */
    private fun isNotificationListenerEnabled(): Boolean {
        val componentName = ComponentName(this, TransactionNotificationListenerService::class.java)
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return enabledListeners.contains(componentName.flattenToString())
    }
}

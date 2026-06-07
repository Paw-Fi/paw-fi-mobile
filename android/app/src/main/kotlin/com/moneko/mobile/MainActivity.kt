package com.moneko.mobile

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "moneko/notification_capture"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
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
                            refreshToken = args["refreshToken"] as? String ?: "",
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
                    (args["accountId"] as? String)?.let { config.accountId = it }
                    (args["accountName"] as? String)?.let { config.accountName = it }
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

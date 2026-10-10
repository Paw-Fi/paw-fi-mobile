package com.moneko.mobile

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import android.os.SystemClock
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.NumberFormat
import java.time.LocalDate
import java.util.Currency
import java.util.Locale
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext

/** Network work is outside the widget receiver; cached RemoteViews always render first. */
class MonekoWidgetRefreshWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    private var deadlineMillis = 0L
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) { refresh() }

    private suspend fun refresh(): Result {
        deadlineMillis = SystemClock.elapsedRealtime() + 90_000
        val context = applicationContext
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, MonekoWidgetProvider::class.java))
        if (ids.isEmpty()) { cancel(context); return Result.success() }
        val data = HomeWidgetPlugin.getData(context)
        val rawContext = data.getString("widget_refresh_context", null) ?: return Result.success()
        val owner = data.getString("widget_user_id", "").orEmpty()
        if (owner.isEmpty()) return Result.success()
        try {
            val settings = JSONObject(rawContext)
            if (settings.getString("userId") != owner) return Result.success()
            val auth = NotificationCaptureConfig(context)
            val token = auth.accessTokenForUser(owner)
            if (token == null) {
                // Flutter remains the only refresh-token owner. Never sign out
                // or replace financial data merely because this JWT expired.
                data.edit().putString("widget_refresh_status", "authentication_required").apply()
                MonekoWidgetProvider().onUpdate(context, manager, ids)
                return Result.success()
            }
            if (hasPendingMutations(context)) return Result.success()
            val currency = settings.getString("currency")
            val currencies = settings.getJSONArray("currencies")
            val scopes = settings.getJSONObject("scopes")
            val zone = WidgetRefreshCalculations.resolveZone(
                settings.optString("timezone"), settings.getInt("timezoneOffsetMinutes"))
            val start = WidgetRefreshCalculations.cycleStart(LocalDate.now(zone), settings.getInt("financialMonthStartDay"))
            val budgetMonth = start.withDayOfMonth(1).toString()
            val scopeIds = ids.map { data.getString("config_scope_$it", null) }.filterNotNull().distinct()
            var rates = emptyMap<String, Double>()
            if (currencies.length() > 1) {
                val response = request(auth, owner, token, "/functions/v1/currency-rates", JSONObject())
                val rateObject = response.getJSONObject("rates")
                rates = rateObject.keys().asSequence().associateWith { rateObject.getDouble(it) }
            }
            for (scopeId in scopeIds) {
                if (!scopes.has(scopeId)) continue
                val key = "widget_snapshot_${scopeId}_$currency"
                val previous = data.getString(key, null)
                val rows = (0 until currencies.length()).map { index ->
                    val nativeCurrency = currencies.getString(index)
                    val body = JSONObject().put("p_user_id", owner)
                        .put("p_scope", scopes.getString(scopeId))
                        .put("p_household_id", if (scopeId == "personal") JSONObject.NULL else scopeId)
                        .put("p_budget_month", budgetMonth).put("p_currency", nativeCurrency)
                        .put("p_include_projected_recurring", settings.getBoolean("includeRecurring"))
                        .put("p_allow_currency_fallback", false)
                    val response = request(auth, owner, token, "/rest/v1/rpc/get_pockets_month_v4", body)
                    require(response.getString("selected_currency") == nativeCurrency)
                    require(response.getString("period_month") == start.toString())
                    val budget = response.optJSONObject("budget")
                    WidgetCurrencyTotals(nativeCurrency, response.getDouble("total_spend_cents"),
                        budget?.getDouble("total_budget_cents") ?: 0.0)
                }
                val (spent, budget) = WidgetRefreshCalculations.aggregate(rows, currency, rates)
                val formatter = NumberFormat.getCurrencyInstance(Locale.forLanguageTag(settings.optString("locale", "en").replace('_', '-')))
                val currencyMetadata = Currency.getInstance(currency)
                formatter.currency = currencyMetadata
                formatter.minimumFractionDigits = currencyMetadata.defaultFractionDigits.coerceAtLeast(0)
                formatter.maximumFractionDigits = currencyMetadata.defaultFractionDigits.coerceAtLeast(0)
                // A concurrent foreground edit, account/filter change, or new
                // queued mutation owns the result. Discard this older response.
                val snapshot = JSONObject().put("version", 1).put("userId", owner)
                    .put("currency", currency).put("periodMonth", start.toString())
                    .put("totalSpent", formatter.format(spent)).put("totalBudget", formatter.format(budget))
                    .put("remainingBudget", formatter.format(budget - spent))
                    .put("progress", if (budget > 0) (spent / budget).coerceIn(0.0, 1.0) else 0.0)
                    .put("updatedAt", java.time.Instant.now().toString())
                MonekoWidgetStore.publishBackground(data, owner, rawContext, key, previous, snapshot.toString()) {
                    auth.accessTokenForUser(owner) != null && !hasPendingMutations(context)
                }
            }
            MonekoWidgetProvider().onUpdate(context, manager, ids)
            return Result.success()
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            Log.w("MonekoWidget", "Background widget refresh failed (${error.javaClass.simpleName})")
            if (data.getString("widget_user_id", "") == owner && data.getString("widget_refresh_context", null) == rawContext) {
                data.edit().putString("widget_refresh_status", if (error is WidgetReadRejected && error.status in listOf(401, 403))
                    "authentication_required" else "error").apply()
                MonekoWidgetProvider().onUpdate(context, manager, ids)
            }
            val retryable = error !is WidgetReadRejected || error.status == 429 || error.status >= 500
            return if (retryable && runAttemptCount < 2) Result.retry() else Result.success()
        }
    }

    private class WidgetReadRejected(val status: Int) : Exception("Widget read rejected ($status)")

    private suspend fun request(auth: NotificationCaptureConfig, owner: String, token: String, path: String, body: JSONObject): JSONObject {
        currentCoroutineContext().ensureActive()
        check(SystemClock.elapsedRealtime() < deadlineMillis) { "Widget refresh deadline reached" }
        check(auth.accessTokenForUser(owner) == token) { "Widget session changed" }
        val connection = URL(auth.supabaseUrl.trimEnd('/') + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 8000
            connection.readTimeout = 12000
            connection.instanceFollowRedirects = false
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("apikey", auth.supabaseAnonKey)
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            if (connection.responseCode !in 200..299) throw WidgetReadRejected(connection.responseCode)
            return connection.inputStream.bufferedReader().use { JSONObject(it.readText()) }
        } finally { connection.disconnect() }
    }

    private fun hasPendingMutations(context: Context): Boolean {
        val file = File(context.filesDir, "moneko_local.sqlite")
        if (!file.exists()) return false
        // Read only. The app/outbox alone owns writes and reconciliation.
        return SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { database ->
            database.rawQuery("SELECT 1 FROM local_mutation_outbox WHERE status NOT IN ('synced', 'cancelled') LIMIT 1", null).use { it.moveToFirst() }
        }
    }

    companion object {
        private const val NAME = "moneko_widget_refresh"
        fun ensureScheduled(context: Context) {
            if (AppWidgetManager.getInstance(context).getAppWidgetIds(
                    ComponentName(context, MonekoWidgetProvider::class.java)).isEmpty()) return
            val constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).setRequiresBatteryNotLow(true).build()
            val work = PeriodicWorkRequestBuilder<MonekoWidgetRefreshWorker>(1, TimeUnit.HOURS)
                .setConstraints(constraints).setInitialDelay(30, TimeUnit.MINUTES).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, work)
        }
        fun cancel(context: Context) { WorkManager.getInstance(context).cancelUniqueWork(NAME) }
    }
}

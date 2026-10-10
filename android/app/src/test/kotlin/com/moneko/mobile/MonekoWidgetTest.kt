package com.moneko.mobile

import android.app.Activity
import android.app.Application
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.TextView
import androidx.work.Configuration
import androidx.work.testing.WorkManagerTestInitHelper
import androidx.work.testing.TestListenableWorkerBuilder
import kotlinx.coroutines.runBlocking
import com.kasem.receive_sharing_intent.ReceiveSharingIntentPlugin
import io.flutter.plugin.common.EventChannel
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 31, 35, 36], application = Application::class)
class MonekoWidgetTest {
    private val context get() = RuntimeEnvironment.getApplication()
    private val data get() = HomeWidgetPlugin.getData(context)
    private val manager get() = AppWidgetManager.getInstance(context)

    @Before fun clear() {
        data.edit().clear().commit()
        WorkManagerTestInitHelper.initializeTestWorkManager(context, Configuration.Builder().build())
        // Model the host binding an ID without sending the first onUpdate.
        val info = AppWidgetProviderInfo().apply {
            provider = ComponentName(context, MonekoWidgetProvider::class.java)
            initialLayout = R.layout.widget
        }
        shadowOf(manager).addBoundWidget(42, info)
        shadowOf(manager).addBoundWidget(64, info)
    }

    private fun snapshot(owner: String = "user-1", spent: String = "€180.00") = JSONObject()
        .put("version", 1).put("userId", owner).put("currency", "EUR")
        .put("totalSpent", spent).put("remainingBudget", "€905.00").put("progress", 0.166).toString()

    @Test fun configurationPublishesUsableViewBeforeReportingPlacementSuccess() {
        val activity = Robolectric.buildActivity(MonekoWidgetConfigureActivity::class.java,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, 42)).create().get()
        val shadow = shadowOf(activity)
        assertEquals(Activity.RESULT_OK, shadow.resultCode)
        assertEquals(42, shadow.resultIntent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1))
        assertEquals(View.VISIBLE, shadowOf(manager).getViewFor(42).findViewById<View>(R.id.widget_setup).visibility)
        val launch = shadow.nextStartedActivity
        assertEquals(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION, launch.action)
        assertEquals("42", launch.data?.getQueryParameter("widgetId"))
    }

    @Test fun invalidConfigurationNeverReportsSuccessOrLaunchesCapture() {
        val activity = Robolectric.buildActivity(MonekoWidgetConfigureActivity::class.java).create().get()
        assertEquals(Activity.RESULT_CANCELED, shadowOf(activity).resultCode)
        assertNull(shadowOf(activity).nextStartedActivity)
    }

    @Test fun widgetLaunchCannotBeMisclassifiedAsSharedFile() {
        fun sharesFor(intent: Intent): List<Any?> {
            val events = mutableListOf<Any?>()
            val plugin = ReceiveSharingIntentPlugin()
            plugin.onListen(null, object : EventChannel.EventSink {
                override fun success(event: Any?) { events.add(event) }
                override fun error(code: String, message: String?, details: Any?) { fail(message) }
                override fun endOfStream() {}
            })
            plugin.onNewIntent(intent)
            return events
        }
        val uri = Uri.parse("moneko://configure_widget?widgetId=42")
        // Reproduces the previous URI -> shared URL -> nonexistent File path.
        assertTrue(sharesFor(Intent(Intent.ACTION_VIEW, uri)).single().toString().contains("configure_widget"))
        val launch = shadowOf(HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)).savedIntent
        assertTrue(sharesFor(launch).isEmpty())
    }

    @Test fun rendersSnapshotAndRetainsSavedDataAfterError() {
        data.edit().putString("widget_user_id", "user-1").putString("config_scope_42", "personal")
            .putString("config_currency_42", "EUR").putString("widget_snapshot_personal_EUR", snapshot())
            .putString("widget_refresh_status", "error").commit()
        MonekoWidgetProvider().onUpdate(context, manager, intArrayOf(42))
        val view = shadowOf(manager).getViewFor(42)
        assertEquals("€180.00", view.findViewById<TextView>(R.id.widget_total_spent).text.toString())
        assertEquals(View.VISIBLE, view.findViewById<View>(R.id.widget_content).visibility)
        assertTrue(view.findViewById<TextView>(R.id.widget_label_month).text.toString().contains("SAVED"))
        view.findViewById<View>(R.id.widget_btn_text).performClick()
        assertEquals(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION, shadowOf(context).nextStartedActivity.action)
    }

    @Test fun corruptDataAndAccountChangesCannotExposePreviousAccountTotals() {
        for (raw in listOf("{", "{}", snapshot("other-user"))) {
            assertNull(MonekoWidgetStore.readSnapshot(raw, "user-1", "EUR"))
        }
        assertNull(MonekoWidgetStore.readSnapshot(snapshot(), "", "EUR"))
        assertNull(MonekoWidgetStore.readSnapshot(snapshot(), "user-1", "USD"))
    }

    @Test fun upgradeKeepsLegacyDataUntilOwnerIsEstablished() {
        data.edit().putString("config_scope_42", "personal").putString("config_currency_42", "EUR")
            .putString("total_spent_personal_EUR", "€5.00").putString("remaining_budget_personal_EUR", "€95.00").commit()
        MonekoWidgetProvider().onUpdate(context, manager, intArrayOf(42))
        assertEquals("€5.00", shadowOf(manager).getViewFor(42).findViewById<TextView>(R.id.widget_total_spent).text.toString())
        MonekoWidgetStore.synchronizeOwner(data, "")
        MonekoWidgetProvider().onUpdate(context, manager, intArrayOf(42))
        assertEquals(View.GONE, shadowOf(manager).getViewFor(42).findViewById<View>(R.id.widget_content).visibility)
    }

    @Test fun restorePreservesInstanceScopeAndCurrency() {
        data.edit().putString("config_scope_42", "space-1").putString("config_currency_42", "EUR").commit()
        MonekoWidgetProvider().onRestored(context, intArrayOf(42), intArrayOf(64))
        assertEquals("space-1", data.getString("config_scope_64", null))
        assertEquals("EUR", data.getString("config_currency_64", null))
        assertFalse(data.contains("config_scope_42"))
    }

    @Test fun backgroundResponseCannotOverwriteNewerForegroundOrAccount() {
        val key = "widget_snapshot_personal_EUR"
        MonekoWidgetStore.synchronizeOwner(data, "user-1")
        MonekoWidgetStore.configureRefresh(data, "user-1", "settings")
        assertTrue(MonekoWidgetStore.publishForeground(data, "user-1", key, snapshot(), "EUR"))
        val previous = data.getString(key, null)
        assertTrue(MonekoWidgetStore.publishForeground(data, "user-1", key, snapshot(spent = "€200.00"), "EUR"))
        assertFalse(MonekoWidgetStore.publishBackground(data, "user-1", "settings", key, previous, snapshot()) { true })
        assertFalse(MonekoWidgetStore.publishBackground(data, "user-1", "settings", key, data.getString(key, null), snapshot()) { false })
        MonekoWidgetStore.synchronizeOwner(data, "user-2")
        assertFalse(MonekoWidgetStore.publishForeground(data, "user-1", key, snapshot(), "EUR"))
        assertFalse(MonekoWidgetStore.publishBackground(data, "user-1", "settings", key, previous, snapshot()) { true })
    }

    @Test fun expiredOrUnavailableAuthKeepsCachedSnapshotWithoutNetworkOrZeroes() = runBlocking {
        val previous = snapshot()
        data.edit().putString("widget_user_id", "user-1")
            .putString("config_scope_42", "personal").putString("config_currency_42", "EUR")
            .putString("widget_snapshot_personal_EUR", previous)
            .putString("widget_refresh_context", "{\"userId\":\"user-1\"}").commit()
        val worker = TestListenableWorkerBuilder<MonekoWidgetRefreshWorker>(context).build()
        assertEquals(androidx.work.ListenableWorker.Result.success(), worker.doWork())
        assertEquals(previous, data.getString("widget_snapshot_personal_EUR", null))
        assertEquals("authentication_required", data.getString("widget_refresh_status", null))
    }
}

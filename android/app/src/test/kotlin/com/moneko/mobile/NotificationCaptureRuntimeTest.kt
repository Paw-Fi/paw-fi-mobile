package com.moneko.mobile

import android.app.Application
import android.content.ContextWrapper
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.concurrent.atomic.AtomicReference

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class NotificationCaptureRuntimeTest {
    private val context get() = RuntimeEnvironment.getApplication()

    @Test fun backgroundBootstrapRegistersBeforeStartingAndHostReusesTheEngine() {
        val events = mutableListOf<String>()
        val engine = Any()
        val store = NotificationCaptureEngineStore(
            create = { received ->
                assertSame(context, received)
                events.add("create")
                engine
            },
            register = { received, value ->
                assertSame(context, received)
                assertSame(engine, value)
                events.add("bridge")
            },
            start = { value ->
                assertSame(engine, value)
                events.add("main")
            },
        )

        assertSame(engine, store.getEngine(context))
        // Activity wrappers must neither be retained nor cause a second Dart main.
        assertSame(engine, store.getEngine(ContextWrapper(context)))
        assertSame(engine, store.getEngine(ContextWrapper(context)))
        assertEquals(listOf("create", "bridge", "main"), events)
    }

    @Test fun workerMustPostToMainInsteadOfBlockingForEngineCreation() {
        val failure = AtomicReference<Throwable?>()
        val store = NotificationCaptureEngineStore<Any>(
            create = { error("Must not create an engine off main") },
            register = { _, _ -> },
            start = { },
        )
        val worker = Thread {
            try {
                store.getEngine(context)
            } catch (error: Throwable) {
                failure.set(error)
            }
        }
        worker.start()
        worker.join()
        assertTrue(failure.get() is IllegalStateException)
        assertEquals("Notification capture runtime requires the main thread", failure.get()?.message)
    }

    @Test fun reentrantAccessDuringDartStartupReturnsThePublishedEngine() {
        val engine = Any()
        var starts = 0
        lateinit var store: NotificationCaptureEngineStore<Any>
        store = NotificationCaptureEngineStore(
            create = { engine },
            register = { _, _ -> },
            start = {
                starts++
                assertSame(engine, store.getEngine(context))
            },
        )
        assertSame(engine, store.getEngine(context))
        assertEquals(1, starts)
    }

    @Test fun listenerFirstGateCompletesEachWaiterOnceAndStaysLatched() {
        val gate = NotificationCaptureForegroundGate()
        var replies = 0
        gate.await { replies++ }
        gate.await { replies++ }
        assertEquals(0, replies)
        gate.markReady()
        assertEquals(2, replies)
        // Host detach does not reset process startup; reattachment is idempotent.
        gate.markReady()
        assertEquals(2, replies)
        gate.await { replies++ }
        assertEquals(3, replies)
    }

    @Test fun activityFirstReadinessIsNotLostWhileDartInitializes() {
        val gate = NotificationCaptureForegroundGate()
        gate.markReady()
        var replies = 0
        gate.await { replies++ }
        assertEquals(1, replies)
    }
}

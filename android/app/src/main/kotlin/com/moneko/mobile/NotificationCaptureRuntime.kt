package com.moneko.mobile

import android.content.Context
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** One default Dart main (and GoTrue client) for capture workers and the UI host. */
internal object NotificationCaptureRuntime {
    private val foregroundGate = NotificationCaptureForegroundGate()
    private lateinit var bridge: NotificationCaptureBridge
    private val engines = NotificationCaptureEngineStore(
        create = { context -> FlutterEngine(context) },
        register = { context, engine ->
            bridge = NotificationCaptureBridge(context, engine.dartExecutor.binaryMessenger, foregroundGate)
        },
        start = { engine ->
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        },
    )

    /** Call on main; workers must post here, never block the main thread waiting for Dart. */
    fun getEngine(context: Context): FlutterEngine = engines.getEngine(context)

    fun captureChannel(context: Context): MethodChannel {
        getEngine(context)
        return bridge.channel
    }

    fun onForegroundHostReady(engine: FlutterEngine) {
        requireCaptureMainThread()
        check(engines.owns(engine)) { "Foreground host must use the capture runtime engine" }
        foregroundGate.markReady()
    }
}

/** Injectable construction boundary so ownership/order tests do not load Flutter's native VM. */
internal class NotificationCaptureEngineStore<T : Any>(
    private val create: (Context) -> T,
    private val register: (Context, T) -> Unit,
    private val start: (T) -> Unit,
) {
    private var engine: T? = null

    fun getEngine(context: Context): T {
        requireCaptureMainThread()
        engine?.let { return it }
        val applicationContext = context.applicationContext
        val created = create(applicationContext)
        register(applicationContext, created)
        // Publish before Dart starts so reentrant access cannot create a second session owner.
        engine = created
        start(created)
        return created
    }

    fun owns(value: T): Boolean = engine === value
}

/** Startup permission, not current visibility: never reset on Activity detach or recreation. */
internal class NotificationCaptureForegroundGate {
    private var ready = false
    private val waiters = mutableListOf<() -> Unit>()

    fun await(reply: () -> Unit) {
        requireCaptureMainThread()
        if (ready) reply() else waiters.add(reply)
    }

    fun markReady() {
        requireCaptureMainThread()
        if (ready) return
        ready = true
        val pending = waiters.toList()
        waiters.clear()
        pending.forEach { it() }
    }
}

private fun requireCaptureMainThread() {
    check(Looper.myLooper() == Looper.getMainLooper()) {
        "Notification capture runtime requires the main thread"
    }
}

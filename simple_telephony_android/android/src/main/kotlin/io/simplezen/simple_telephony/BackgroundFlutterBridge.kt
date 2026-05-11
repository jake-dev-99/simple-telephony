package io.simplezen.simple_telephony

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.view.FlutterCallbackInformation
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

internal class BackgroundFlutterBridge(
    private val context: Context,
    private val callStore: CallStore,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val bootstrapExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "simple-telephony-bg-bootstrap").apply { isDaemon = true }
    }

    // All mutable state is protected by `synchronized(this)`.
    private var dispatcherReady = false
    private var bootstrapInProgress = false
    private var flutterEngine: FlutterEngine? = null
    private var controlChannel: MethodChannel? = null
    private var backgroundEventsChannel: MethodChannel? = null

    fun dispose() {
        synchronized(this) {
            controlChannel?.setMethodCallHandler(null)
            controlChannel = null
            backgroundEventsChannel = null
            dispatcherReady = false
            flutterEngine?.destroy()
            flutterEngine = null
        }
    }

    /**
     * Ensures the background FlutterEngine is started (or already starting).
     * Safe to call from the telecom binder thread — bootstrap runs on a
     * dedicated worker thread so we never block the caller on
     * `FlutterLoader.ensureInitializationComplete`.
     */
    fun ensureStarted() {
        val config = callStore.getBackgroundHandlerConfig() ?: return
        synchronized(this) {
            if (flutterEngine != null || bootstrapInProgress) return
            bootstrapInProgress = true
        }
        bootstrapExecutor.execute { bootstrapEngine(config.dispatcherHandle) }
    }

    private fun bootstrapEngine(dispatcherHandle: Long) {
        // `bootstrapInProgress` was set to true by `ensureStarted()`. Two
        // callers eventually clear it:
        //   - The success path on the main thread, in `createEngineOnMainThread`,
        //     once the engine is fully attached.
        //   - Every failure path here, so a transient failure (missing
        //     callback handle, corrupt Dart snapshot, etc.) doesn't
        //     permanently strand the bridge in a "bootstrap in progress"
        //     state where later `ensureStarted()` calls become silent
        //     no-ops.
        var handedOffToMainThread = false
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context.applicationContext)
            loader.ensureInitializationComplete(context.applicationContext, null)

            val callbackInfo = FlutterCallbackInformation
                .lookupCallbackInformation(dispatcherHandle)
            if (callbackInfo == null) {
                Log.e(TAG, "Unable to resolve background dispatcher handle $dispatcherHandle")
                return
            }

            // Construct the engine + channels on the main thread. FlutterEngine
            // and MethodChannel both assume they're created on the platform
            // thread; creating them on a worker thread is undefined behaviour.
            // From here on, `createEngineOnMainThread` owns the
            // `bootstrapInProgress` reset.
            mainHandler.post { createEngineOnMainThread(callbackInfo, loader) }
            handedOffToMainThread = true
        } catch (throwable: Throwable) {
            // Engine bootstrap can fail if the app bundle is missing or the
            // Dart snapshot is corrupt. Log and bail — events stay queued in
            // CallStore and will be retried on the next ensureStarted() call.
            Log.e(TAG, "Failed to start background Flutter engine", throwable)
        } finally {
            // Clear the flag on every exit path EXCEPT the successful
            // hand-off to the main thread (where createEngineOnMainThread
            // takes ownership). Without this, any non-throwing early return
            // — most importantly the `callbackInfo == null` branch above —
            // would leave bootstrapInProgress stuck at true and every
            // future ensureStarted() call would silently skip the engine
            // start.
            if (!handedOffToMainThread) {
                synchronized(this) { bootstrapInProgress = false }
            }
        }
    }

    private fun createEngineOnMainThread(
        callbackInfo: FlutterCallbackInformation,
        loader: io.flutter.embedding.engine.loader.FlutterLoader,
    ) {
        synchronized(this) {
            if (flutterEngine != null) {
                bootstrapInProgress = false
                return
            }
            try {
                val engine = FlutterEngine(context.applicationContext)
                val messenger = engine.dartExecutor.binaryMessenger
                controlChannel = MethodChannel(messenger, TelecomConstants.ACTIONS_CHANNEL).also {
                    it.setMethodCallHandler(::onMethodCall)
                }
                backgroundEventsChannel = MethodChannel(
                    messenger,
                    TelecomConstants.BACKGROUND_EVENTS_CHANNEL,
                )
                val callback = DartExecutor.DartCallback(
                    context.assets,
                    loader.findAppBundlePath(),
                    callbackInfo,
                )
                engine.dartExecutor.executeDartCallback(callback)
                flutterEngine = engine
            } catch (throwable: Throwable) {
                Log.e(TAG, "Failed to create background Flutter engine", throwable)
            } finally {
                bootstrapInProgress = false
            }
        }
    }

    fun flushPendingEvents() {
        val channel: MethodChannel
        val pendingEvents: List<PendingCallEvent>
        synchronized(this) {
            if (!dispatcherReady) return
            channel = backgroundEventsChannel ?: return
            pendingEvents = callStore.claimPendingBackgroundEvents()
        }
        pendingEvents.forEach { pendingEvent ->
            mainHandler.post {
                channel.invokeMethod("deliverBackgroundEvent", pendingEvent.payload)
            }
        }
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getBackgroundHandlerHandle" -> {
                result.success(callStore.getBackgroundUserHandle())
            }

            "backgroundDispatcherReady" -> {
                synchronized(this) { dispatcherReady = true }
                result.success(null)
                flushPendingEvents()
            }

            "ackBackgroundEvent" -> {
                val eventId = call.arguments as? String
                if (eventId.isNullOrBlank()) {
                    result.success(null)
                    return
                }

                callStore.acknowledgeBackgroundEvent(eventId)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    companion object {
        private const val TAG = "BackgroundFlutterBridge"
    }
}

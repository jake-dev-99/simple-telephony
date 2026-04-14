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

internal class BackgroundFlutterBridge(
    private val context: Context,
    private val callStore: CallStore,
) {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var dispatcherReady = false

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

    fun ensureStarted() {
        val config = callStore.getBackgroundHandlerConfig() ?: return
        if (flutterEngine != null) {
            return
        }

        synchronized(this) {
            // Re-check inside the lock — another thread may have started the
            // engine while we were waiting to acquire it (double-checked locking).
            if (flutterEngine != null) {
                return
            }

            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(context.applicationContext)
                loader.ensureInitializationComplete(context.applicationContext, null)

                val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(
                    config.dispatcherHandle,
                )
                if (callbackInfo == null) {
                    Log.e(TAG, "Unable to resolve background dispatcher handle ${config.dispatcherHandle}")
                    return
                }

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
                // Engine bootstrap can fail if the app bundle is missing or the
                // Dart snapshot is corrupt. Log and bail — events stay queued in
                // CallStore and will be retried on the next ensureStarted() call.
                Log.e(TAG, "Failed to start background Flutter engine", throwable)
            }
        }
    }

    fun flushPendingEvents() {
        if (!dispatcherReady) {
            return
        }

        val channel = backgroundEventsChannel ?: return
        val pendingEvents = callStore.claimPendingBackgroundEvents()
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
                dispatcherReady = true
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

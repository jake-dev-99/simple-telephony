package io.simplezen.simple_telephony

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Handles dispatching call events from native code to Flutter via MethodChannel.
 * This class is public so that consumer apps can use their own InCallService
 * implementation while still routing events through simple-telephony's channel.
 */
object InboundTelecom {
    private const val TAG = "InboundTelecom"
    const val CHANNEL_NAME = "io.simplezen.simple_telephony/inbound"

    private var applicationContext: Context? = null
    private var binaryMessenger: BinaryMessenger? = null
    private var channel: MethodChannel? = null

    fun initialize(context: Context, messenger: BinaryMessenger) {
        applicationContext = context.applicationContext
        binaryMessenger = messenger
        channel = MethodChannel(messenger, CHANNEL_NAME)
    }

    fun detach() {
        channel = null
        binaryMessenger = null
    }

    fun transferCallEvent(context: Context, payload: Map<String, Any?>) {
        val messenger = ensureMessenger(context)
        val methodChannel = channel ?: MethodChannel(messenger, CHANNEL_NAME).also {
            channel = it
        }

        val jsonPayload = JSONObject(payload).toString()
        Handler(Looper.getMainLooper()).post {
            methodChannel.invokeMethod(
                "receiveCallEvent",
                jsonPayload,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        Log.d(TAG, "Call event delivered to Flutter")
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.e(TAG, "Error delivering call event: $errorCode $errorMessage")
                    }

                    override fun notImplemented() {
                        Log.e(TAG, "Flutter side has not implemented receiveCallEvent")
                    }
                },
            )
        }
    }

    private fun ensureMessenger(context: Context): BinaryMessenger {
        binaryMessenger?.let { return it }

        val appContext = applicationContext ?: context.applicationContext
        val flutterEngine = FlutterEngine(appContext)
        val loader = FlutterInjector.instance().flutterLoader()
        val entrypoint = DartEntrypoint(loader.findAppBundlePath(), "initializeApp")
        flutterEngine.dartExecutor.executeDartEntrypoint(entrypoint)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        binaryMessenger = messenger
        channel = MethodChannel(messenger, CHANNEL_NAME)
        return messenger
    }
}

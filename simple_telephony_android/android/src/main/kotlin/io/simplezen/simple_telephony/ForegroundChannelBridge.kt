package io.simplezen.simple_telephony

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

internal class ForegroundChannelBridge : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())

    private var channel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    fun attach(binaryMessenger: BinaryMessenger) {
        channel = EventChannel(binaryMessenger, TelecomConstants.FOREGROUND_EVENTS_CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    fun detach() {
        channel?.setStreamHandler(null)
        channel = null
        eventSink = null
    }

    // Sends a call event to the foreground Dart listener. If no listener is
    // attached (eventSink is null), the event is intentionally dropped —
    // foreground delivery is live-only. Background delivery handles persistence.
    fun emit(payload: Map<String, Any?>) {
        val sink = eventSink ?: return
        mainHandler.post {
            sink.success(payload)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}

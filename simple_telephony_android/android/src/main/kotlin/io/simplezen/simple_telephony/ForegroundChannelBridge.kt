package io.simplezen.simple_telephony

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ConcurrentHashMap

/**
 * Bridges live (foreground) call events to the Dart side over an
 * [EventChannel] — one registration per attached `FlutterEngine`.
 *
 * WHY PER-ENGINE (UNFY-176). This bridge is a single process-wide instance
 * (held by [TelecomServiceRuntime]). More than one `FlutterEngine` can register
 * `SimpleTelephonyPlugin` in the same process — the main app engine plus any
 * engine a foreground service spins up — so [attach]/[detach] fire once per
 * engine. The previous design kept a single `channel`/`sink`, so the most
 * recent [attach] overwrote the field and a [detach] tore down whichever engine
 * attached *last*, not the engine actually detaching. With the ordering
 * [service attaches → main attaches → service detaches], the service's detach
 * removed the *main* engine's `StreamHandler`, and the consumer's `.listen()`
 * then hit `MissingPluginException(... /foreground_events)`.
 *
 * Now each engine's messenger owns its own [EventChannel] + sink, [detach]
 * removes only that engine's registration, and [emit] fans out to every live
 * sink — so no engine can clobber another's handler.
 */
internal class ForegroundChannelBridge {
    private val mainHandler = Handler(Looper.getMainLooper())

    /** One registration per engine, keyed by that engine's messenger. */
    private val registrations = ConcurrentHashMap<BinaryMessenger, Registration>()

    fun attach(binaryMessenger: BinaryMessenger) {
        // Idempotent per engine: re-attaching the same messenger reuses its
        // registration rather than leaking a second EventChannel.
        registrations.computeIfAbsent(binaryMessenger) { messenger ->
            Registration().also { registration ->
                registration.channel =
                    EventChannel(messenger, TelecomConstants.FOREGROUND_EVENTS_CHANNEL)
                        .also { it.setStreamHandler(registration) }
            }
        }
    }

    fun detach(binaryMessenger: BinaryMessenger) {
        // Remove ONLY the detaching engine's registration; every other engine's
        // handler is left intact (the UNFY-176 fix).
        registrations.remove(binaryMessenger)?.let { registration ->
            registration.channel?.setStreamHandler(null)
            registration.channel = null
            registration.sink = null
        }
    }

    // Sends a call event to every live foreground listener. Engines with no
    // active listener (sink == null) are skipped — foreground delivery is
    // live-only; background delivery (BackgroundFlutterBridge) handles
    // persistence.
    fun emit(payload: Map<String, Any?>) {
        registrations.values.forEach { registration ->
            val sink = registration.sink ?: return@forEach
            mainHandler.post { sink.success(payload) }
        }
    }

    /**
     * Per-engine [EventChannel.StreamHandler] so each engine tracks its own
     * sink independently — a listen/cancel on one engine cannot disturb
     * another's delivery.
     */
    private class Registration : EventChannel.StreamHandler {
        @Volatile var channel: EventChannel? = null
        @Volatile var sink: EventChannel.EventSink? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            sink = events
        }

        override fun onCancel(arguments: Any?) {
            sink = null
        }
    }
}

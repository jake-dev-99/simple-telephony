package io.simplezen.simple_telephony

import android.content.Context

/**
 * Listener invoked by [TelecomServiceRuntime] on every call state event.
 *
 * Default-dialer Flutter apps typically need to launch a dedicated Activity
 * (with its own Flutter engine) to show a full-screen incoming-call overlay.
 * That Activity launch must happen on the Android side — Dart cannot start
 * Activities on its own, and routing every telecom event through Dart first
 * would add latency in the background / cold-start case.
 *
 * This interface is the host-side seam for that work. Apps implement it,
 * register a single instance via [SimpleTelephonyCallUi.launcher] (typically
 * in `Application.onCreate`), and decide inside [onCallEvent] whether to
 * launch UI, finish UI, post a missed-call notification, etc. The plugin
 * still delivers the same events to the Dart event stream in parallel; this
 * hook is purely additive for host apps that need the native-side UI seam.
 *
 * Consumers that only need Dart-level events (e.g. a call-log integration
 * that never renders call UI) can leave [SimpleTelephonyCallUi.launcher]
 * null — the plugin will skip the dispatch silently.
 *
 * ## Thread safety
 *
 * [onCallEvent] is invoked on the InCallService's binder thread. Return
 * quickly; launching an Activity inline is fine, but any heavier work
 * (database writes, network calls) should be offloaded to another executor.
 *
 * ## Payload
 *
 * The [payload] map is the same map the plugin emits to the Dart
 * `SimpleTelephonyNative.events` stream. See [onCallEvent] for the key list.
 */
interface CallUiLauncher {
    /**
     * Invoked on every call state update. Implementations inspect [payload]
     * and choose an action (typically: launch an Activity on the first
     * `"ringing"` event of an incoming call, finish that Activity on the
     * `"disconnected"` event).
     *
     * Payload keys:
     *  - `"eventId"` ([String]): UUID unique to this event.
     *  - `"callId"` ([String]): stable id for the call across state transitions.
     *  - `"state"` ([String]): one of `"new"`, `"dialing"`, `"ringing"`,
     *    `"connecting"`, `"active"`, `"holding"`, `"disconnecting"`,
     *    `"disconnected"`, `"pulling"`, `"selectPhoneAccount"`,
     *    `"audioProcessing"`, `"simulatedRinging"`, or `"unknown"`.
     *  - `"isIncoming"` ([Boolean]): true for inbound calls.
     *  - `"phoneNumber"` ([String]?): E.164 when available, else raw number,
     *    null if the platform withheld it.
     *  - `"displayName"` ([String]?): contact display name if the platform
     *    resolved one.
     *  - `"disconnectCause"` ([String]?): only set on `"disconnected"`.
     *    Values include `"REMOTE"`, `"LOCAL"`, `"MISSED"`, `"REJECTED"`,
     *    `"BUSY"`, `"ERROR"`, `"CANCELED"`, `"UNKNOWN"`.
     *  - `"timestamp"` ([Long]): event time in ms since epoch.
     *
     * @param context the plugin's application context — safe to use for
     *   `startActivity` with `FLAG_ACTIVITY_NEW_TASK`.
     */
    fun onCallEvent(context: Context, payload: Map<String, Any?>)
}

/**
 * Process-wide registry for the active [CallUiLauncher].
 *
 * Host apps install their launcher early in the process lifecycle, typically
 * in `Application.onCreate`:
 * ```kotlin
 * class MyApplication : Application() {
 *   override fun onCreate() {
 *     super.onCreate()
 *     SimpleTelephonyCallUi.launcher = MyCallUiLauncher(this)
 *   }
 * }
 * ```
 *
 * Only one launcher may be registered at a time. Reassignment is allowed
 * (useful for tests); the runtime reads the field fresh on every event.
 */
object SimpleTelephonyCallUi {
    @Volatile
    var launcher: CallUiLauncher? = null
}

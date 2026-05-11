package io.simplezen.simple_telephony

import android.content.Context
import android.telecom.Call
import android.telecom.DisconnectCause
import android.telecom.VideoProfile
import android.util.Log
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

object TelecomServiceRuntime {
    private const val TAG = "TelecomServiceRuntime"

    private data class Components(
        val appContext: Context,
        val callStore: CallStore,
        val foregroundBridge: ForegroundChannelBridge,
        val backgroundBridge: BackgroundFlutterBridge,
    )

    @Volatile
    private var components: Components? = null

    private val callIdByCall = ConcurrentHashMap<Call, String>()
    private val liveCallById = ConcurrentHashMap<String, Call>()

    val isInitialized: Boolean get() = components != null

    fun initialize(context: Context) {
        if (components != null) return
        synchronized(this) {
            if (components != null) return
            val appContext = context.applicationContext
            val callStore = CallStore(appContext)
            components = Components(
                appContext = appContext,
                callStore = callStore,
                foregroundBridge = ForegroundChannelBridge(),
                backgroundBridge = BackgroundFlutterBridge(appContext, callStore),
            )
        }
    }

    private fun require(): Components = components
        ?: error("TelecomServiceRuntime accessed before initialize()")

    internal fun foregroundBridge(): ForegroundChannelBridge = require().foregroundBridge

    internal fun registerBackgroundHandler(dispatcherHandle: Long, userHandle: Long) {
        val runtime = require()
        // Destroy the previous background engine so stale callback handles
        // don't persist after re-registration (e.g. hot restart, app update).
        runtime.backgroundBridge.dispose()
        runtime.callStore.saveBackgroundHandlerConfig(
            BackgroundHandlerConfig(
                dispatcherHandle = dispatcherHandle,
                userHandle = userHandle,
            ),
        )
        runtime.backgroundBridge.ensureStarted()
        runtime.backgroundBridge.flushPendingEvents()
    }

    internal fun currentCalls(): List<Map<String, Any?>> =
        require().callStore.getCurrentCalls().map { it.toMap() }

    internal fun answerCall(callId: String): CallControlResult {
        val liveCall = liveCallById[callId]
        if (liveCall != null) {
            return try {
                liveCall.answer(VideoProfile.STATE_AUDIO_ONLY)
                CallControlResult(CallControlStatus.success)
            } catch (throwable: Throwable) {
                Log.e(TAG, "Failed answering call $callId", throwable)
                CallControlResult(
                    CallControlStatus.platformFailure,
                    throwable.message ?: "Failed to answer call",
                )
            }
        }

        return if (require().callStore.getCall(callId) != null) {
            CallControlResult(
                CallControlStatus.notAttached,
                "Call record exists but the live telecom call is not attached",
            )
        } else {
            CallControlResult(CallControlStatus.notFound, "Unknown callId: $callId")
        }
    }

    internal fun endCall(callId: String): CallControlResult {
        val liveCall = liveCallById[callId]
        if (liveCall != null) {
            return try {
                liveCall.disconnect()
                CallControlResult(CallControlStatus.success)
            } catch (throwable: Throwable) {
                Log.e(TAG, "Failed ending call $callId", throwable)
                CallControlResult(
                    CallControlStatus.platformFailure,
                    throwable.message ?: "Failed to end call",
                )
            }
        }

        return if (require().callStore.getCall(callId) != null) {
            CallControlResult(
                CallControlStatus.notAttached,
                "Call record exists but the live telecom call is not attached",
            )
        } else {
            CallControlResult(CallControlStatus.notFound, "Unknown callId: $callId")
        }
    }

    fun onCallAdded(call: Call): Map<String, Any?> {
        val callId = resolveCallId(call)
        liveCallById[callId] = call
        return dispatchCallUpdate(call, call.state, call.details?.disconnectCause)
    }

    fun onCallStateChanged(call: Call, newState: Int): Map<String, Any?> {
        trackIfNeeded(call)
        return dispatchCallUpdate(call, newState, call.details?.disconnectCause)
    }

    fun onCallDetailsChanged(call: Call): Map<String, Any?> {
        trackIfNeeded(call)
        return dispatchCallUpdate(call, call.state, call.details?.disconnectCause)
    }

    fun onCallRemoved(call: Call, disconnectCause: DisconnectCause?): Map<String, Any?> {
        trackIfNeeded(call)
        val payload = dispatchCallUpdate(call, Call.STATE_DISCONNECTED, disconnectCause)

        callIdByCall.remove(call)?.let(liveCallById::remove)
        return payload
    }

    private fun trackIfNeeded(call: Call) {
        if (!callIdByCall.containsKey(call)) {
            val callId = resolveCallId(call)
            liveCallById[callId] = call
        }
    }

    private fun resolveCallId(call: Call): String {
        val existing = callIdByCall[call]
        if (existing != null) {
            return existing
        }

        val callId = require().callStore.findReusableCallId(
            phoneNumber = call.detailsPhoneNumber(),
            isIncoming = call.isIncomingCall(),
        ) ?: UUID.randomUUID().toString()

        callIdByCall[call] = callId
        return callId
    }

    private fun dispatchCallUpdate(
        call: Call,
        state: Int,
        disconnectCause: DisconnectCause?,
    ): Map<String, Any?> {
        val runtime = require()
        // Synchronize the entire read-mutate-write sequence against callStore
        // so that rapid state changes on different threads cannot interleave.
        val (payload, shouldFlushBackground) = synchronized(runtime.callStore) {
            val callId = resolveCallId(call)
            val now = System.currentTimeMillis()
            val existingRecord = runtime.callStore.getCall(callId)
            val eventId = UUID.randomUUID().toString()
            val record = CallSessionRecord(
                callId = callId,
                state = stateToString(state),
                isIncoming = call.isIncomingCall(),
                createdAt = existingRecord?.createdAt ?: now,
                updatedAt = now,
                isLive = state != Call.STATE_DISCONNECTED,
                // Snapshot the count *before* we enqueue this event below,
                // so the record reflects already-queued events at dispatch time.
                pendingEventCount = runtime.callStore.queuedBackgroundEventCount(callId),
                phoneNumber = call.detailsPhoneNumber(),
                displayName = call.details?.callerDisplayName?.toString(),
                disconnectCause = disconnectCauseToString(disconnectCause),
            )

            runtime.callStore.upsertCall(record)

            val eventPayload = mutableMapOf<String, Any?>(
                "eventId" to eventId,
                "callId" to callId,
                "state" to record.state,
                "isIncoming" to record.isIncoming,
                "timestamp" to now,
                "phoneNumber" to record.phoneNumber,
                "displayName" to record.displayName,
                "disconnectCause" to record.disconnectCause,
            )

            val hasBackgroundHandler = runtime.callStore.getBackgroundHandlerConfig() != null
            if (hasBackgroundHandler) {
                runtime.callStore.enqueueBackgroundEvent(
                    PendingCallEvent(
                        eventId = eventId,
                        callId = callId,
                        payload = eventPayload,
                        createdAt = now,
                    ),
                )
            }

            Pair(eventPayload, hasBackgroundHandler)
        }

        // Emit outside the lock — these don't touch callStore and may block.
        runtime.foregroundBridge.emit(payload)

        if (shouldFlushBackground) {
            runtime.backgroundBridge.ensureStarted()
            runtime.backgroundBridge.flushPendingEvents()
        }

        // Notify the host-side UI launcher, if one is registered. This is the
        // seam used by default-dialer apps to pop a full-screen Activity for
        // incoming calls (see [CallUiLauncher] docs). Runs after the Dart
        // bridges so that a host-side exception can't starve the event stream.
        SimpleTelephonyCallUi.launcher?.let { launcher ->
            try {
                launcher.onCallEvent(runtime.appContext, payload)
            } catch (throwable: Throwable) {
                Log.e(TAG, "CallUiLauncher threw; continuing", throwable)
            }
        }

        return payload
    }
}

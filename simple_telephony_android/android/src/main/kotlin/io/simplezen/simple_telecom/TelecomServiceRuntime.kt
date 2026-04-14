package io.simplezen.simple_telecom

import android.content.Context
import android.telecom.Call
import android.telecom.DisconnectCause
import android.telecom.VideoProfile
import android.util.Log
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

object TelecomServiceRuntime {
    private const val TAG = "TelecomServiceRuntime"

    private lateinit var appContext: Context
    private lateinit var callStore: CallStore
    private lateinit var foregroundBridge: ForegroundChannelBridge
    private lateinit var backgroundBridge: BackgroundFlutterBridge

    private val callIdByCall = ConcurrentHashMap<Call, String>()
    private val liveCallById = ConcurrentHashMap<String, Call>()

    @Volatile
    var isInitialized = false
        private set

    fun initialize(context: Context) {
        if (isInitialized) {
            return
        }

        synchronized(this) {
            if (isInitialized) {
                return
            }

            appContext = context.applicationContext
            callStore = CallStore(appContext)
            foregroundBridge = ForegroundChannelBridge()
            backgroundBridge = BackgroundFlutterBridge(appContext, callStore)
            isInitialized = true
        }
    }

    internal fun foregroundBridge(): ForegroundChannelBridge = foregroundBridge

    internal fun registerBackgroundHandler(dispatcherHandle: Long, userHandle: Long) {
        // Destroy the previous background engine so stale callback handles
        // don't persist after re-registration (e.g. hot restart, app update).
        backgroundBridge.dispose()
        callStore.saveBackgroundHandlerConfig(
            BackgroundHandlerConfig(
                dispatcherHandle = dispatcherHandle,
                userHandle = userHandle,
            ),
        )
        backgroundBridge.ensureStarted()
        backgroundBridge.flushPendingEvents()
    }

    internal fun currentCalls(): List<Map<String, Any?>> =
        callStore.getCurrentCalls().map { it.toMap() }

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

        return if (callStore.getCall(callId) != null) {
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

        return if (callStore.getCall(callId) != null) {
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

        val callId = callStore.findReusableCallId(
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
        // Synchronize the entire read-mutate-write sequence against callStore
        // so that rapid state changes on different threads cannot interleave.
        val (payload, shouldFlushBackground) = synchronized(callStore) {
            val callId = resolveCallId(call)
            val now = System.currentTimeMillis()
            val existingRecord = callStore.getCall(callId)
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
                pendingEventCount = callStore.queuedBackgroundEventCount(callId),
                phoneNumber = call.detailsPhoneNumber(),
                displayName = call.details?.callerDisplayName?.toString(),
                disconnectCause = disconnectCauseToString(disconnectCause),
            )

            callStore.upsertCall(record)

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

            val hasBackgroundHandler = callStore.getBackgroundHandlerConfig() != null
            if (hasBackgroundHandler) {
                callStore.enqueueBackgroundEvent(
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
        foregroundBridge.emit(payload)

        if (shouldFlushBackground) {
            backgroundBridge.ensureStarted()
            backgroundBridge.flushPendingEvents()
        }

        return payload
    }
}

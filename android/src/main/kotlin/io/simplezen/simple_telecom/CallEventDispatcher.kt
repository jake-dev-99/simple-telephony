package io.simplezen.simple_telephony

import android.content.Context
import android.net.Uri
import android.telecom.Call
import android.telecom.DisconnectCause
import android.util.Log

internal object CallEventDispatcher {
    private const val TAG = "CallEventDispatcher"

    fun onCallAdded(context: Context, entry: CallRegistry.Entry) {
        dispatch(context, entry, entry.call.state, entry.call.details?.disconnectCause)
    }

    fun onCallStateChanged(
        context: Context,
        entry: CallRegistry.Entry,
        newState: Int,
    ) {
        dispatch(context, entry, newState, entry.call.details?.disconnectCause)
    }

    fun onCallRemoved(
        context: Context,
        entry: CallRegistry.Entry?,
        disconnectCause: DisconnectCause?,
    ) {
        if (entry != null) {
            dispatch(context, entry, Call.STATE_DISCONNECTED, disconnectCause)
        }
    }

    private fun dispatch(
        context: Context,
        entry: CallRegistry.Entry,
        state: Int,
        disconnectCause: DisconnectCause?,
    ) {
        val payload = mutableMapOf<String, Any?>(
            "callId" to entry.id,
            "state" to stateToString(state),
            "isIncoming" to (entry.direction == CallRegistry.CallDirection.INCOMING),
            "timestamp" to System.currentTimeMillis(),
        )

        entry.call.details?.let { details ->
            details.handle?.let { handle ->
                payload["phoneNumber"] = extractHandle(handle)
            }
            if (!details.callerDisplayName.isNullOrBlank()) {
                payload["displayName"] = details.callerDisplayName
            }
        }

        disconnectCause?.let { cause ->
            val bestEffortDescription = listOfNotNull(
                cause.reason?.takeIf { it.isNotBlank() },
                cause.label?.toString()?.takeIf { it.isNotBlank() },
                cause.description?.toString()?.takeIf { it.isNotBlank() },
                cause.toString().takeIf { it.isNotBlank() && it != cause.javaClass.name },
            ).firstOrNull()

            if (!bestEffortDescription.isNullOrBlank()) {
                payload["disconnectCause"] = bestEffortDescription
            }
        }

        try {
            InboundTelecom.transferCallEvent(context, payload)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to dispatch call event", t)
        }
    }

    private fun stateToString(state: Int): String = when (state) {
        Call.STATE_NEW -> "new"
        Call.STATE_RINGING -> "ringing"
        Call.STATE_DIALING -> "dialing"
        Call.STATE_CONNECTING -> "connecting"
        Call.STATE_ACTIVE -> "active"
        Call.STATE_HOLDING -> "holding"
        Call.STATE_DISCONNECTING -> "disconnecting"
        Call.STATE_DISCONNECTED -> "disconnected"
        else -> "unknown"
    }

    private fun extractHandle(handle: Uri): String? {
        val value = handle.schemeSpecificPart ?: return null
        return value.ifBlank { null }
    }
}

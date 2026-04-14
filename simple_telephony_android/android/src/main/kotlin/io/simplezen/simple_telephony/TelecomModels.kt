package io.simplezen.simple_telephony

import android.net.Uri
import android.telecom.Call
import android.telecom.DisconnectCause
import org.json.JSONObject

internal data class CallSessionRecord(
    val callId: String,
    val state: String,
    val isIncoming: Boolean,
    val createdAt: Long,
    val updatedAt: Long,
    val isLive: Boolean,
    val pendingEventCount: Int,
    val phoneNumber: String? = null,
    val displayName: String? = null,
    val disconnectCause: String? = null,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "callId" to callId,
        "state" to state,
        "isIncoming" to isIncoming,
        "createdAt" to createdAt,
        "updatedAt" to updatedAt,
        "isLive" to isLive,
        "pendingEventCount" to pendingEventCount,
        "phoneNumber" to phoneNumber,
        "displayName" to displayName,
        "disconnectCause" to disconnectCause,
    )

    fun toJson(): JSONObject = JSONObject(toMap())

    companion object {
        fun fromJson(json: JSONObject): CallSessionRecord = CallSessionRecord(
            callId = json.optString("callId"),
            state = json.optString("state", "unknown"),
            isIncoming = json.optBoolean("isIncoming"),
            createdAt = json.optLong("createdAt"),
            updatedAt = json.optLong("updatedAt"),
            isLive = json.optBoolean("isLive"),
            pendingEventCount = json.optInt("pendingEventCount"),
            phoneNumber = json.optString("phoneNumber").nullIfEmpty(),
            displayName = json.optString("displayName").nullIfEmpty(),
            disconnectCause = json.optString("disconnectCause").nullIfEmpty(),
        )

        // optString returns "null" for JSONObject.NULL — treat it the same as blank.
        private fun String.nullIfEmpty(): String? =
            takeIf { it.isNotBlank() && it != "null" }
    }
}

internal data class PendingCallEvent(
    val eventId: String,
    val callId: String,
    val payload: Map<String, Any?>,
    val createdAt: Long,
    val inFlightAt: Long? = null,
) {
    fun toJson(): JSONObject = JSONObject(
        mapOf(
            "eventId" to eventId,
            "callId" to callId,
            "payload" to JSONObject(payload),
            "createdAt" to createdAt,
            "inFlightAt" to inFlightAt,
        ),
    )

    companion object {
        fun fromJson(json: JSONObject): PendingCallEvent = PendingCallEvent(
            eventId = json.optString("eventId"),
            callId = json.optString("callId"),
            payload = jsonObjectToMap(json.optJSONObject("payload") ?: JSONObject()),
            createdAt = json.optLong("createdAt"),
            inFlightAt = json.optLong("inFlightAt").takeIf { it > 0L },
        )
    }
}

internal data class BackgroundHandlerConfig(
    val dispatcherHandle: Long,
    val userHandle: Long,
)

internal enum class CallControlStatus {
    success,
    requested,
    notFound,
    notAttached,
    permissionDenied,
    platformFailure,
    invalidArguments,
}

internal data class CallControlResult(
    val status: CallControlStatus,
    val message: String? = null,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "status" to status.name,
        "message" to message,
    )
}

internal fun Call.detailsPhoneNumber(): String? = details?.handle?.toNormalizedPhoneNumber()

internal fun Uri.toNormalizedPhoneNumber(): String? {
    val value = schemeSpecificPart ?: return null
    return value.ifBlank { null }
}

internal fun Call.isIncomingCall(): Boolean {
    val details = details
    if (details != null) {
        when (details.callDirection) {
            Call.Details.DIRECTION_INCOMING -> return true
            Call.Details.DIRECTION_OUTGOING -> return false
        }
    }

    return state == Call.STATE_RINGING
}

internal fun stateToString(state: Int): String = when (state) {
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

internal fun disconnectCauseToString(disconnectCause: DisconnectCause?): String? {
    if (disconnectCause == null) {
        return null
    }

    return listOfNotNull(
        disconnectCause.reason?.takeIf { it.isNotBlank() },
        disconnectCause.label?.toString()?.takeIf { it.isNotBlank() },
        disconnectCause.description?.toString()?.takeIf { it.isNotBlank() },
        disconnectCause.toString().takeIf {
            it.isNotBlank() && it != disconnectCause.javaClass.name
        },
    ).firstOrNull()
}

internal fun jsonObjectToMap(json: JSONObject): Map<String, Any?> {
    val map = linkedMapOf<String, Any?>()
    val keys = json.keys()
    while (keys.hasNext()) {
        val key = keys.next()
        val value = json.opt(key)
        map[key] = when (value) {
            JSONObject.NULL -> null
            is JSONObject -> jsonObjectToMap(value)
            else -> value
        }
    }
    return map
}

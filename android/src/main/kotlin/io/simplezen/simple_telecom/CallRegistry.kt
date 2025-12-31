package io.simplezen.simple_telephony

import android.telecom.Call
import android.telecom.VideoProfile
import android.util.Log
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

internal object CallRegistry {
    private const val TAG = "CallRegistry"

    enum class CallDirection {
        INCOMING,
        OUTGOING
    }

    data class Entry(
        val call: Call,
        val id: String,
        val direction: CallDirection,
    )

    private val idByCall = ConcurrentHashMap<Call, String>()
    private val entries = ConcurrentHashMap<String, Entry>()

    fun register(call: Call): Entry {
        val existingId = idByCall[call]
        if (existingId != null) {
            return entries[existingId] ?: createEntry(call, existingId)
        }

        val callId = resolveCallId(call)
        val direction = resolveDirection(call)
        val entry = Entry(call = call, id = callId, direction = direction)
        idByCall[call] = callId
        entries[callId] = entry
        return entry
    }

    fun entryFor(call: Call): Entry? {
        val id = idByCall[call] ?: return null
        return entries[id]
    }

    fun entryFor(callId: String): Entry? = entries[callId]

    fun unregister(call: Call): Entry? {
        val id = idByCall.remove(call) ?: return null
        return entries.remove(id)
    }

    fun updateDirection(call: Call, direction: CallDirection) {
        val id = idByCall[call] ?: return
        val existing = entries[id] ?: return
        entries[id] = existing.copy(direction = direction)
    }

    fun answer(callId: String): Boolean {
        val entry = entries[callId]
        if (entry == null) {
            Log.w(TAG, "Attempted to answer unknown callId: $callId")
            return false
        }
        return try {
            entry.call.answer(VideoProfile.STATE_AUDIO_ONLY)
            true
        } catch (t: Throwable) {
            Log.e(TAG, "Failed answering call $callId", t)
            false
        }
    }

    fun end(callId: String): Boolean {
        val entry = entries[callId]
        if (entry == null) {
            Log.w(TAG, "Attempted to end unknown callId: $callId")
            return false
        }
        return try {
            entry.call.disconnect()
            true
        } catch (t: Throwable) {
            Log.e(TAG, "Failed ending call $callId", t)
            false
        }
    }

    private fun createEntry(call: Call, id: String): Entry {
        val direction = resolveDirection(call)
        val entry = Entry(call = call, id = id, direction = direction)
        entries[id] = entry
        return entry
    }

    private fun resolveCallId(call: Call): String {
        val details = call.details
        if (details != null) {
            details.handle?.let { handle ->
                val schemeSpecific = handle.schemeSpecificPart
                if (!schemeSpecific.isNullOrBlank()) {
                    return schemeSpecific + "-" + UUID.randomUUID().toString()
                }
            }
        }
        return UUID.randomUUID().toString()
    }

    private fun resolveDirection(call: Call): CallDirection {
        return when (call.state) {
            Call.STATE_RINGING -> CallDirection.INCOMING
            Call.STATE_CONNECTING,
            Call.STATE_DIALING,
            Call.STATE_NEW -> CallDirection.OUTGOING
            else -> CallDirection.OUTGOING
        }
    }
}

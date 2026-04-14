package io.simplezen.simple_telecom

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

internal class CallStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // In-memory caches — populated on first read, invalidated on write.
    // All public methods are @Synchronized so these are thread-safe.
    private var cachedCallRecords: MutableMap<String, CallSessionRecord>? = null
    private var cachedBackgroundEvents: MutableList<PendingCallEvent>? = null

    init {
        ensureSchemaVersion()
    }

    @Synchronized
    fun saveBackgroundHandlerConfig(config: BackgroundHandlerConfig) {
        prefs.edit()
            .putLong(KEY_DISPATCHER_HANDLE, config.dispatcherHandle)
            .putLong(KEY_USER_HANDLE, config.userHandle)
            .apply()
    }

    @Synchronized
    fun getBackgroundHandlerConfig(): BackgroundHandlerConfig? {
        if (!prefs.contains(KEY_DISPATCHER_HANDLE) || !prefs.contains(KEY_USER_HANDLE)) {
            return null
        }

        return BackgroundHandlerConfig(
            dispatcherHandle = prefs.getLong(KEY_DISPATCHER_HANDLE, 0L),
            userHandle = prefs.getLong(KEY_USER_HANDLE, 0L),
        )
    }

    @Synchronized
    fun getBackgroundUserHandle(): Long? {
        if (!prefs.contains(KEY_USER_HANDLE)) {
            return null
        }
        return prefs.getLong(KEY_USER_HANDLE, 0L)
    }

    @Synchronized
    fun getCurrentCalls(): List<CallSessionRecord> = readCallRecords().values
        .filter { it.isLive || it.pendingEventCount > 0 }
        .sortedByDescending { it.updatedAt }

    @Synchronized
    fun getCall(callId: String): CallSessionRecord? = readCallRecords()[callId]

    @Synchronized
    fun findReusableCallId(phoneNumber: String?, isIncoming: Boolean): String? {
        if (phoneNumber.isNullOrBlank()) {
            return null
        }

        return readCallRecords().values.firstOrNull {
            it.phoneNumber == phoneNumber &&
                it.isIncoming == isIncoming &&
                it.isLive &&
                it.state != "disconnected" &&
                it.state != "disconnecting"
        }?.callId
    }

    @Synchronized
    fun upsertCall(record: CallSessionRecord) {
        val records = readCallRecords()
        records[record.callId] = record
        writeCallRecords(records.values.toList())
    }

    @Synchronized
    fun enqueueBackgroundEvent(event: PendingCallEvent) {
        val events = readBackgroundEvents()
        events.add(event)
        writeBackgroundEvents(events)

        val record = getCall(event.callId)
        if (record != null) {
            upsertCall(record.copy(pendingEventCount = record.pendingEventCount + 1))
        }
    }

    @Synchronized
    fun claimPendingBackgroundEvents(
        now: Long = System.currentTimeMillis(),
    ): List<PendingCallEvent> {
        resetExpiredInFlightBackgroundEvents(now)
        val events = readBackgroundEvents()
        val claimed = mutableListOf<PendingCallEvent>()

        for (index in events.indices) {
            val event = events[index]
            if (event.inFlightAt != null) {
                continue
            }

            val claimedEvent = event.copy(inFlightAt = now)
            events[index] = claimedEvent
            claimed += claimedEvent
        }

        if (claimed.isNotEmpty()) {
            writeBackgroundEvents(events)
        }

        return claimed
    }

    @Synchronized
    fun acknowledgeBackgroundEvent(eventId: String) {
        val events = readBackgroundEvents()
        val event = events.firstOrNull { it.eventId == eventId } ?: return
        events.removeAll { it.eventId == eventId }
        writeBackgroundEvents(events)

        val record = getCall(event.callId)
        if (record != null) {
            upsertCall(
                record.copy(
                    pendingEventCount = maxOf(0, record.pendingEventCount - 1),
                ),
            )
        }
    }

    @Synchronized
    fun resetExpiredInFlightBackgroundEvents(now: Long = System.currentTimeMillis()) {
        val events = readBackgroundEvents()
        var changed = false

        for (index in events.indices) {
            val event = events[index]
            val inFlightAt = event.inFlightAt ?: continue
            if (now - inFlightAt < BACKGROUND_EVENT_LEASE_MS) {
                continue
            }

            events[index] = event.copy(inFlightAt = null)
            changed = true
        }

        if (changed) {
            writeBackgroundEvents(events)
        }
    }

    @Synchronized
    fun queuedBackgroundEventCount(callId: String): Int =
        readBackgroundEvents().count { it.callId == callId }

    private fun ensureSchemaVersion() {
        val storedVersion = prefs.getInt(KEY_SCHEMA_VERSION, 0)
        if (storedVersion == STORE_SCHEMA_VERSION) {
            return
        }

        prefs.edit()
            .remove(KEY_CALLS)
            .remove(KEY_BACKGROUND_EVENTS)
            .remove(KEY_DISPATCHER_HANDLE)
            .remove(KEY_USER_HANDLE)
            .putInt(KEY_SCHEMA_VERSION, STORE_SCHEMA_VERSION)
            .apply()

        cachedCallRecords = null
        cachedBackgroundEvents = null
    }

    private fun readCallRecords(): MutableMap<String, CallSessionRecord> {
        cachedCallRecords?.let { return it }

        val raw = prefs.getString(KEY_CALLS, null)
        if (raw == null) {
            val empty = linkedMapOf<String, CallSessionRecord>()
            cachedCallRecords = empty
            return empty
        }
        return try {
            val array = JSONArray(raw)
            val records = linkedMapOf<String, CallSessionRecord>()
            for (index in 0 until array.length()) {
                val record = CallSessionRecord.fromJson(array.getJSONObject(index))
                records[record.callId] = record
            }
            cachedCallRecords = records
            records
        } catch (error: JSONException) {
            Log.w(TAG, "Discarding corrupt call record store", error)
            prefs.edit().remove(KEY_CALLS).apply()
            val empty = linkedMapOf<String, CallSessionRecord>()
            cachedCallRecords = empty
            empty
        }
    }

    private fun writeCallRecords(records: List<CallSessionRecord>) {
        val trimmed = records.sortedByDescending { it.updatedAt }.take(MAX_CALL_RECORDS)
        val map = linkedMapOf<String, CallSessionRecord>()
        trimmed.forEach { map[it.callId] = it }
        cachedCallRecords = map

        val array = JSONArray()
        trimmed.forEach { record -> array.put(record.toJson()) }
        prefs.edit().putString(KEY_CALLS, array.toString()).apply()
    }

    private fun readBackgroundEvents(): MutableList<PendingCallEvent> {
        cachedBackgroundEvents?.let { return it }

        val raw = prefs.getString(KEY_BACKGROUND_EVENTS, null)
        if (raw == null) {
            val empty = mutableListOf<PendingCallEvent>()
            cachedBackgroundEvents = empty
            return empty
        }
        return try {
            val array = JSONArray(raw)
            val events = mutableListOf<PendingCallEvent>()
            for (index in 0 until array.length()) {
                events.add(PendingCallEvent.fromJson(array.getJSONObject(index)))
            }
            cachedBackgroundEvents = events
            events
        } catch (error: JSONException) {
            Log.w(TAG, "Discarding corrupt background event store", error)
            prefs.edit().remove(KEY_BACKGROUND_EVENTS).apply()
            val empty = mutableListOf<PendingCallEvent>()
            cachedBackgroundEvents = empty
            empty
        }
    }

    private fun writeBackgroundEvents(events: List<PendingCallEvent>) {
        val trimmed = events.sortedBy { it.createdAt }.takeLast(MAX_PENDING_EVENTS)
        cachedBackgroundEvents = trimmed.toMutableList()

        val array = JSONArray()
        trimmed.forEach { event -> array.put(event.toJson()) }
        prefs.edit().putString(KEY_BACKGROUND_EVENTS, array.toString()).apply()
    }

    companion object {
        private const val TAG = "CallStore"
        private const val PREFS_NAME = "simple_telephony_store"
        private const val KEY_SCHEMA_VERSION = "store_schema_version"
        private const val KEY_CALLS = "call_records"
        private const val KEY_BACKGROUND_EVENTS = "background_events"
        private const val KEY_DISPATCHER_HANDLE = "background_dispatcher_handle"
        private const val KEY_USER_HANDLE = "background_user_handle"

        // Bump this to clear all persisted state on upgrade. Old data is wiped,
        // not migrated — acceptable because call records are transient.
        private const val STORE_SCHEMA_VERSION = 2

        // How long a background event stays "in flight" before we assume the
        // handler crashed and make it claimable again. 30 s is generous for a
        // Dart callback; if the handler takes longer, the event may be delivered
        // twice (at-least-once, not exactly-once).
        private const val BACKGROUND_EVENT_LEASE_MS = 30_000L

        // Caps to prevent SharedPreferences from growing without bound.
        // 32 call records ≈ 32 concurrent calls (well beyond real-world).
        // 128 events ≈ ~4 state changes × 32 calls worth of queued events.
        private const val MAX_CALL_RECORDS = 32
        private const val MAX_PENDING_EVENTS = 128
    }
}

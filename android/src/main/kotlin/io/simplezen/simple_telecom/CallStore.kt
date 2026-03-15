package io.simplezen.simple_telecom

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

internal class CallStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

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
                it.state != "disconnected"
        }?.callId
    }

    @Synchronized
    fun upsertCall(record: CallSessionRecord) {
        val records = readCallRecords().toMutableMap()
        records[record.callId] = record
        writeCallRecords(records.values.toList())
    }

    @Synchronized
    fun enqueuePendingEvent(event: PendingCallEvent) {
        val events = readPendingEvents().toMutableList()
        events.add(event)
        writePendingEvents(events)

        val record = getCall(event.callId)
        if (record != null) {
            upsertCall(record.copy(pendingEventCount = record.pendingEventCount + 1))
        }
    }

    @Synchronized
    fun pendingEvents(): List<PendingCallEvent> = readPendingEvents()

    @Synchronized
    fun acknowledgePendingEvent(eventId: String) {
        val events = readPendingEvents().toMutableList()
        val event = events.firstOrNull { it.eventId == eventId } ?: return
        events.removeAll { it.eventId == eventId }
        writePendingEvents(events)

        val record = getCall(event.callId)
        if (record != null) {
            upsertCall(
                record.copy(
                    pendingEventCount = maxOf(0, record.pendingEventCount - 1),
                ),
            )
        }
    }

    private fun readCallRecords(): Map<String, CallSessionRecord> {
        val raw = prefs.getString(KEY_CALLS, null) ?: return emptyMap()
        val array = JSONArray(raw)
        val records = linkedMapOf<String, CallSessionRecord>()
        for (index in 0 until array.length()) {
            val record = CallSessionRecord.fromJson(array.getJSONObject(index))
            records[record.callId] = record
        }
        return records
    }

    private fun writeCallRecords(records: List<CallSessionRecord>) {
        val array = JSONArray()
        records
            .sortedByDescending { it.updatedAt }
            .take(MAX_CALL_RECORDS)
            .forEach { record ->
                array.put(record.toJson())
            }
        prefs.edit().putString(KEY_CALLS, array.toString()).apply()
    }

    private fun readPendingEvents(): List<PendingCallEvent> {
        val raw = prefs.getString(KEY_PENDING_EVENTS, null) ?: return emptyList()
        val array = JSONArray(raw)
        return buildList {
            for (index in 0 until array.length()) {
                add(PendingCallEvent.fromJson(array.getJSONObject(index)))
            }
        }
    }

    private fun writePendingEvents(events: List<PendingCallEvent>) {
        val array = JSONArray()
        events
            .sortedBy { it.createdAt }
            .takeLast(MAX_PENDING_EVENTS)
            .forEach { event ->
                array.put(event.toJson())
            }
        prefs.edit().putString(KEY_PENDING_EVENTS, array.toString()).apply()
    }

    companion object {
        private const val PREFS_NAME = "simple_telephony_store"
        private const val KEY_CALLS = "call_records"
        private const val KEY_PENDING_EVENTS = "pending_events"
        private const val KEY_DISPATCHER_HANDLE = "background_dispatcher_handle"
        private const val KEY_USER_HANDLE = "background_user_handle"
        private const val MAX_CALL_RECORDS = 32
        private const val MAX_PENDING_EVENTS = 128
    }
}

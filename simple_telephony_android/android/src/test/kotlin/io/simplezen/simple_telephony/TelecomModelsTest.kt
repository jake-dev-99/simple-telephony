package io.simplezen.simple_telephony

import android.telecom.Call
import android.telecom.DisconnectCause
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class TelecomModelsTest {

    // -------------------------------------------------------------------------
    // stateToString
    // -------------------------------------------------------------------------

    @Test
    fun `stateToString maps all known Call states`() {
        assertEquals("new", stateToString(Call.STATE_NEW))
        assertEquals("ringing", stateToString(Call.STATE_RINGING))
        assertEquals("dialing", stateToString(Call.STATE_DIALING))
        assertEquals("connecting", stateToString(Call.STATE_CONNECTING))
        assertEquals("active", stateToString(Call.STATE_ACTIVE))
        assertEquals("holding", stateToString(Call.STATE_HOLDING))
        assertEquals("disconnecting", stateToString(Call.STATE_DISCONNECTING))
        assertEquals("disconnected", stateToString(Call.STATE_DISCONNECTED))
    }

    @Test
    fun `stateToString returns unknown for unrecognized state`() {
        assertEquals("unknown", stateToString(9999))
        assertEquals("unknown", stateToString(-1))
    }

    // -------------------------------------------------------------------------
    // disconnectCauseToString
    // -------------------------------------------------------------------------

    @Test
    fun `disconnectCauseToString returns null for null input`() {
        assertNull(disconnectCauseToString(null))
    }

    @Test
    fun `disconnectCauseToString prefers reason when available`() {
        val cause = DisconnectCause(DisconnectCause.REMOTE, "Label", "Description", "Reason")
        val result = disconnectCauseToString(cause)
        assertEquals("Reason", result)
    }

    @Test
    fun `disconnectCauseToString falls back to label when reason is blank`() {
        val cause = DisconnectCause(DisconnectCause.LOCAL, "Busy", "User is busy", "")
        val result = disconnectCauseToString(cause)
        assertEquals("Busy", result)
    }

    // -------------------------------------------------------------------------
    // CallSessionRecord serialization
    // -------------------------------------------------------------------------

    @Test
    fun `CallSessionRecord roundtrips through JSON`() {
        val original = CallSessionRecord(
            callId = "call-1",
            state = "active",
            isIncoming = true,
            createdAt = 1_700_000_000_000L,
            updatedAt = 1_700_000_001_000L,
            isLive = true,
            pendingEventCount = 3,
            phoneNumber = "+15551234567",
            displayName = "Alice",
            disconnectCause = null,
        )

        val json = original.toJson()
        val restored = CallSessionRecord.fromJson(json)

        assertEquals(original.callId, restored.callId)
        assertEquals(original.state, restored.state)
        assertEquals(original.isIncoming, restored.isIncoming)
        assertEquals(original.createdAt, restored.createdAt)
        assertEquals(original.updatedAt, restored.updatedAt)
        assertEquals(original.isLive, restored.isLive)
        assertEquals(original.pendingEventCount, restored.pendingEventCount)
        assertEquals(original.phoneNumber, restored.phoneNumber)
        assertEquals(original.displayName, restored.displayName)
        assertEquals(original.disconnectCause, restored.disconnectCause)
    }

    @Test
    fun `CallSessionRecord fromJson handles missing optional fields`() {
        val json = JSONObject().apply {
            put("callId", "c")
            put("state", "ringing")
            put("isIncoming", true)
            put("createdAt", 1L)
            put("updatedAt", 2L)
            put("isLive", true)
            put("pendingEventCount", 0)
        }

        val record = CallSessionRecord.fromJson(json)

        assertNull(record.phoneNumber)
        assertNull(record.displayName)
        assertNull(record.disconnectCause)
    }

    @Test
    fun `CallSessionRecord fromJson treats blank strings as null`() {
        val json = JSONObject().apply {
            put("callId", "c")
            put("phoneNumber", "")
            put("displayName", "  ")
            put("disconnectCause", "")
        }

        val record = CallSessionRecord.fromJson(json)

        assertNull(record.phoneNumber)
        assertNull(record.displayName)
        assertNull(record.disconnectCause)
    }

    @Test
    fun `CallSessionRecord toMap includes all fields`() {
        val record = CallSessionRecord(
            callId = "c",
            state = "s",
            isIncoming = false,
            createdAt = 1L,
            updatedAt = 2L,
            isLive = false,
            pendingEventCount = 0,
            phoneNumber = "+1",
            displayName = "Bob",
            disconnectCause = "remote",
        )

        val map = record.toMap()

        assertEquals("c", map["callId"])
        assertEquals("s", map["state"])
        assertEquals(false, map["isIncoming"])
        assertEquals(1L, map["createdAt"])
        assertEquals(2L, map["updatedAt"])
        assertEquals(false, map["isLive"])
        assertEquals(0, map["pendingEventCount"])
        assertEquals("+1", map["phoneNumber"])
        assertEquals("Bob", map["displayName"])
        assertEquals("remote", map["disconnectCause"])
    }

    // -------------------------------------------------------------------------
    // PendingCallEvent serialization
    // -------------------------------------------------------------------------

    @Test
    fun `PendingCallEvent roundtrips through JSON`() {
        val original = PendingCallEvent(
            eventId = "evt-1",
            callId = "call-1",
            payload = mapOf("callId" to "call-1", "state" to "ringing"),
            createdAt = 100L,
            inFlightAt = 200L,
        )

        val json = original.toJson()
        val restored = PendingCallEvent.fromJson(json)

        assertEquals(original.eventId, restored.eventId)
        assertEquals(original.callId, restored.callId)
        assertEquals(original.createdAt, restored.createdAt)
        assertEquals(original.inFlightAt, restored.inFlightAt)
    }

    @Test
    fun `PendingCallEvent fromJson treats zero inFlightAt as null`() {
        val json = JSONObject().apply {
            put("eventId", "e")
            put("callId", "c")
            put("payload", JSONObject())
            put("createdAt", 10L)
            put("inFlightAt", 0L)
        }

        val event = PendingCallEvent.fromJson(json)

        assertNull(event.inFlightAt)
    }

    // -------------------------------------------------------------------------
    // CallControlResult
    // -------------------------------------------------------------------------

    @Test
    fun `CallControlResult toMap serializes status name and message`() {
        val result = CallControlResult(CallControlStatus.notAttached, "gone")
        val map = result.toMap()

        assertEquals("notAttached", map["status"])
        assertEquals("gone", map["message"])
    }

    @Test
    fun `CallControlResult toMap includes null message`() {
        val result = CallControlResult(CallControlStatus.success)
        val map = result.toMap()

        assertEquals("success", map["status"])
        assertNull(map["message"])
    }

    // -------------------------------------------------------------------------
    // jsonObjectToMap
    // -------------------------------------------------------------------------

    @Test
    fun `jsonObjectToMap handles nested objects and null values`() {
        val json = JSONObject().apply {
            put("key", "value")
            put("nested", JSONObject().apply { put("inner", 42) })
            put("nullable", JSONObject.NULL)
        }

        val map = jsonObjectToMap(json)

        assertEquals("value", map["key"])
        assertEquals(42, (map["nested"] as Map<*, *>)["inner"])
        assertNull(map["nullable"])
    }

    @Test
    fun `jsonObjectToMap handles empty object`() {
        val map = jsonObjectToMap(JSONObject())
        assertEquals(0, map.size)
    }
}

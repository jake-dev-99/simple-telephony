package io.simplezen.simple_telephony

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class CallStoreTest {
    private lateinit var context: Context
    private lateinit var prefs: android.content.SharedPreferences

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        prefs = context.getSharedPreferences("simple_telephony_store", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
    }

    @Test
    fun `claiming pending background events marks them in flight once`() {
        val store = CallStore(context)
        seedCall(store, "call-1")
        store.enqueueBackgroundEvent(
            PendingCallEvent(
                eventId = "evt-1",
                callId = "call-1",
                payload = mapOf("callId" to "call-1"),
                createdAt = 10L,
            ),
        )

        val firstClaim = store.claimPendingBackgroundEvents(now = 100L)
        val secondClaim = store.claimPendingBackgroundEvents(now = 101L)

        assertEquals(1, firstClaim.size)
        assertEquals(100L, firstClaim.single().inFlightAt)
        assertTrue(secondClaim.isEmpty())
        assertEquals(1, store.getCall("call-1")?.pendingEventCount)
    }

    @Test
    fun `acknowledging background event removes it and decrements pending count`() {
        val store = CallStore(context)
        seedCall(store, "call-1")
        store.enqueueBackgroundEvent(
            PendingCallEvent(
                eventId = "evt-1",
                callId = "call-1",
                payload = mapOf("callId" to "call-1"),
                createdAt = 10L,
            ),
        )
        store.claimPendingBackgroundEvents(now = 100L)

        store.acknowledgeBackgroundEvent("evt-1")

        assertTrue(store.claimPendingBackgroundEvents(now = 101L).isEmpty())
        assertEquals(0, store.getCall("call-1")?.pendingEventCount)
    }

    @Test
    fun `expired in-flight background events become claimable again`() {
        val store = CallStore(context)
        seedCall(store, "call-1")
        store.enqueueBackgroundEvent(
            PendingCallEvent(
                eventId = "evt-1",
                callId = "call-1",
                payload = mapOf("callId" to "call-1"),
                createdAt = 10L,
            ),
        )

        store.claimPendingBackgroundEvents(now = 100L)

        val reclaimed = store.claimPendingBackgroundEvents(now = 30_101L)

        assertEquals(1, reclaimed.size)
        assertEquals(30_101L, reclaimed.single().inFlightAt)
    }

    @Test
    fun `corrupt persisted blobs are discarded instead of crashing`() {
        prefs.edit()
            .putInt("store_schema_version", 2)
            .putString("call_records", "{broken")
            .putString("background_events", "{broken")
            .commit()

        val store = CallStore(context)

        assertTrue(store.getCurrentCalls().isEmpty())
        assertTrue(store.claimPendingBackgroundEvents(now = 100L).isEmpty())
        assertNull(prefs.getString("call_records", null))
        assertNull(prefs.getString("background_events", null))
    }

    @Test
    fun `schema mismatch clears incompatible stored state`() {
        prefs.edit()
            .putInt("store_schema_version", 1)
            .putString("call_records", "[]")
            .putString("background_events", "[]")
            .putLong("background_dispatcher_handle", 1L)
            .putLong("background_user_handle", 2L)
            .commit()

        val store = CallStore(context)

        assertEquals(2, prefs.getInt("store_schema_version", 0))
        assertNull(prefs.getString("call_records", null))
        assertNull(prefs.getString("background_events", null))
        assertNull(store.getBackgroundHandlerConfig())
    }

    // -------------------------------------------------------------------------
    // findReusableCallId
    // -------------------------------------------------------------------------

    @Test
    fun `findReusableCallId returns null for blank phone number`() {
        val store = CallStore(context)
        seedCall(store, "call-1", phoneNumber = "+1555")

        assertNull(store.findReusableCallId(null, isIncoming = true))
        assertNull(store.findReusableCallId("", isIncoming = true))
        assertNull(store.findReusableCallId("  ", isIncoming = true))
    }

    @Test
    fun `findReusableCallId matches same number and direction`() {
        val store = CallStore(context)
        seedCall(store, "call-1", phoneNumber = "+1555", isIncoming = true)

        assertEquals("call-1", store.findReusableCallId("+1555", isIncoming = true))
    }

    @Test
    fun `findReusableCallId does not match different direction`() {
        val store = CallStore(context)
        seedCall(store, "call-1", phoneNumber = "+1555", isIncoming = true)

        assertNull(store.findReusableCallId("+1555", isIncoming = false))
    }

    @Test
    fun `findReusableCallId does not match different phone number`() {
        val store = CallStore(context)
        seedCall(store, "call-1", phoneNumber = "+1555", isIncoming = true)

        assertNull(store.findReusableCallId("+9999", isIncoming = true))
    }

    @Test
    fun `findReusableCallId excludes disconnected calls`() {
        val store = CallStore(context)
        store.upsertCall(
            CallSessionRecord(
                callId = "call-1",
                state = "disconnected",
                isIncoming = true,
                createdAt = 1L,
                updatedAt = 1L,
                isLive = true,
                pendingEventCount = 0,
                phoneNumber = "+1555",
            ),
        )

        assertNull(store.findReusableCallId("+1555", isIncoming = true))
    }

    @Test
    fun `findReusableCallId excludes disconnecting calls`() {
        val store = CallStore(context)
        store.upsertCall(
            CallSessionRecord(
                callId = "call-1",
                state = "disconnecting",
                isIncoming = true,
                createdAt = 1L,
                updatedAt = 1L,
                isLive = true,
                pendingEventCount = 0,
                phoneNumber = "+1555",
            ),
        )

        assertNull(store.findReusableCallId("+1555", isIncoming = true))
    }

    @Test
    fun `findReusableCallId excludes non-live calls`() {
        val store = CallStore(context)
        store.upsertCall(
            CallSessionRecord(
                callId = "call-1",
                state = "ringing",
                isIncoming = true,
                createdAt = 1L,
                updatedAt = 1L,
                isLive = false,
                pendingEventCount = 0,
                phoneNumber = "+1555",
            ),
        )

        assertNull(store.findReusableCallId("+1555", isIncoming = true))
    }

    // -------------------------------------------------------------------------
    // getCurrentCalls
    // -------------------------------------------------------------------------

    @Test
    fun `getCurrentCalls returns only live or pending-event calls`() {
        val store = CallStore(context)
        // Live call — should be included
        seedCall(store, "call-live")
        // Dead call with no pending events — should be excluded
        store.upsertCall(
            CallSessionRecord(
                callId = "call-dead",
                state = "disconnected",
                isIncoming = false,
                createdAt = 1L,
                updatedAt = 1L,
                isLive = false,
                pendingEventCount = 0,
            ),
        )
        // Dead call with pending events — should be included
        store.upsertCall(
            CallSessionRecord(
                callId = "call-pending",
                state = "disconnected",
                isIncoming = true,
                createdAt = 1L,
                updatedAt = 2L,
                isLive = false,
                pendingEventCount = 1,
            ),
        )

        val calls = store.getCurrentCalls()
        val ids = calls.map { it.callId }.toSet()

        assertTrue(ids.contains("call-live"))
        assertTrue(ids.contains("call-pending"))
        assertFalse(ids.contains("call-dead"))
    }

    // -------------------------------------------------------------------------
    // Max record cap
    // -------------------------------------------------------------------------

    @Test
    fun `upsertCall trims to max 32 records`() {
        val store = CallStore(context)
        for (i in 1..40) {
            store.upsertCall(
                CallSessionRecord(
                    callId = "call-$i",
                    state = "active",
                    isIncoming = true,
                    createdAt = i.toLong(),
                    updatedAt = i.toLong(),
                    isLive = true,
                    pendingEventCount = 0,
                ),
            )
        }

        // The 32 most recently updated should survive
        assertNull(store.getCall("call-1"))
        assertNotNull(store.getCall("call-40"))
        assertNotNull(store.getCall("call-9"))
    }

    // -------------------------------------------------------------------------
    // Background handler config
    // -------------------------------------------------------------------------

    @Test
    fun `background handler config roundtrips through store`() {
        val store = CallStore(context)

        assertNull(store.getBackgroundHandlerConfig())
        assertNull(store.getBackgroundUserHandle())

        store.saveBackgroundHandlerConfig(
            BackgroundHandlerConfig(dispatcherHandle = 111L, userHandle = 222L),
        )

        val config = store.getBackgroundHandlerConfig()
        assertNotNull(config)
        assertEquals(111L, config!!.dispatcherHandle)
        assertEquals(222L, config.userHandle)
        assertEquals(222L, store.getBackgroundUserHandle())
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private fun seedCall(
        store: CallStore,
        callId: String,
        phoneNumber: String? = null,
        isIncoming: Boolean = true,
    ) {
        store.upsertCall(
            CallSessionRecord(
                callId = callId,
                state = "ringing",
                isIncoming = isIncoming,
                createdAt = 1L,
                updatedAt = 1L,
                isLive = true,
                pendingEventCount = 0,
                phoneNumber = phoneNumber,
            ),
        )
        assertNotNull(store.getCall(callId))
    }
}

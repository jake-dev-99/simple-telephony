package io.simplezen.simple_telephony

import android.telecom.Call
import android.telecom.InCallService
import android.util.Log

internal class SimpleTelecomInCallService : InCallService() {
    private val callCallback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            super.onStateChanged(call, state)
            val entry = CallRegistry.entryFor(call) ?: CallRegistry.register(call)
            CallEventDispatcher.onCallStateChanged(applicationContext, entry, state)
        }

        override fun onDetailsChanged(call: Call, details: Call.Details) {
            super.onDetailsChanged(call, details)
            CallRegistry.entryFor(call)
            val direction = when (call.state) {
                Call.STATE_RINGING -> CallRegistry.CallDirection.INCOMING
                else -> CallRegistry.CallDirection.OUTGOING
            }
            CallRegistry.updateDirection(call, direction)
        }

        override fun onCallDestroyed(call: Call) {
            super.onCallDestroyed(call)
            val entry = CallRegistry.unregister(call)
            CallEventDispatcher.onCallRemoved(applicationContext, entry, call.details?.disconnectCause)
        }
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        Log.d(TAG, "Call added: ${call.details}")
        val entry = CallRegistry.register(call)
        call.registerCallback(callCallback)
        CallEventDispatcher.onCallAdded(applicationContext, entry)
    }

    override fun onCallRemoved(call: Call) {
        val entry = CallRegistry.unregister(call)
        CallEventDispatcher.onCallRemoved(applicationContext, entry, call.details?.disconnectCause)
        call.unregisterCallback(callCallback)
        super.onCallRemoved(call)
    }

    companion object {
        private const val TAG = "SimpleTelecomService"
    }
}

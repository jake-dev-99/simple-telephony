package io.simplezen.simple_telecom

import android.telecom.Call
import android.telecom.InCallService
import android.util.Log

internal class SimpleTelecomInCallService : InCallService() {
    private val callCallback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            super.onStateChanged(call, state)
            TelecomServiceRuntime.onCallStateChanged(call, state)
        }

        override fun onDetailsChanged(call: Call, details: Call.Details) {
            super.onDetailsChanged(call, details)
            TelecomServiceRuntime.onCallDetailsChanged(call)
        }
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        Log.d(TAG, "Call added: ${call.details}")
        call.registerCallback(callCallback)
        TelecomServiceRuntime.initialize(applicationContext)
        TelecomServiceRuntime.onCallAdded(call)
    }

    override fun onCallRemoved(call: Call) {
        TelecomServiceRuntime.initialize(applicationContext)
        TelecomServiceRuntime.onCallRemoved(call, call.details?.disconnectCause)
        call.unregisterCallback(callCallback)
        super.onCallRemoved(call)
    }

    companion object {
        private const val TAG = "SimpleTelecomService"
    }
}

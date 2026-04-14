package io.simplezen.simple_telephony

import android.telecom.Call
import android.telecom.InCallService
import android.util.Log

internal class SimpleTelephonyInCallService : InCallService() {
    private val callCallback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            super.onStateChanged(call, state)
            if (!TelecomServiceRuntime.isInitialized) return
            TelecomServiceRuntime.onCallStateChanged(call, state)
        }

        override fun onDetailsChanged(call: Call, details: Call.Details) {
            super.onDetailsChanged(call, details)
            if (!TelecomServiceRuntime.isInitialized) return
            TelecomServiceRuntime.onCallDetailsChanged(call)
        }
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        Log.d(TAG, "Call added: ${call.details}")
        TelecomServiceRuntime.initialize(applicationContext)
        TelecomServiceRuntime.onCallAdded(call)
        // Register callback AFTER initialize + onCallAdded so the runtime
        // is fully initialised and the call is tracked before any
        // onStateChanged / onDetailsChanged can fire on another thread.
        call.registerCallback(callCallback)
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        TelecomServiceRuntime.initialize(applicationContext)
        TelecomServiceRuntime.onCallRemoved(call, call.details?.disconnectCause)
        call.unregisterCallback(callCallback)
    }

    companion object {
        private const val TAG = "SimpleTelephonyInCallService"
    }
}

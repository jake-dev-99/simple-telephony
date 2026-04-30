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
        Log.d(TAG, "Call added: state=${call.state}")
        TelecomServiceRuntime.initialize(applicationContext)
        // Register the state callback before taking the initial snapshot so
        // any state change that fires between the snapshot and the callback
        // hookup is still delivered. The callback's early-return guards handle
        // the case where runtime init has not completed yet.
        call.registerCallback(callCallback)
        TelecomServiceRuntime.onCallAdded(call)
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

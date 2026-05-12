package io.simplezen.simple_telephony

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.telecom.TelecomManager
import android.util.Log
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/// Focused on actual telephony operations (place, answer, end calls).
/// Dialer-role observation + request is out of scope for this plugin —
/// host apps handle that with whatever permissions helper they use
/// (`permission_handler`, `simple_permissions_native`, or a hand-rolled
/// `RoleManager` call).
internal class CallManager(private val context: Context) {
    private val telecomManager =
        context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager

    private var activityBinding: ActivityPluginBinding? = null

    fun attach(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    fun detach() {
        activityBinding = null
    }

    fun placeCall(phoneNumber: String): CallControlResult {
        return try {
            val uri = Uri.fromParts("tel", phoneNumber, null)
            telecomManager.placeCall(uri, Bundle())
            CallControlResult(CallControlStatus.requested)
        } catch (security: SecurityException) {
            Log.e(TAG, "Security exception placing call", security)
            CallControlResult(
                CallControlStatus.permissionDenied,
                security.message ?: "Permission denied placing call",
            )
        } catch (throwable: Throwable) {
            Log.e(TAG, "Unexpected error placing call", throwable)
            CallControlResult(
                CallControlStatus.platformFailure,
                throwable.message ?: "Unexpected error placing call",
            )
        }
    }

    fun answerCall(callId: String): CallControlResult =
        TelecomServiceRuntime.answerCall(callId)

    fun endCall(callId: String): CallControlResult =
        TelecomServiceRuntime.endCall(callId)

    companion object {
        private const val TAG = "CallManager"
    }
}

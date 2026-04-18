package io.simplezen.simple_telephony

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.telecom.TelecomManager
import android.util.Log
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/// Dialer role (`android.app.role.DIALER`) observation + request is
/// owned by `simple_permissions_native` — consumers call
/// `SimplePermissionsNative.instance.check(DefaultDialerApp())` or
/// `request(DefaultDialerApp())` / observe via `observe(...)`.
/// This class stays focused on actual telephony operations (place,
/// answer, end calls).
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

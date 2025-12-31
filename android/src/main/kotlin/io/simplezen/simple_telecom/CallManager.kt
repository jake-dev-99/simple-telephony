package io.simplezen.simple_telecom

import android.app.role.RoleManager
import android.content.Context
import android.content.Context.ROLE_SERVICE
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.telecom.TelecomManager
import android.util.Log
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

internal class CallManager(private val context: Context) {
    private val telecomManager =
        context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
    private val roleManager = context.getSystemService(ROLE_SERVICE) as RoleManager

    private var activityBinding: ActivityPluginBinding? = null
    private var requestRoleListener: PluginRegistry.ActivityResultListener? = null
    private var pendingRoleCallback: ((Boolean) -> Unit)? = null

    fun attach(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    fun detach() {
        requestRoleListener?.let { listener ->
            activityBinding?.removeActivityResultListener(listener)
        }
        requestRoleListener = null
        pendingRoleCallback = null
        activityBinding = null
    }

    fun placeCall(phoneNumber: String): Boolean {
        return try {
            val uri = Uri.fromParts("tel", phoneNumber, null)
            telecomManager.placeCall(uri, Bundle())
            true
        } catch (security: SecurityException) {
            Log.e(TAG, "Security exception placing call", security)
            false
        } catch (throwable: Throwable) {
            Log.e(TAG, "Unexpected error placing call", throwable)
            false
        }
    }

    fun answerCall(callId: String): Boolean = CallRegistry.answer(callId)

    fun endCall(callId: String): Boolean = CallRegistry.end(callId)

    fun isDefaultDialerApp(): Boolean {
        return telecomManager.defaultDialerPackage == context.packageName
    }

    fun requestDefaultDialerApp(callback: (Boolean) -> Unit) {
        if (!roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)) {
            callback(false)
            return
        }

        if (roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
            callback(true)
            return
        }

        val activity = activityBinding?.activity
        if (activity == null) {
            Log.w(TAG, "requestDefaultDialerApp called without an attached activity")
            callback(false)
            return
        }

        val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
        val requestCode = REQUEST_CODE_ROLE

        val listener = object : PluginRegistry.ActivityResultListener {
            override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
                if (requestCode != REQUEST_CODE_ROLE) {
                    return false
                }

                val granted = roleManager.isRoleHeld(RoleManager.ROLE_DIALER)
                synchronized(this@CallManager) {
                    pendingRoleCallback?.invoke(granted)
                    pendingRoleCallback = null
                }
                return true
            }
        }

        requestRoleListener?.let { existing ->
            activityBinding?.removeActivityResultListener(existing)
        }
        requestRoleListener = listener
        pendingRoleCallback = callback
        activityBinding?.addActivityResultListener(listener)

        try {
            activity.startActivityForResult(intent, REQUEST_CODE_ROLE)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to request default dialer role", t)
            synchronized(this) {
                pendingRoleCallback?.invoke(false)
                pendingRoleCallback = null
            }
        }
    }

    companion object {
        private const val TAG = "CallManager"
        private const val REQUEST_CODE_ROLE = 0x5317
    }
}

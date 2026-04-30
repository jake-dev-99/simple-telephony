package io.simplezen.simple_telephony

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles the `io.simplezen.simple_telephony/device_info` method channel.
 *
 * Returns device build metadata + active SIM card enumeration. These APIs
 * deliberately live outside the content-provider layer covered by
 * `simple_query` — they come from `android.os.Build` and
 * [SubscriptionManager], not from a [android.net.Uri].
 */
internal class DeviceInfoHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDeviceInfo" -> result.success(buildDeviceInfo())
            "listSimCards" -> result.success(listSimCards())
            else -> result.notImplemented()
        }
    }

    private fun buildDeviceInfo(): Map<String, Any?> {
        val simCount = countSimSlots()
        return mapOf(
            "model" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "androidVersion" to Build.VERSION.RELEASE,
            "androidSdkInt" to Build.VERSION.SDK_INT,
            "simSlotCount" to simCount,
            // deviceId intentionally omitted — getDeviceId() is hard-restricted
            // on modern Android. Callers that truly need it can extend the
            // host API under a carrier-privileged build.
            "deviceId" to null,
        )
    }

    @SuppressLint("MissingPermission")
    private fun listSimCards(): List<Map<String, Any?>> {
        if (!hasPhoneStatePermission()) return emptyList()
        val sm = subscriptionManager() ?: return emptyList()
        val defaultSmsSub = SubscriptionManager.getDefaultSmsSubscriptionId()
        val defaultVoiceSub = SubscriptionManager.getDefaultVoiceSubscriptionId()
        val subs: List<SubscriptionInfo> =
            sm.activeSubscriptionInfoList ?: emptyList()
        return subs.map { info ->
            val subId = info.subscriptionId
            mapOf<String, Any?>(
                "slotIndex" to info.simSlotIndex,
                "subscriptionId" to subId,
                "isDefault" to (subId == defaultSmsSub || subId == defaultVoiceSub),
                "carrierName" to info.carrierName?.toString(),
                "displayName" to info.displayName?.toString(),
                "number" to info.number,
                "countryIso" to info.countryIso,
                "mcc" to mccOrNull(info),
                "mnc" to mncOrNull(info),
            )
        }
    }

    private fun subscriptionManager(): SubscriptionManager? =
        context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE)
            as? SubscriptionManager

    /**
     * Read-only check used to short-circuit SIM enumeration without surfacing
     * a [SecurityException]. Host apps are responsible for requesting
     * `READ_PHONE_STATE` with whatever permissions helper they use
     * (`permission_handler`, `simple_permissions_native`, a hand-rolled
     * method-channel, …) — this plugin does not mandate a choice.
     */
    private fun hasPhoneStatePermission(): Boolean =
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_PHONE_STATE,
        ) == PackageManager.PERMISSION_GRANTED

    /** mccString was added in API 29; fall back to the deprecated int before that. */
    private fun mccOrNull(info: SubscriptionInfo): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            info.mccString
        } else {
            @Suppress("DEPRECATION")
            info.mcc.takeIf { it != 0 }?.toString()
        }

    private fun mncOrNull(info: SubscriptionInfo): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            info.mncString
        } else {
            @Suppress("DEPRECATION")
            info.mnc.takeIf { it != 0 }?.toString()
        }

    /**
     * Best-effort SIM slot count. Prefers the active subscription list when
     * permission is granted; falls back to `TelephonyManager.phoneCount` /
     * `activeModemCount` otherwise.
     */
    @SuppressLint("MissingPermission")
    private fun countSimSlots(): Int {
        if (hasPhoneStatePermission()) {
            val sm = subscriptionManager()
            val list = sm?.activeSubscriptionInfoList
            if (list != null) return list.size
        }
        val tm = context.getSystemService(Context.TELEPHONY_SERVICE)
            as? android.telephony.TelephonyManager
        if (tm != null) {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                tm.activeModemCount
            } else {
                @Suppress("DEPRECATION")
                tm.phoneCount
            }
        }
        return 0
    }
}

package io.simplezen.simple_telecom

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class TelecomMethodHandler(
    private val callManager: CallManager,
) : MethodChannel.MethodCallHandler {

    @Volatile
    private var pendingDialerRequest: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "placePhoneCall" -> {
                val phoneNumber = call.arguments as? String
                if (phoneNumber.isNullOrBlank()) {
                    result.error("invalid-args", "phoneNumber is required", null)
                    return
                }
                result.success(callManager.placeCall(phoneNumber))
            }

            "answerPhoneCall" -> {
                val callId = call.arguments as? String
                if (callId.isNullOrBlank()) {
                    result.error("invalid-args", "callId is required", null)
                    return
                }
                result.success(callManager.answerCall(callId))
            }

            "endPhoneCall" -> {
                val callId = call.arguments as? String
                if (callId.isNullOrBlank()) {
                    result.error("invalid-args", "callId is required", null)
                    return
                }
                result.success(callManager.endCall(callId))
            }

            "isDefaultDialerApp" -> {
                result.success(callManager.isDefaultDialerApp())
            }

            "requestDefaultDialerApp" -> {
                if (pendingDialerRequest != null) {
                    result.error("request-in-flight", "A dialer role request is already running", null)
                    return
                }
                pendingDialerRequest = result
                callManager.requestDefaultDialerApp { granted ->
                    synchronized(this) {
                        pendingDialerRequest?.success(granted)
                        pendingDialerRequest = null
                    }
                }
            }

            else -> result.notImplemented()
        }
    }
}

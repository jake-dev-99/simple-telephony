package io.simplezen.simple_telecom

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class TelecomMethodHandler(
    private val callManager: CallManager,
) : MethodChannel.MethodCallHandler {

    private var pendingDialerRequest: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "placePhoneCall" -> {
                val phoneNumber = call.arguments as? String
                if (phoneNumber.isNullOrBlank()) {
                    result.error("invalid-args", "phoneNumber is required", null)
                    return
                }
                result.success(callManager.placeCall(phoneNumber).toMap())
            }

            "answerPhoneCall" -> {
                val callId = call.arguments as? String
                if (callId.isNullOrBlank()) {
                    result.error("invalid-args", "callId is required", null)
                    return
                }
                result.success(callManager.answerCall(callId).toMap())
            }

            "endPhoneCall" -> {
                val callId = call.arguments as? String
                if (callId.isNullOrBlank()) {
                    result.error("invalid-args", "callId is required", null)
                    return
                }
                result.success(callManager.endCall(callId).toMap())
            }

            "isDefaultDialerApp" -> {
                result.success(callManager.isDefaultDialerApp())
            }

            "requestDefaultDialerApp" -> {
                synchronized(this) {
                    if (pendingDialerRequest != null) {
                        result.error("request-in-flight", "A dialer role request is already running", null)
                        return
                    }
                    pendingDialerRequest = result
                }
                callManager.requestDefaultDialerApp { granted ->
                    synchronized(this) {
                        pendingDialerRequest?.success(granted)
                        pendingDialerRequest = null
                    }
                }
            }

            "registerBackgroundHandler" -> {
                val arguments = call.arguments as? Map<*, *>
                val dispatcherHandle = (arguments?.get("dispatcherHandle") as? Number)?.toLong()
                val handlerHandle = (arguments?.get("handlerHandle") as? Number)?.toLong()
                if (dispatcherHandle == null || handlerHandle == null) {
                    result.error("invalid-args", "dispatcherHandle and handlerHandle are required", null)
                    return
                }

                TelecomServiceRuntime.registerBackgroundHandler(
                    dispatcherHandle = dispatcherHandle,
                    userHandle = handlerHandle,
                )
                result.success(null)
            }

            "getCurrentCalls" -> result.success(TelecomServiceRuntime.currentCalls())

            else -> result.notImplemented()
        }
    }
}

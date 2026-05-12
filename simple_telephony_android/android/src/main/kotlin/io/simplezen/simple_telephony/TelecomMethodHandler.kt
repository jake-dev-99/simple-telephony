package io.simplezen.simple_telephony

import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class TelecomMethodHandler(
    private val callManager: CallManager,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            dispatch(call, result)
        } catch (throwable: Throwable) {
            // Never let an exception escape the method handler — Dart's
            // invokeMethod future would never complete, deadlocking callers.
            Log.e(TAG, "Unhandled exception in ${call.method}", throwable)
            result.error(
                "platform-error",
                throwable.message ?: throwable.javaClass.simpleName,
                null,
            )
        }
    }

    private fun dispatch(call: MethodCall, result: MethodChannel.Result) {
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

            "registerBackgroundHandler" -> {
                val arguments = call.arguments as? Map<*, *>
                val dispatcherHandle = (arguments?.get("dispatcherHandle") as? Number)?.toLong()
                val handlerHandle = (arguments?.get("handlerHandle") as? Number)?.toLong()
                if (dispatcherHandle == null || handlerHandle == null) {
                    result.error(
                        "invalid-args",
                        "dispatcherHandle and handlerHandle are required",
                        null,
                    )
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

    companion object {
        private const val TAG = "TelecomMethodHandler"
    }
}

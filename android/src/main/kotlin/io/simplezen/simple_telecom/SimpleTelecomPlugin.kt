package io.simplezen.simple_telephony

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

class SimpleTelecomPlugin : FlutterPlugin, ActivityAware {

    private lateinit var applicationContext: Context
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var actionsChannel: MethodChannel? = null
    private var callManager: CallManager? = null
    private var methodHandler: TelecomMethodHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        InboundTelecom.initialize(applicationContext, binding.binaryMessenger)

        callManager = CallManager(applicationContext)
        methodHandler = TelecomMethodHandler(callManager!!)

        actionsChannel = MethodChannel(
            binding.binaryMessenger,
            "io.simplezen.simple_telephony/telecom_actions",
        ).also { channel ->
            channel.setMethodCallHandler(methodHandler)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        actionsChannel?.setMethodCallHandler(null)
        actionsChannel = null
        methodHandler = null
        callManager = null
        InboundTelecom.detach()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        callManager?.attach(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachActivity()
    }

    private fun detachActivity() {
        callManager?.detach()
        activityBinding = null
        activity = null
    }
}

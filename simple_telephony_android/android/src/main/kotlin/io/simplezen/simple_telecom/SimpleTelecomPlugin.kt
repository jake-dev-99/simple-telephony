package io.simplezen.simple_telecom

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

class SimpleTelecomPlugin : FlutterPlugin, ActivityAware {

    private lateinit var applicationContext: Context

    private var actionsChannel: MethodChannel? = null
    private var deviceInfoChannel: MethodChannel? = null
    private var callManager: CallManager? = null
    private var methodHandler: TelecomMethodHandler? = null
    private var deviceInfoHandler: DeviceInfoHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        TelecomServiceRuntime.initialize(applicationContext)
        TelecomServiceRuntime.foregroundBridge().attach(binding.binaryMessenger)

        callManager = CallManager(applicationContext)
        methodHandler = TelecomMethodHandler(callManager!!)
        deviceInfoHandler = DeviceInfoHandler(applicationContext)

        actionsChannel = MethodChannel(
            binding.binaryMessenger,
            TelecomConstants.ACTIONS_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler(methodHandler)
        }

        deviceInfoChannel = MethodChannel(
            binding.binaryMessenger,
            TelecomConstants.DEVICE_INFO_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler(deviceInfoHandler)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        actionsChannel?.setMethodCallHandler(null)
        actionsChannel = null
        deviceInfoChannel?.setMethodCallHandler(null)
        deviceInfoChannel = null
        methodHandler = null
        deviceInfoHandler = null
        callManager = null
        TelecomServiceRuntime.foregroundBridge().detach()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
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
    }
}

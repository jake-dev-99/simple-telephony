import 'package:simple_telephony_platform_interface/simple_telephony_platform_interface.dart';

/// Android implementation of [SimpleTelephonyPlatform].
///
/// Registered via `dartPluginClass: SimpleTelephonyAndroid` in pubspec.yaml.
/// The generated plugin registrant calls [registerWith] at startup; this
/// binds `SimpleTelephonyNativePlatform.instance` to the method-channel
/// implementation carried by the platform interface.
class SimpleTelephonyAndroid extends MethodChannelSimpleTelephony {
  /// Registers this class as the platform implementation.
  static void registerWith() {
    SimpleTelephonyPlatform.instance = SimpleTelephonyAndroid();
  }
}

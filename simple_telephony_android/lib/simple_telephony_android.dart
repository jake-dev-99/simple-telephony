import 'package:flutter/services.dart';
import 'package:simple_telephony_platform_interface/simple_telephony_platform_interface.dart';

/// Android implementation of [SimpleTelephonyPlatform].
///
/// This class registers the Android platform with the plugin system.
/// The actual method channel communication is handled by
/// [MethodChannelSimpleTelephony] in the platform interface; this package
/// carries the native Kotlin code and ensures it is loaded on Android.
class SimpleTelephonyAndroid extends MethodChannelSimpleTelephony {
  /// Registers this class as the platform implementation.
  static void registerWith(Registrar? registrar) {
    SimpleTelephonyPlatform.instance = SimpleTelephonyAndroid();
  }
}

/// Registrar interface for plugin registration.
///
/// Matches the signature expected by Flutter's generated plugin registrant.
// ignore: one_member_abstracts
abstract class Registrar {
  /// Returns a [BinaryMessenger] for creating channels.
  BinaryMessenger get messenger;
}

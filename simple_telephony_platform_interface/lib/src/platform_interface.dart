import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'call_control_result.dart';
import 'method_channel_simple_telephony.dart';
import 'phone_call_event.dart';
import 'phone_call_snapshot.dart';

/// Callback signature for receiving phone call events.
typedef CallEventHandler = Future<void> Function(PhoneCallEvent event);

/// The interface that platform-specific implementations of
/// `simple_telephony` must extend.
///
/// Platform implementations should set
/// [SimpleTelephonyPlatform.instance] to their own subclass in their
/// `registerWith` method.
abstract class SimpleTelephonyPlatform extends PlatformInterface {
  SimpleTelephonyPlatform() : super(token: _token);

  static final Object _token = Object();

  static SimpleTelephonyPlatform _instance = MethodChannelSimpleTelephony();

  /// The current platform implementation.
  ///
  /// Defaults to [MethodChannelSimpleTelephony].
  static SimpleTelephonyPlatform get instance => _instance;

  /// Set the platform implementation. Called by platform packages during
  /// registration (e.g., [SimpleTelephonyAndroid.registerWith]).
  static set instance(SimpleTelephonyPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Broadcast stream of call events from the native layer.
  Stream<PhoneCallEvent> get events;

  /// Returns current call snapshots from persisted native state.
  Future<List<PhoneCallSnapshot>> getCurrentCalls();

  /// Requests the system to place an outbound call.
  Future<CallControlResult> placePhoneCall(String phoneNumber);

  /// Attempts to answer the call identified by [callId].
  Future<CallControlResult> answerPhoneCall(String callId);

  /// Attempts to end the call identified by [callId].
  Future<CallControlResult> endPhoneCall(String callId);

  /// Whether this app currently holds the default dialer role.
  Future<bool> isDefaultDialerApp();

  /// Requests the default dialer role from the system.
  Future<bool> requestDefaultDialerApp();

  /// Registers the raw callback handles for background event delivery.
  ///
  /// [dispatcherHandle] is the handle for the background isolate entrypoint.
  /// [userHandle] is the handle for the user's callback function.
  Future<void> registerBackgroundHandler({
    required int dispatcherHandle,
    required int userHandle,
  });
}

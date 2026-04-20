import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'call_control_result.dart';
import 'call_log_entry.dart';
import 'call_log_filter.dart';
import 'device_info.dart';
import 'method_channel_simple_telephony.dart';
import 'phone_call_event.dart';
import 'phone_call_snapshot.dart';
import 'sim_card.dart';

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

  // Dialer-role observation + request is owned by
  // `simple_permissions_native` — call
  // `SimplePermissionsNative.instance.check(DefaultDialerApp())`
  // / `request(DefaultDialerApp())` / `observe(...)` there. Removed
  // from this interface in v0.4.0 so access-state vocabulary lives
  // in exactly one plugin.

  /// Registers the raw callback handles for background event delivery.
  ///
  /// [dispatcherHandle] is the handle for the background isolate entrypoint.
  /// [userHandle] is the handle for the user's callback function.
  Future<void> registerBackgroundHandler({
    required int dispatcherHandle,
    required int userHandle,
  });

  /// Returns the raw Dart callback handle registered via
  /// [registerBackgroundHandler], or `null` if no handler is registered.
  ///
  /// Called from the headless background isolate during bootstrap.
  Future<int?> fetchBackgroundHandlerHandle() {
    throw UnimplementedError(
      'fetchBackgroundHandlerHandle() has not been implemented.',
    );
  }

  /// Wires up the background-events channel to invoke [onEvent] for each
  /// `deliverBackgroundEvent` method call. The implementation is responsible
  /// for decoding the raw channel payload into a [PhoneCallEvent].
  ///
  /// Called once per background-isolate bootstrap.
  void setBackgroundMessageHandler(
    Future<void> Function(PhoneCallEvent event) onEvent,
  ) {
    throw UnimplementedError(
      'setBackgroundMessageHandler() has not been implemented.',
    );
  }

  /// Acknowledges a delivered background event so native can drop it from its
  /// retry queue. [eventId] is the id carried in [PhoneCallEvent.eventId].
  Future<void> acknowledgeBackgroundEvent(String eventId) {
    throw UnimplementedError(
      'acknowledgeBackgroundEvent() has not been implemented.',
    );
  }

  /// Signals to native that the background isolate has finished bootstrapping
  /// and is ready to receive events. Called once per bootstrap after the
  /// message handler is registered.
  Future<void> notifyBackgroundDispatcherReady() {
    throw UnimplementedError(
      'notifyBackgroundDispatcherReady() has not been implemented.',
    );
  }

  /// Lists call-log entries (history) matching [filter], ordered by [sort],
  /// paged by [limit] / [offset].
  ///
  /// Requires `READ_CALL_LOG` permission. Implemented against the device's
  /// `content://call_log/calls` provider — the typed filter is translated to
  /// the underlying query inside the platform implementation.
  Future<List<CallLogEntry>> listCallLog({
    CallLogFilter? filter,
    CallLogSort? sort,
    int? limit,
    int? offset,
  }) {
    throw UnimplementedError(
      'listCallLog() is not implemented on the current platform. '
      'Ensure simple_telephony_android is listed in your pubspec dependencies.',
    );
  }

  /// Returns basic device info (build, Android version, SIM slot count).
  ///
  /// This is NOT a content-provider query — it's sourced from `Build` and
  /// `SubscriptionManager`. The `deviceId` field requires `READ_PHONE_STATE`
  /// on supported Android versions.
  Future<DeviceInfo> getDeviceInfo() {
    throw UnimplementedError(
      'getDeviceInfo() is not implemented on the current platform. '
      'Ensure simple_telephony_android is listed in your pubspec dependencies.',
    );
  }

  /// Enumerates active SIM subscriptions on the device.
  ///
  /// Sourced from `SubscriptionManager.getActiveSubscriptionInfoList()` (NOT
  /// a content-provider query). Requires `READ_PHONE_STATE`.
  Future<List<SimCard>> listSimCards() {
    throw UnimplementedError(
      'listSimCards() is not implemented on the current platform. '
      'Ensure simple_telephony_android is listed in your pubspec dependencies.',
    );
  }
}

/// Device-level information returned by
/// `SimpleTelephonyNative.instance.getDeviceInfo()`.
///
/// This is sourced from `android.os.Build` + `TelephonyManager` /
/// `SubscriptionManager`, not from a content provider — no READ_CONTACTS /
/// READ_CALL_LOG permission is required, though `deviceId` / `simSlotCount`
/// may require `READ_PHONE_STATE` depending on the Android version.
class DeviceInfo {
  const DeviceInfo({
    required this.model,
    required this.manufacturer,
    required this.androidVersion,
    required this.androidSdkInt,
    required this.simSlotCount,
    this.deviceId,
    this.sourceMap,
  });

  /// `Build.MODEL` (e.g. "SM-G998U").
  final String model;

  /// `Build.MANUFACTURER` (e.g. "samsung").
  final String manufacturer;

  /// `Build.VERSION.RELEASE` (e.g. "14").
  final String androidVersion;

  /// `Build.VERSION.SDK_INT` (e.g. 34).
  final int androidSdkInt;

  /// Number of SIM slots reported by `SubscriptionManager`. `0` when the
  /// plugin couldn't enumerate subscriptions.
  final int simSlotCount;

  /// Hardware-bound identifier when available and permitted by the OS.
  /// Null on recent Android versions without carrier privileges.
  final String? deviceId;

  /// Raw underlying map for consumers needing non-modeled fields.
  final Map<String, Object?>? sourceMap;

  @override
  String toString() => 'DeviceInfo(model: $model, manufacturer: $manufacturer, '
      'androidVersion: $androidVersion, androidSdkInt: $androidSdkInt, '
      'simSlotCount: $simSlotCount)';
}

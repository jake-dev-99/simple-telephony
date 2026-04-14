/// A single active SIM subscription on the device, returned by
/// `SimpleTelephonyNative.instance.listSimCards()`.
///
/// Sourced from `SubscriptionManager.getActiveSubscriptionInfoList()` — NOT a
/// content-provider query. `READ_PHONE_STATE` is typically required; on
/// recent Android versions `number` and `countryIso` may return empty strings
/// unless the app holds carrier privileges.
class SimCard {
  const SimCard({
    required this.slotIndex,
    required this.subscriptionId,
    required this.isDefault,
    this.carrierName,
    this.displayName,
    this.number,
    this.countryIso,
    this.mcc,
    this.mnc,
    this.sourceMap,
  });

  /// Physical SIM slot index (0, 1, ...).
  final int slotIndex;

  /// Unique subscription id assigned by the system.
  final int subscriptionId;

  /// Whether this subscription is the default for SMS / voice.
  final bool isDefault;

  /// Carrier display name (e.g. "Verizon").
  final String? carrierName;

  /// User-facing subscription label (often carrier name + line).
  final String? displayName;

  /// The SIM's phone number when reported by the carrier. Frequently empty.
  final String? number;

  /// ISO country code of the SIM operator.
  final String? countryIso;

  /// Mobile country code.
  final String? mcc;

  /// Mobile network code.
  final String? mnc;

  /// Raw underlying map for consumers needing non-modeled fields.
  final Map<String, Object?>? sourceMap;

  @override
  String toString() => 'SimCard(slot: $slotIndex, sub: $subscriptionId, '
      'carrier: $carrierName, default: $isDefault)';
}

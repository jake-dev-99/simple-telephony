# simple_telephony_platform_interface

A common platform interface for the [`simple_telephony_native`](https://pub.dev/packages/simple_telephony_native) plugin.

This interface allows platform-specific implementations of `simple_telephony_native` to ensure they support the same interface. If you are implementing a new platform, extend [`SimpleTelephonyPlatform`](lib/src/platform_interface.dart) with an implementation that satisfies the contract.

## Usage

To implement a new platform:

```dart
class SimpleTelephonyMyPlatform extends SimpleTelephonyPlatform {
  static void registerWith(Registrar registrar) {
    SimpleTelephonyPlatform.instance = SimpleTelephonyMyPlatform();
  }

  @override
  Future<List<PhoneCallSnapshot>> getCurrentCalls() async { /* ... */ }

  // ... implement all abstract methods
}
```

## Note on breaking changes

Strongly prefer non-breaking changes (such as adding a method to the interface) over breaking changes.

See [the Flutter wiki](https://github.com/flutter/flutter/wiki/Plugins-and-Packages-repository-structure#platform-interface-packages) for more information.

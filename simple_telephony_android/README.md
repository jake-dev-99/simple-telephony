# simple_telephony_android

The Android implementation of [`simple_telephony`](https://pub.dev/packages/simple_telephony).

## Usage

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin), which means you can simply use `simple_telephony` normally. This package will be automatically included in your app when you depend on `simple_telephony`.

```yaml
dependencies:
  simple_telephony: ^0.1.0
```

## Direct usage

If you want to use this package directly (without the app-facing package), add it as a dependency:

```yaml
dependencies:
  simple_telephony_android: ^0.1.0
```

Then use `SimpleTelephonyPlatform.instance` directly.

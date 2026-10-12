# simple_telephony_android

The Android implementation of [`simple_telephony_native`](https://pub.dev/packages/simple_telephony_native).

## Usage

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin), which means you can simply use `simple_telephony_native` normally. This package will be automatically included in your app when you depend on `simple_telephony_native`.

```yaml
dependencies:
  simple_telephony_native: ^1.0.0
```

## Direct usage

If you want to use this package directly (without the app-facing package), add it as a dependency:

```yaml
dependencies:
  simple_telephony_android: ^1.0.0
```

Then use `SimpleTelephonyPlatform.instance` directly.

Call-log queries use Query's canonical field contract. Query failures,
including permission errors, propagate to the caller; an empty list means
the query succeeded with no matching records.

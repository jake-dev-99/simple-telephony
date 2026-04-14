# simple_telephony_native

A federated Flutter plugin for phone call management.

## Packages

| Package | Description |
|---|---|
| [simple_telephony_native](simple_telephony_native/) | App-facing API (what you import) |
| [simple_telephony_platform_interface](simple_telephony_platform_interface/) | Abstract contract and shared models |
| [simple_telephony_android](simple_telephony_android/) | Android implementation via InCallService |

See [simple_telephony_native/README.md](simple_telephony_native/README.md) for usage documentation.

## Development

```bash
# Run all tests
tool/publish.sh

# Publish (interface → android → app-facing)
tool/publish.sh --live
```

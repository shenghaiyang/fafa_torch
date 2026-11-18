# Changelog

## 0.1.0

- Unregister the iOS torch host API on engine detach, so method channel handlers no longer retain the plugin instance.
- Remove the inverted `isTorchModeSupported(.on)` guard in `turnOn(level:)`.
- Improve README formatting and structure.

## 0.0.1

- Initial release.
- Android and iOS torch control through Pigeon channels.
- Torch availability, on/off state, and level APIs.
- Torch state broadcast stream.

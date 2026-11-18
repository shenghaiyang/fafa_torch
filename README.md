# fafa_torch

[![pub package](https://img.shields.io/pub/v/fafa_torch.svg)](https://pub.dev/packages/fafa_torch)
[![CI](https://github.com/shenghaiyang/fafa_torch/actions/workflows/ci.yml/badge.svg)](https://github.com/shenghaiyang/fafa_torch/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Flutter plugin for controlling the device flashlight on Android and iOS, with level control and state streaming.

## Features

- Query torch availability and on/off state
- Turn the torch on or off
- Adjust the torch level where the platform supports it
- Subscribe to torch state changes
- No camera permission required

## Platform support

| Platform | Minimum version | Notes                                                                               |
|----------|-----------------|-------------------------------------------------------------------------------------|
| Android  | API 24          | Level control requires API 33 or later, and hardware with adjustable torch strength |
| iOS      | 15.0            | Level control is available on devices with a torch                                  |

Web, macOS, Windows, and Linux are not supported.

## Installation

```yaml
dependencies:
  fafa_torch: ^0.1.0
```

## Usage

```dart
import 'package:fafa_torch/fafa_torch.dart';

final torch = Torch();

if (await torch.isAvailable()) {
  await torch.turnOn();
}
```

### State changes

`stateChanges` is a broadcast stream. The current state is emitted as soon as the stream is listened to.

```dart
final subscription = torch.stateChanges.listen((state) {
  print('available: ${state.available}');
  print('on: ${state.on}');
});
```

### Level control

`turnOn` accepts an optional level between 0.0 and 1.0. Calling it while the torch is on updates the level. A value of `0.0` maps to the lowest level the platform supports and does not turn the torch off.

```dart
if (await torch.supportsLevel()) {
  await torch.turnOn(level: 0.5);
  final level = await torch.level();
}
```

Calling `turnOn(level:)` or `level()` on a device without level support throws a `PlatformException` with code `levelUnsupported`.

### Error handling

The plugin reports failures through `PlatformException`. Map `error.code` to a `TorchErrorCode` with `TorchErrorCode.fromCode` to handle specific cases.

```dart
import 'package:fafa_torch/fafa_torch.dart';
import 'package:flutter/services.dart';

try {
  await torch.turnOn();
} on PlatformException catch (error) {
  switch (TorchErrorCode.fromCode(error.code)) {
    case TorchErrorCode.torchUnavailable:
      break;
    case TorchErrorCode.torchInUse:
      break;
    case TorchErrorCode.levelUnsupported:
      break;
    case TorchErrorCode.torchOperationFailed:
      break;
    case null:
      break;
  }
}
```

| Error code             | Meaning                                            |
|------------------------|----------------------------------------------------|
| `torchUnavailable`     | No torch is available, or the system cannot use it |
| `torchInUse`           | The torch is held by another camera client         |
| `levelUnsupported`     | Level control is not supported on this device      |
| `torchOperationFailed` | The platform failed to complete the operation      |

## API

| Member                    | Description                                       |
|---------------------------|---------------------------------------------------|
| `isAvailable()`           | Returns whether a torch is available              |
| `isOn()`                  | Returns whether the torch is currently on         |
| `supportsLevel()`         | Returns whether the torch level can be adjusted   |
| `turnOn({double? level})` | Turns the torch on, optionally at the given level |
| `turnOff()`               | Turns the torch off                               |
| `level()`                 | Returns the current level, between 0.0 and 1.0    |
| `stateChanges`            | Broadcast stream of `TorchState` changes          |

## Notes

- The plugin does not request camera permission.
- On Android, `isAvailable()` reports whether a torch is present. Turning it on can still fail with `torchInUse` when another app is using the camera.
- The plugin does not turn the torch off when the app goes to the background or when the Flutter engine detaches. Apps should manage the torch state themselves.


## License

This project is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 shenghaiyang.

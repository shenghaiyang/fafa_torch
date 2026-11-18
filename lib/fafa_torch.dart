import 'dart:async';

import 'package:fafa_torch/src/messages.g.dart' as messages;
import 'package:meta/meta.dart';

/// The current state of the device torch.
class TorchState {
  const TorchState({
    required this.available,
    required this.on,
  });

  /// Whether a torch is available on the device.
  final bool available;

  /// Whether the torch is currently turned on.
  final bool on;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TorchState &&
        other.available == available &&
        other.on == on;
  }

  @override
  int get hashCode => Object.hash(available, on);

  @override
  String toString() => 'TorchState(available: $available, on: $on)';
}

/// Error codes reported by [Torch] through `PlatformException`.
enum TorchErrorCode {
  /// No torch is available, or the system cannot use it.
  torchUnavailable,

  /// The torch is held by another camera client.
  torchInUse,

  /// Level control is not supported on this device.
  levelUnsupported,

  /// The platform failed to complete the operation.
  torchOperationFailed;

  /// Resolves a `PlatformException.code` string to its [TorchErrorCode].
  ///
  /// Returns null if [code] is not recognized.
  static TorchErrorCode? fromCode(String code) {
    for (final value in values) {
      if (value.name == code) return value;
    }
    return null;
  }
}

/// Controls the device torch.
///
/// All methods report failures by throwing `PlatformException` with a code
/// from [TorchErrorCode].
class Torch {
  /// Creates a [Torch] that talks to the host platform.
  Torch()
    : this._(
        api: messages.TorchHostApi(),
        stateChangesFactory: messages.stateChanges,
      );

  /// Creates a [Torch] backed by [api] and [stateChanges].
  ///
  /// Visible for testing only. Use the default [Torch] constructor to talk
  /// to the host platform.
  @visibleForTesting
  Torch.withBackend({
    required messages.TorchHostApi api,
    required Stream<messages.TorchState> Function() stateChanges,
  }) : this._(api: api, stateChangesFactory: stateChanges);

  Torch._({required this._api, required this._stateChangesFactory});

  final messages.TorchHostApi _api;
  final Stream<messages.TorchState> Function() _stateChangesFactory;
  Stream<TorchState>? _cachedStateChanges;

  /// Returns whether a torch is available on the device.
  Future<bool> isAvailable() => _api.isAvailable();

  /// Returns whether the torch is currently turned on.
  Future<bool> isOn() => _api.isOn();

  /// Returns whether the torch level can be adjusted.
  Future<bool> supportsLevel() => _api.supportsLevel();

  /// Returns the current torch level, between 0.0 and 1.0.
  ///
  /// Throws `levelUnsupported` when level control is not available.
  Future<double> level() => _api.level();

  /// Turns the torch on, optionally at [level] between 0.0 and 1.0.
  ///
  /// When [level] is null the platform default is used. A value of 0.0 maps
  /// to the lowest level the platform supports.
  Future<void> turnOn({double? level}) {
    if (level != null && (!level.isFinite || level < 0 || level > 1)) {
      throw RangeError.range(level, 0, 1, 'level');
    }
    return _api.turnOn(level);
  }

  /// Turns the torch off.
  Future<void> turnOff() => _api.turnOff();

  /// A broadcast stream of torch state changes.
  ///
  /// The current state is emitted as soon as the stream is listened to.
  Stream<TorchState> get stateChanges {
    return _cachedStateChanges ??= _stateChangesFactory().map(
      (state) => TorchState(available: state.available, on: state.on),
    );
  }
}

import 'dart:async';

import 'package:fafa_torch/fafa_torch.dart';
import 'package:fafa_torch/src/messages.g.dart' as messages;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTorchHostApi implements messages.TorchHostApi {
  PlatformException? error;
  bool available = true;
  bool on = false;
  bool levelSupported = true;
  double currentLevel = 1.0;

  void _throwIfNeeded() {
    final value = error;
    if (value != null) throw value;
  }

  @override
  Future<bool> isAvailable() async {
    _throwIfNeeded();
    return available;
  }

  @override
  Future<bool> isOn() async {
    _throwIfNeeded();
    return on;
  }

  @override
  Future<bool> supportsLevel() async {
    _throwIfNeeded();
    return levelSupported;
  }

  @override
  Future<double> level() async {
    _throwIfNeeded();
    return currentLevel;
  }

  @override
  Future<void> turnOn(double? level) async {
    _throwIfNeeded();
    on = true;
    if (level != null) currentLevel = level;
  }

  @override
  Future<void> turnOff() async {
    _throwIfNeeded();
    on = false;
  }

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';
}

Torch buildTorch(
  FakeTorchHostApi api,
  Stream<messages.TorchState> Function() stateChanges,
) {
  return Torch.withBackend(api: api, stateChanges: stateChanges);
}

void main() {
  test('delegates to TorchHostApi', () async {
    final api = FakeTorchHostApi();
    final controller = StreamController<messages.TorchState>.broadcast();
    final torch = buildTorch(api, () => controller.stream);

    expect(await torch.isAvailable(), isTrue);
    expect(await torch.isOn(), isFalse);
    expect(await torch.supportsLevel(), isTrue);
    expect(await torch.level(), 1.0);

    await torch.turnOn();
    expect(api.on, isTrue);
    expect(api.currentLevel, 1.0);

    await torch.turnOff();
    expect(api.on, isFalse);

    await torch.turnOn(level: 0.25);
    expect(api.on, isTrue);
    expect(api.currentLevel, 0.25);

    await controller.close();
  });

  test('propagates PlatformException', () async {
    final api = FakeTorchHostApi()
      ..error = PlatformException(code: TorchErrorCode.torchInUse.name);
    final controller = StreamController<messages.TorchState>.broadcast();
    final torch = buildTorch(api, () => controller.stream);

    await expectLater(
      torch.turnOn(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          TorchErrorCode.torchInUse.name,
        ),
      ),
    );

    await controller.close();
  });

  test('turnOn validates the level range', () {
    final torch = buildTorch(
      FakeTorchHostApi(),
      () => const Stream<messages.TorchState>.empty(),
    );

    expect(() => torch.turnOn(level: -0.1), throwsRangeError);
    expect(() => torch.turnOn(level: 1.1), throwsRangeError);
    expect(() => torch.turnOn(level: double.nan), throwsRangeError);
    expect(() => torch.turnOn(level: double.infinity), throwsRangeError);
  });

  test('stateChanges maps to the public TorchState', () async {
    final controller = StreamController<messages.TorchState>.broadcast();
    final torch = buildTorch(FakeTorchHostApi(), () => controller.stream);

    final future = torch.stateChanges.first;
    controller.add(messages.TorchState(available: true, on: true));
    final state = await future;

    expect(state.available, isTrue);
    expect(state.on, isTrue);

    await controller.close();
  });

  test('stateChanges creates the underlying stream once', () async {
    var calls = 0;
    final controller = StreamController<messages.TorchState>.broadcast();
    final torch = buildTorch(FakeTorchHostApi(), () {
      calls += 1;
      return controller.stream;
    });

    expect(identical(torch.stateChanges, torch.stateChanges), isTrue);
    expect(calls, 1);

    await controller.close();
  });

  test('TorchState supports value equality', () {
    const a = TorchState(available: true, on: false);
    const b = TorchState(available: true, on: false);
    const c = TorchState(available: true, on: true);

    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(equals(c)));
  });

  test('TorchErrorCode.fromCode resolves known codes', () {
    expect(
      TorchErrorCode.fromCode('torchUnavailable'),
      TorchErrorCode.torchUnavailable,
    );
    expect(TorchErrorCode.fromCode('torchInUse'), TorchErrorCode.torchInUse);
    expect(
      TorchErrorCode.fromCode('levelUnsupported'),
      TorchErrorCode.levelUnsupported,
    );
    expect(
      TorchErrorCode.fromCode('torchOperationFailed'),
      TorchErrorCode.torchOperationFailed,
    );
    expect(TorchErrorCode.fromCode('unknown'), isNull);
  });
}

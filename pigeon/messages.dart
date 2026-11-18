import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'fafa_torch',
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/shenghaiyang/fafa/torch/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.shenghaiyang.fafa.torch'),
    swiftOut: ['ios/fafa_torch/Sources/fafa_torch/Messages.g.swift'],
  ),
)
class TorchState {
  TorchState({
    required this.available,
    required this.on,
  });

  bool available;
  bool on;
}

@HostApi()
abstract class TorchHostApi {
  bool isAvailable();
  bool isOn();
  bool supportsLevel();
  double level();
  void turnOn(double? level);
  void turnOff();
}

@EventChannelApi()
abstract class TorchStateEventApi {
  TorchState stateChanges();
}

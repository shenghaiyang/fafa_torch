import 'dart:async';

import 'package:fafa_torch/fafa_torch.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.amber, useMaterial3: true),
      home: const TorchPage(),
    );
  }
}

class TorchPage extends StatefulWidget {
  const TorchPage({super.key});

  @override
  State<TorchPage> createState() => _TorchPageState();
}

class _TorchPageState extends State<TorchPage> {
  final Torch _torch = Torch();
  StreamSubscription<TorchState>? _subscription;
  TorchState? _state;
  bool _levelSupported = false;
  double _level = 1.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = _torch.stateChanges.listen(
      (state) {
        if (!mounted) return;
        setState(() {
          _state = state;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = _describeError(error);
        });
      },
    );
    _loadLevelSupport();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLevelSupport() async {
    try {
      final supported = await _torch.supportsLevel();
      if (!mounted) return;
      setState(() {
        _levelSupported = supported;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _describeError(error);
      });
    }
  }

  Future<void> _setOn(bool on) async {
    await _run(() => on ? _torch.turnOn() : _torch.turnOff());
  }

  Future<void> _setLevel(double level) async {
    await _run(() => _torch.turnOn(level: level));
    final current = await _torch.level();
    if (mounted) setState(() => _level = current);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _error = null;
    });
    try {
      await action();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _describeError(error);
      });
    }
  }

  String _describeError(Object error) {
    if (error is PlatformException) {
      return switch (TorchErrorCode.fromCode(error.code)) {
        TorchErrorCode.torchUnavailable =>
          'No torch is available on this device',
        TorchErrorCode.torchInUse => 'The torch is in use by another app',
        TorchErrorCode.levelUnsupported =>
          'Level control is not supported on this device',
        _ => 'Operation failed: ${error.message ?? error.code}',
      };
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final available = state?.available ?? false;
    final on = state?.on ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Torch Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(on ? Icons.flashlight_on : Icons.flashlight_off),
              title: const Text('Torch'),
              subtitle: Text(
                state == null
                    ? 'Reading state'
                    : available
                    ? (on ? 'On' : 'Off')
                    : 'Unavailable',
              ),
              trailing: Switch(
                value: on,
                onChanged: available ? _setOn : null,
              ),
            ),
          ),
          if (_levelSupported)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Level ${(_level * 100).round()}%'),
                  Slider(value: _level, onChanged: _setLevel),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

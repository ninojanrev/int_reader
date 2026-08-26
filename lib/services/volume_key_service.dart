import 'dart:async';

import 'package:flutter/services.dart';

/// Which hardware key was pressed.
enum VolumeKey { up, down }

/// Listens for volume-key presses forwarded from MainActivity
/// (see `dispatchKeyEvent` there). Only one listener is expected at a
/// time (the reader screen).
class VolumeKeyService {
  static const _channel = EventChannel('int_reader/volume_keys');

  StreamSubscription? _subscription;

  /// Start listening; [onKey] fires for each press. Safe to call when the
  /// platform side isn't available (errors are swallowed).
  void startListening(void Function(VolumeKey key) onKey) {
    stopListening();
    _subscription = _channel.receiveBroadcastStream().listen(
      (data) {
        if (data == 'up') onKey(VolumeKey.up);
        if (data == 'down') onKey(VolumeKey.down);
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Global singleton instance.
final volumeKeyService = VolumeKeyService();

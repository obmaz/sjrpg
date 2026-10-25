import 'package:flutter/foundation.dart';
import 'device_bridge.dart';

enum FeedbackKind { hit, hurt, kill, skill, dodge, loot }

class DeviceSettings extends ChangeNotifier {
  DeviceSettings({DeviceBridge? bridge, Duration Function()? now})
    : bridge = bridge ?? createDeviceBridge() {
    _clock.start();
    _now = now ?? (() => _clock.elapsed);
    hapticsEnabled = this.bridge.readPreference(preferenceKey) != 'false';
    this.bridge.listen(() {
      if (!_disposed) notifyListeners();
    });
  }
  static final shared = DeviceSettings();
  static const preferenceKey = 'guardian.new.haptics';
  final DeviceBridge bridge;
  final _clock = Stopwatch();
  late final Duration Function() _now;
  Duration? _lastPulse;
  bool hapticsEnabled = true, _disposed = false;
  bool get fullscreenSupported => bridge.fullscreenSupported;
  bool get fullscreen => bridge.fullscreen;
  bool get vibrationSupported => bridge.vibrationSupported;
  void setHaptics(bool enabled) {
    hapticsEnabled = enabled;
    bridge.writePreference(preferenceKey, '$enabled');
    if (!enabled) cancel();
    notifyListeners();
  }

  Future<bool> toggleFullscreen() async {
    if (!fullscreenSupported || _disposed) return false;
    try {
      await bridge.toggleFullscreen();
      if (!_disposed) notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void pulse(FeedbackKind kind, {bool preview = false}) {
    if (_disposed ||
        !hapticsEnabled ||
        !vibrationSupported ||
        !bridge.visible) {
      return;
    }
    final now = _now();
    // Several targets in one cleave generate one pulse, while a hit on the hero takes precedence.
    if (!preview &&
        kind != FeedbackKind.hurt &&
        _lastPulse != null &&
        now - _lastPulse! < const Duration(milliseconds: 100)) {
      return;
    }
    _lastPulse = now;
    try {
      bridge.vibrate(switch (kind) {
        FeedbackKind.hit => [12],
        FeedbackKind.hurt => [32, 22, 45],
        FeedbackKind.kill => [18, 14, 14],
        FeedbackKind.skill => [12, 18, 24],
        FeedbackKind.dodge => [8],
        FeedbackKind.loot => [8, 14, 8],
      });
    } catch (_) {
      /* Device feedback must never interrupt combat. */
    }
  }

  void cancel() {
    try {
      bridge.cancelVibration();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    bridge.dispose();
    _clock.stop();
    super.dispose();
  }
}

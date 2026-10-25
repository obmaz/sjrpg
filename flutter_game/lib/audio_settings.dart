import 'package:flutter/foundation.dart';
import 'audio_bridge.dart';
import 'audio_profile.dart';
export 'audio_profile.dart';

class AudioSettings extends ChangeNotifier {
  AudioSettings({AudioBridge? bridge, Duration Function()? now})
    : bridge = bridge ?? createAudioBridge() {
    _clock.start();
    _now = now ?? (() => _clock.elapsed);
    enabled = this.bridge.readPreference(preferenceKey) != 'false';
    this.bridge.setEnabled(enabled);
  }
  static final shared = AudioSettings();
  static const preferenceKey = 'guardian.new.audio';
  final AudioBridge bridge;
  final _clock = Stopwatch();
  late final Duration Function() _now;
  final _last = <EffectSound, Duration>{};
  Duration? _lastSound;
  bool enabled = true, _disposed = false;
  bool get supported => bridge.supported;

  void setEnabled(bool value) {
    if (_disposed) return;
    enabled = value;
    bridge.writePreference(preferenceKey, '$value');
    bridge.setEnabled(value);
    if (!value) stop();
    notifyListeners();
  }

  void play(EffectSound sound, {bool preview = false}) {
    if (_disposed || !enabled || !supported || !bridge.visible) return;
    final now = _now();
    if (!preview &&
        sound != EffectSound.hurt &&
        ((_last[sound] != null &&
                now - _last[sound]! < const Duration(milliseconds: 80)) ||
            (_lastSound != null &&
                now - _lastSound! < const Duration(milliseconds: 25)))) {
      return;
    }
    _last[sound] = now;
    _lastSound = now;
    try {
      bridge.play(sound);
    } catch (_) {
      // Browser audio must never interrupt combat.
    }
  }

  void stop() {
    try {
      bridge.stop();
    } catch (_) {}
    _last.clear();
    _lastSound = null;
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    bridge.dispose();
    _clock.stop();
    super.dispose();
  }
}

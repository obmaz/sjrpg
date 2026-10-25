import 'audio_bridge.dart';
import 'audio_profile.dart';

AudioBridge createBridge() => _UnavailableAudio();

class _UnavailableAudio implements AudioBridge {
  @override
  bool get supported => false;
  @override
  bool get visible => true;
  @override
  String? readPreference(String key) => null;
  @override
  void writePreference(String key, String value) {}
  @override
  void setEnabled(bool enabled) {}
  @override
  void play(EffectSound sound) {}
  @override
  void stop() {}
  @override
  void dispose() {}
}

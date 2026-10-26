import 'audio_bridge_stub.dart'
    if (dart.library.js_interop) 'audio_bridge_web.dart'
    as implementation;
import 'audio_profile.dart';

abstract class AudioBridge {
  bool get supported;
  bool get visible;
  String? readPreference(String key);
  void writePreference(String key, String value);
  void setEnabled(bool enabled);
  void play(EffectSound sound);
  void stop();
  void dispose();
}

AudioBridge createAudioBridge() => implementation.createBridge();

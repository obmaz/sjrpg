import 'device_bridge_stub.dart'
    if (dart.library.js_interop) 'device_bridge_web.dart'
    as implementation;

abstract class DeviceBridge {
  bool get fullscreenSupported;
  bool get fullscreen;
  bool get vibrationSupported;
  bool get visible;
  String? readPreference(String key);
  void writePreference(String key, String value);
  Future<void> toggleFullscreen();
  bool vibrate(List<int> pattern);
  void cancelVibration();
  void listen(void Function() onChange);
  void dispose();
}

DeviceBridge createDeviceBridge() => implementation.createBridge();

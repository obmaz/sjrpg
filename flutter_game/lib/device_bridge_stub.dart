import 'device_bridge.dart';

DeviceBridge createBridge() => _UnavailableDevice();

class _UnavailableDevice implements DeviceBridge {
  @override
  bool get fullscreenSupported => false;
  @override
  bool get fullscreen => false;
  @override
  bool get vibrationSupported => false;
  @override
  bool get visible => true;
  @override
  String? readPreference(String key) => null;
  @override
  void writePreference(String key, String value) {}
  @override
  Future<void> toggleFullscreen() async {}
  @override
  bool vibrate(List<int> pattern) => false;
  @override
  void cancelVibration() {}
  @override
  void listen(void Function() onChange) {}
  @override
  void dispose() {}
}

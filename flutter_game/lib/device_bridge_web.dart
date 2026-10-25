import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'device_bridge.dart';

DeviceBridge createBridge() => _BrowserDevice();

class _BrowserDevice implements DeviceBridge {
  JSFunction? _listener;
  @override
  bool get fullscreenSupported =>
      web.document.hasProperty('fullscreenEnabled'.toJS).toDart &&
      web.document.fullscreenEnabled &&
      web.document.documentElement != null &&
      web.document.documentElement!
          .hasProperty('requestFullscreen'.toJS)
          .toDart;
  @override
  bool get fullscreen => web.document.fullscreenElement != null;
  @override
  bool get vibrationSupported =>
      web.window.navigator.hasProperty('vibrate'.toJS).toDart;
  @override
  bool get visible => !web.document.hidden;
  @override
  String? readPreference(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  void writePreference(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {
      /* Private browsing can block storage. */
    }
  }

  @override
  Future<void> toggleFullscreen() async {
    if (fullscreen) {
      await web.document.exitFullscreen().toDart;
    } else {
      await web.document.documentElement!.requestFullscreen().toDart;
    }
  }

  @override
  bool vibrate(List<int> pattern) =>
      vibrationSupported &&
      web.window.navigator.vibrate(pattern.map((v) => v.toJS).toList().toJS);
  @override
  void cancelVibration() {
    if (vibrationSupported) {
      web.window.navigator.vibrate(0.toJS);
    }
  }

  @override
  void listen(void Function() onChange) {
    _listener = ((web.Event event) {
      if (!visible) cancelVibration();
      onChange();
    }).toJS;
    web.document.addEventListener('fullscreenchange', _listener);
    web.document.addEventListener('visibilitychange', _listener);
  }

  @override
  void dispose() {
    if (_listener != null) {
      web.document.removeEventListener('fullscreenchange', _listener);
      web.document.removeEventListener('visibilitychange', _listener);
    }
    cancelVibration();
  }
}

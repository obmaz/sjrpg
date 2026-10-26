import 'dart:js_interop';
import 'package:web/web.dart' as web;

const _key = 'guardian.new.progress.v1';
String? readCheckpoint() {
  try {
    return web.window.localStorage.getItem(_key);
  } catch (_) {
    return null;
  }
}

bool writeCheckpoint(String value) {
  try {
    web.window.localStorage.setItem(_key, value);
    return true;
  } catch (_) {
    return false;
  }
}

void clearCheckpoint() {
  try {
    web.window.localStorage.removeItem(_key);
  } catch (_) {}
}

void Function() listenForExit(void Function() save) {
  final callback = ((web.Event event) {
    save();
  }).toJS;
  web.window.addEventListener('pagehide', callback);
  web.document.addEventListener('visibilitychange', callback);
  return () {
    web.window.removeEventListener('pagehide', callback);
    web.document.removeEventListener('visibilitychange', callback);
  };
}

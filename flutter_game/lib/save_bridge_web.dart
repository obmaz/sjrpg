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

void writeCheckpoint(String value) {
  try {
    web.window.localStorage.setItem(_key, value);
  } catch (_) {
    /* Storage may be full or blocked. */
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

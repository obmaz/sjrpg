import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

@JS('Object.assign')
external JSObject _copyState(JSObject target, JSAny? source);

void Function() listenForBack(void Function() onBack) {
  final url = web.window.location.href;
  JSObject markedState() =>
      _copyState(JSObject(), web.window.history.state)
        ..setProperty('guardianGameBack'.toJS, true.toJS);
  final current = _copyState(JSObject(), web.window.history.state);
  if (!current.hasProperty('guardianGameBack'.toJS).toDart) {
    web.window.history.pushState(markedState(), '', url);
  }
  final listener = ((web.Event event) {
    // Handle this before Flutter's route listener: dialogs and in-game sheets
    // close through the same app callback without leaving the document.
    event.stopImmediatePropagation();
    web.window.history.pushState(markedState(), '', url);
    onBack();
  }).toJS;
  web.window.addEventListener('popstate', listener, true.toJS);
  return () => web.window.removeEventListener('popstate', listener, true.toJS);
}

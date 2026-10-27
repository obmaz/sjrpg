import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

@JS('Object.assign')
external JSObject _copyState(JSObject target, JSAny? source);

// History survives reloads and browser session restoration; this owner does not.
final _documentOwner =
    '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(0x7fffffff)}';

bool _browserBackConfigured = false;

/// Run before Flutter binding creation; this game owns in-document Back.
void configureBrowserBack() {
  if (_browserBackConfigured) return;
  ui_web.urlStrategy = null;
  _browserBackConfigured = true;
}

void Function() listenForBack(void Function() onBack) {
  final url = web.window.location.href;
  var armed = false, restoring = false;
  String? guardKey;
  String? currentEntryKey() {
    if (!web.window.hasProperty('navigation'.toJS).toDart) return null;
    final navigation = web.window.getProperty<JSObject?>('navigation'.toJS);
    final entry = navigation?.getProperty<JSObject?>('currentEntry'.toJS);
    return entry?.getProperty<JSString?>('key'.toJS)?.toDart;
  }

  bool isGuardEntry() {
    final key = currentEntryKey();
    if (guardKey != null && key != null) return key == guardKey;
    final state = _copyState(JSObject(), web.window.history.state);
    return state.getProperty<JSAny?>('guardianGameBack'.toJS)?.dartify() ==
        _documentOwner;
  }

  JSObject markedState() =>
      _copyState(JSObject(), web.window.history.state)
        ..setProperty('guardianGameBack'.toJS, _documentOwner.toJS);

  // A persisted marker does not prove its preceding same-document entry still
  // exists. Establish a fresh pair during the first real interaction instead.
  const gestures = ['pointerup', 'touchend', 'click', 'keydown'];
  late final JSFunction arm;
  void stopArming() {
    for (final type in gestures) {
      web.window.removeEventListener(type, arm, true.toJS);
    }
  }

  arm = ((web.Event event) {
    if (armed || !event.isTrusted) return;
    if (event.type == 'keydown') {
      final key = event as web.KeyboardEvent;
      if (key.altKey ||
          key.ctrlKey ||
          key.metaKey ||
          key.key != 'Enter' && key.key != ' ') {
        return;
      }
    }
    web.window.history.pushState(markedState(), '', url);
    guardKey = currentEntryKey();
    armed = true;
    stopArming();
  }).toJS;
  for (final type in gestures) {
    web.window.addEventListener(type, arm, true.toJS);
  }

  final listener = ((web.Event event) {
    if (!armed) return;
    // Flutter's browser route integration is disabled at startup. Dispatch
    // only through the app's Navigator and in-game panel callbacks.
    event.stopImmediatePropagation();
    if (isGuardEntry() || restoring && guardKey == null) {
      restoring = false;
      return;
    }
    // A pushState here marks the anchor skippable after traversal consumed its
    // activation. Reuse the existing forward entry, then ignore its popstate.
    restoring = true;
    web.window.history.forward();
    onBack();
  }).toJS;
  web.window.addEventListener('popstate', listener, true.toJS);
  final pageShow = ((web.Event event) {
    // A cached document can return from an explicitly visited external page.
    // Its guard is a return destination, not a request to leave it again.
    if (armed &&
        event.isTrusted &&
        (event as web.PageTransitionEvent).persisted) {
      restoring = false;
      if (guardKey == null) {
        web.window.history.replaceState(markedState(), '', url);
      }
    }
  }).toJS;
  web.window.addEventListener('pageshow', pageShow, true.toJS);
  return () {
    stopArming();
    web.window.removeEventListener('popstate', listener, true.toJS);
    web.window.removeEventListener('pageshow', pageShow, true.toJS);
  };
}

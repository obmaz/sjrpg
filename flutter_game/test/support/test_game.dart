import 'dart:async';
import 'package:bonfire/bonfire.dart';

class TestGame implements BonfireGameInterface {
  @override
  bool paused = false;
  final added = <Component>[];
  @override
  FutureOr<void> add(Component c) {
    added.add(c);
  }

  @override
  void pauseEngine() {
    paused = true;
  }

  @override
  void resumeEngine() {
    paused = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

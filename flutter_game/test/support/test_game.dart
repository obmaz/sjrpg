import 'dart:async';
import 'package:bonfire/bonfire.dart';
import 'package:guardian_new/adventure.dart';

class TestGame implements BonfireGameInterface {
  @override
  bool paused = false;
  final added = <Component>[];
  bool mountEnemies = true;
  @override
  FutureOr<void> add(Component c) {
    added.add(c);
    if (mountEnemies && c is HuntEnemy) c.combatReady = true;
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

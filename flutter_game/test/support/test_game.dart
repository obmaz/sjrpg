import 'dart:async';
import 'package:bonfire/bonfire.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/stage_content.dart';

T inCombatField<T extends Adventure>(T session) {
  final world = session.world, size = session.hero.body.size;
  final center = world.stage == WorldStage.forest
      ? const Offset(6014, 4212)
      : world.trails.first.points.firstWhere(
          (point) =>
              (point - world.sanctuary.center).distance >
                  world.sanctuary.radius + 900 &&
              !world.blocked(
                Rect.fromCenter(
                  center: point,
                  width: size.width,
                  height: size.height,
                ),
              ),
        );
  final at = world.spawnNear(
    center - Offset(size.width / 2, size.height / 2),
    size,
    avoidSanctuary: true,
  );
  if (at == null) {
    throw StateError(
      'The combat fixture needs a walkable field outside the sanctuary',
    );
  }
  session.hero.position.setValues(at.dx, at.dy);
  session.hero.lastClearPosition = at;
  return session;
}

class TestGame implements BonfireGameInterface {
  @override
  double timeScale = 1;
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

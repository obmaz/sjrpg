import 'dart:math' as math;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Adventure session({WorldStage stage = WorldStage.forest}) {
    final result = Adventure(GameArt(), stage: stage)..start(TestGame());
    addTearDown(result.dispose);
    return result;
  }

  Offset stored(Offset at) => Vector2(at.dx, at.dy).toOffset();

  ({Offset desired, Offset from}) wardContact(Adventure session) {
    final ward = session.world.sanctuary;
    const size = Size(24, 22);
    for (var angle = .08; angle < math.pi / 2; angle += .017) {
      final y = stored(
        ward.center + Offset(0, math.sin(angle) * ward.radius),
      ).dy;
      final dy = y - ward.center.dy;
      final x = ward.center.dx + math.sqrt(ward.radius * ward.radius - dy * dy);
      final desired = Offset(x + .0000001, y);
      final from = stored(desired + const Offset(2, 0));
      if (session.world.blocksEnemy(desired & size) ||
          !session.world.blocksEnemy(stored(desired) & size) ||
          session.world.blocksEnemy(from & size)) {
        continue;
      }
      final geometric = session.world.moveEnemy(from, desired - from, size);
      if (!session.world.blocksEnemy(geometric & size) &&
          session.world.blocksEnemy(stored(geometric) & size)) {
        return (desired: desired, from: from);
      }
    }
    throw StateError(
      'current ward must expose a legal double/blocked Float32 contact',
    );
  }

  double openRow(Adventure session) {
    for (var y = 2000.0; y < 16000; y += 64) {
      if (!session.world.blocksEnemy(Rect.fromLTWH(8170, y - 20, 130, 80))) {
        return y;
      }
    }
    throw StateError('precision fixture needs a clear row across x8192');
  }

  test('spawn rejects a legal double whose stored body enters the ward', () {
    final s = session(stage: WorldStage.sands);
    final desired = wardContact(s).desired;
    const size = Size(24, 22);
    expect(s.mobs, isEmpty);
    expect(s.sheltered, true);
    expect(s.world.blocksEnemy(desired & size), false);
    expect(s.world.blocksEnemy(stored(desired) & size), true);
    final enemy = s.spawnEnemy('goblin', desired)!;
    expect(s.world.blocksEnemy(enemy.body), false);
    expect(s.world.sanctuary.protects(enemy.body), false);
    expect(enemy.body.topLeft, isNot(stored(desired)));
    expect(enemy.body.overlaps(s.hero.body), false);
  });

  test('spawn tests rounded contact with a living mob before construction', () {
    final s = session();
    final y = openRow(s);
    final obstacle = s.spawnEnemy('goblin', Offset(8191.99853515625, y))!;
    final desired = Offset(obstacle.body.right, y);
    const size = Size(24, 22);
    expect((desired & size).overlaps(obstacle.body), false);
    expect((stored(desired) & size).overlaps(obstacle.body), true);
    expect(s.world.blocksEnemy(desired & size), false);
    final enemy = s.spawnEnemy('goblin', desired)!;
    expect(enemy.body.overlaps(obstacle.body), false);
    expect(s.world.blocksEnemy(enemy.body), false);
    expect(enemy.body.topLeft, isNot(stored(desired)));
  });

  test('spawn tests rounded hero contact before construction', () {
    final s = session();
    final y = openRow(s);
    s.hero.position.setValues(8191.99853515625, y);
    final desired = Offset(s.hero.body.right, y);
    const size = Size(24, 22);
    expect((desired & size).overlaps(s.hero.body), false);
    expect((stored(desired) & size).overlaps(s.hero.body), true);
    expect(s.world.blocksEnemy(desired & size), false);
    final enemy = s.spawnEnemy('goblin', desired)!;
    expect(enemy.body.overlaps(s.hero.body), false);
    expect(s.world.blocksEnemy(enemy.body), false);
    expect(enemy.body.topLeft, isNot(stored(desired)));
  });

  for (final boss in [false, true]) {
    test(
      'a valid ${boss ? 'boss' : 'ordinary'} spawn keeps its old stored point',
      () {
        final s = session();
        for (final desired in [
          const Offset(6200.31251, 4200.43751),
          const Offset(6300.15317, 4200.28513),
        ]) {
          final size = boss ? const Size(48, 40) : const Size(24, 22);
          expect(s.world.blocksEnemy(desired & size), false);
          expect(s.world.blocksEnemy(stored(desired) & size), false);
          final enemy = s.spawnEnemy('goblin', desired, boss: boss)!;
          expect(enemy.body.topLeft, stored(desired));
          expect(enemy.body.size, size);
          expect(s.world.blocksEnemy(enemy.body), false);
        }
      },
    );
  }

  for (final inactive in ['dead', 'dormant']) {
    test('$inactive bodies do not force a spawn relocation', () {
      final s = session();
      final y = openRow(s);
      final obstacle = s.spawnEnemy('goblin', Offset(8191.99853515625, y))!;
      if (inactive == 'dead') {
        obstacle.life.remove(obstacle.life.value);
      } else {
        obstacle.encounterDormant = true;
      }
      final desired = Offset(obstacle.body.right, y);
      expect(
        (stored(desired) & const Size(24, 22)).overlaps(obstacle.body),
        true,
      );
      final enemy = s.spawnEnemy('goblin', desired)!;
      expect(enemy.body.topLeft, stored(desired));
      expect(s.world.blocksEnemy(enemy.body), false);
    });
  }
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/enemy_spacing.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local crowd queries exclude distant bodies and follow cell crossings',
    () {
      final spacing = EnemySpacing<int>();
      for (var i = 0; i < 40; i++) {
        spacing.update(i, Rect.fromLTWH(i * 192, 100, 24, 22));
      }
      const bounds = Rect.fromLTWH(0, 60, 100, 100);
      expect(spacing.query(bounds), [0]);
      spacing.update(39, const Rect.fromLTWH(50, 100, 48, 40));
      expect(spacing.query(bounds).toSet(), {0, 39});
      spacing.remove(0);
      expect(spacing.query(bounds), [39]);
    },
  );

  Adventure session() {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    s.hero.invulnerable = 999;
    return s;
  }

  test(
    'converging pursuers keep separate bodies and still approach the hero',
    () {
      final s = session();
      final first = s.spawnEnemy('goblin', const Offset(6200, 4185))!;
      final second = s.spawnEnemy('goblin', const Offset(6200, 4210))!;
      final original = (first.body.center - s.hero.body.center).distance;
      for (var i = 0; i < 150; i++) {
        first.update(1 / 30);
        second.update(1 / 30);
        expect(first.body.overlaps(second.body), false);
        expect(s.world.blocksEnemy(first.body), false);
        expect(s.world.blocksEnemy(second.body), false);
      }
      expect(
        (first.body.center - s.hero.body.center).distance,
        lessThan(original / 2),
      );
      expect(
        (second.body.center - s.hero.body.center).distance,
        lessThan(original / 2),
      );
    },
  );

  test('a swept knockback stops at another monster instead of crossing it', () {
    final s = session();
    final pushed = s.spawnEnemy('goblin', const Offset(6200, 4200))!;
    final obstacle = s.spawnEnemy('goblin', const Offset(6250, 4200))!;
    pushed.stun = 2;
    pushed.push(const Offset(80, 0));
    for (var i = 0; i < 10; i++) {
      pushed.update(1 / 30);
      expect(pushed.body.overlaps(obstacle.body), false);
    }
    expect(pushed.body.right, lessThanOrEqualTo(obstacle.body.left));
    expect(pushed.body.left, greaterThan(6200));
  });

  test('large steps cannot tunnel through a nearby small body', () {
    final s = session();
    final first = s.spawnEnemy('goblin', const Offset(6200, 4200))!;
    final obstacle = s.spawnEnemy('goblin', const Offset(6250, 4200))!;
    final at = s.moveEnemyBody(first, first.body.topLeft, const Offset(160, 0));
    expect((at & first.body.size).overlaps(obstacle.body), false);
    expect(at.dx + first.body.width, lessThanOrEqualTo(obstacle.body.left));
  });

  test(
    'overlapping old positions can escape but cannot deepen penetration',
    () {
      final s = session();
      final first = s.spawnEnemy('goblin', const Offset(6200, 4200))!;
      final second = s.spawnEnemy('goblin', const Offset(6250, 4200))!;
      second.position.setValues(first.position.x + 10, first.position.y);
      s.updateEnemySpacing(second);
      final from = first.body.topLeft;
      final blocked = s.moveEnemyBody(first, from, const Offset(12, 0));
      expect(blocked, from);
      final escape = s.moveEnemyBody(first, from, const Offset(-24, 0));
      expect(escape.dx, lessThan(from.dx));
      expect((escape & first.body.size).overlaps(second.body), false);
    },
  );

  test('a large body respects crowd, terrain and the sanctuary boundary', () {
    final s = session();
    final boss = s.spawnEnemy('golem', const Offset(6200, 4200), boss: true)!;
    final small = s.spawnEnemy('goblin', const Offset(6280, 4200))!;
    final at = s.moveEnemyBody(boss, boss.body.topLeft, const Offset(160, 0));
    expect((at & boss.body.size).overlaps(small.body), false);
    expect(s.world.blocksEnemy(at & boss.body.size), false);
    final ward = s.world.sanctuary;
    final outside = s.world.spawnNear(
      ward.center,
      boss.body.size,
      avoidSanctuary: true,
    )!;
    boss.position.setValues(outside.dx, outside.dy);
    s.updateEnemySpacing(boss);
    final inward = ward.center - boss.body.center;
    final approach = s.moveEnemyBody(boss, outside, inward);
    expect(s.world.blocksEnemy(approach & boss.body.size), false);
    expect(ward.protects(approach & boss.body.size), false);
  });

  test(
    'a small body contained in an old boss position escapes in bounded steps',
    () {
      final s = session();
      final boss = s.spawnEnemy('golem', const Offset(6200, 4200), boss: true)!;
      final small = s.spawnEnemy('goblin', const Offset(6280, 4200))!;
      final center = boss.body.center;
      small.position.setValues(
        center.dx - small.body.width / 2,
        center.dy - small.body.height / 2,
      );
      s.updateEnemySpacing(small);
      expect(boss.body.contains(small.body.topLeft), true);
      var from = small.body.topLeft;
      for (var i = 0; i < 8; i++) {
        final next = s.moveEnemyBody(small, from, const Offset(6, 0));
        expect((next - from).distance, closeTo(6, .001));
        small.position.setValues(next.dx, next.dy);
        s.updateEnemySpacing(small);
        expect(s.world.blocksEnemy(small.body), false);
        if (i == 0) {
          expect(
            s.moveEnemyBody(small, next, const Offset(-6, 0)),
            next,
            reason:
                'equal-area overlap cannot move back toward the boss center',
          );
        }
        from = next;
      }
      expect(small.body.overlaps(boss.body), false);
    },
  );

  test('dead and dormant enemies do not leave invisible crowd obstacles', () {
    final s = session();
    final first = s.spawnEnemy('goblin', const Offset(6200, 4200))!;
    final obstacle = s.spawnEnemy('goblin', const Offset(6250, 4200))!;
    obstacle.encounterDormant = true;
    final from = first.body.topLeft;
    final at = s.moveEnemyBody(first, from, const Offset(100, 0));
    expect(at.dx, closeTo(from.dx + 100, .001));
    obstacle.encounterDormant = false;
    obstacle.life.remove(obstacle.life.value);
    final afterDeath = s.moveEnemyBody(first, from, const Offset(100, 0));
    expect(afterDeath.dx, closeTo(from.dx + 100, .001));
  });
}

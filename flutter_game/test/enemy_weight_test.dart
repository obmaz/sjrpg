import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/enemy_motion.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session() {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    s.mobs.clear();
    s.hero.invulnerable = 999;
    addTearDown(s.dispose);
    return s;
  }

  void advance(Adventure s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 30) {
      s.elapsed += 1 / 30;
      for (final mob in s.mobs.toList()) {
        mob.update(1 / 30);
      }
    }
  }

  test('fresh crowded spawns reserve visual body space immediately', () {
    final s = session();
    for (var i = 0; i < 8; i++) {
      expect(
        s.spawnEnemy('goblin', const Offset(6300, 4200), reserveSpacing: true),
        isNotNull,
      );
    }
    for (var i = 0; i < s.mobs.length; i++) {
      final a = s.mobs[i];
      for (final b in s.mobs.skip(i + 1)) {
        expect(
          HuntEnemy.tooClose(
            a.body.center,
            a.personalSpace,
            b.body.center,
            b.personalSpace,
          ),
          false,
          reason: 'distinct artwork needs visible foot spacing at spawn',
        );
      }
    }
  });

  test(
    'monster appearance scales down without changing its collision body',
    () {
      final s = session();
      final mob = s.spawnEnemy('goblin', const Offset(6300, 4200))!;
      final boss = s.spawnEnemy(
        'goblin',
        const Offset(6500, 4200),
        boss: true,
      )!;
      expect(mob.body.size, const Size(24, 22));
      expect(boss.body.size, const Size(48, 40));
      expect(
        mob.visualHeight,
        closeTo((mob.definition?.renderHeight ?? 62) * .8, 1e-8),
      );
      expect(boss.visualHeight, 100);
    },
  );

  test('a dense pack leaves distinct personal foot space around the hero', () {
    final s = session();
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        final enemy = s.spawnEnemy(
          'goblin',
          Offset(6200 + col * 36, 4155 + row * 30),
        )!;
        enemy.attackClock = 10;
      }
    }
    advance(s, 6);
    var minimum = double.infinity;
    for (var i = 0; i < s.mobs.length; i++) {
      final a = s.mobs[i];
      expect(s.world.blocksEnemy(a.body), false);
      expect(a.body.overlaps(s.hero.body), false);
      for (final b in s.mobs.skip(i + 1)) {
        expect(a.body.overlaps(b.body), false);
        final d = a.body.center - b.body.center;
        minimum = math.min(
          minimum,
          math.sqrt(d.dx * d.dx / (44 * 44) + d.dy * d.dy / (34 * 34)),
        );
      }
    }
    expect(
      minimum,
      greaterThan(.86),
      reason:
          'separate hitboxes alone still overlap wide monster illustrations',
    );
    expect(
      s.mobs
          .where((e) => (e.body.center - s.hero.body.center).distance < 100)
          .length,
      greaterThan(5),
    );
  });

  test(
    'stationary survivors restored at identical positions gradually separate',
    () {
      final s = session();
      for (var i = 0; i < 4; i++) {
        final mob = s.spawnEnemy('goblin', Offset(6180 + i * 40, 4200))!;
        mob.position.setValues(6038, 4200);
        mob.attackClock = 999;
        s.updateEnemySpacing(mob);
      }
      advance(s, 2);
      for (var i = 0; i < s.mobs.length; i++) {
        final a = s.mobs[i];
        expect(s.world.blocksEnemy(a.body), false);
        expect(a.body.overlaps(s.hero.body), false);
        for (final b in s.mobs.skip(i + 1)) {
          expect(a.body.overlaps(b.body), false);
        }
      }
    },
  );

  test('pursuit accelerates promptly and integrates equally at30and60Hz', () {
    final locations = <Offset>[];
    for (final rate in [30, 60]) {
      final s = session();
      final mob = s.spawnEnemy('goblin', const Offset(6500, 4200))!;
      final origin = mob.body.topLeft;
      mob.update(1 / rate);
      expect(
        (mob.body.topLeft - origin).distance,
        inExclusiveRange(0, mob.speed / rate),
      );
      for (var i = 1; i < rate; i++) {
        mob.update(1 / rate);
      }
      expect(
        (mob.body.topLeft - origin).distance,
        greaterThan(mob.speed * .85),
      );
      locations.add(mob.body.topLeft);
    }
    expect((locations[0] - locations[1]).distance, lessThan(.03));
    final a = EnemyInertia(), b = EnemyInertia();
    var slow = Offset.zero, fast = Offset.zero;
    for (var i = 0; i < 30; i++) {
      slow += a.advance(const Offset(120, 0), 1 / 30);
    }
    for (var i = 0; i < 60; i++) {
      fast += b.advance(const Offset(120, 0), 1 / 60);
    }
    expect((slow - fast).distance, lessThan(.000001));
    expect((a.velocity - b.velocity).distance, lessThan(.000001));
  });

  test('heavy enemies resist a hit without delaying its actual damage', () {
    final s = session();
    final light = s.spawnEnemy('goblin', const Offset(6300, 4200))!..stun = 4;
    final heavy = s.spawnEnemy('golem', const Offset(6300, 4320), boss: true)!
      ..stun = 4;
    final lightStart = light.body.left, heavyStart = heavy.body.left;
    final lightHp = light.life.value, heavyHp = heavy.life.value;
    s.hit(light, 2, const Offset(42, 0));
    s.hit(heavy, 2, const Offset(42, 0));
    expect(light.life.value, lightHp - 2);
    expect(heavy.life.value, heavyHp - 2);
    expect(light.body.left, lightStart);
    expect(heavy.body.left, heavyStart);
    for (var i = 0; i < 20; i++) {
      light.update(1 / 60);
      heavy.update(1 / 60);
    }
    expect(light.body.left - lightStart, closeTo(42, .001));
    expect(heavy.body.left - heavyStart, inExclusiveRange(0, 25));
    expect(s.world.blocksEnemy(heavy.body), false);
  });

  test('a swept knockback cannot push a monster through the hero', () {
    final s = session();
    final enemy = s.spawnEnemy('goblin', const Offset(6060, 4200))!..stun = 4;
    enemy.push(const Offset(-80, 0));
    for (var i = 0; i < 20; i++) {
      enemy.update(1 / 60);
      expect(enemy.body.overlaps(s.hero.body), false);
      expect(enemy.body.left, greaterThanOrEqualTo(s.hero.body.right));
    }
  });

  test('a personal-space queue still passes an authored narrow tree gap', () {
    final s = session();
    const body = Size(24, 22);
    ({Offset hero, List<Offset> queue, double exit})? corridor;
    for (final a in s.world.props) {
      if (a.kind != 'tree') continue;
      for (final b in s.world.props) {
        final gap = b.body.left - a.body.right;
        if (b.kind != 'tree' ||
            gap < 30 ||
            gap > 42 ||
            !a.body.overlaps(b.body.inflate(44))) {
          continue;
        }
        final top = math.min(a.body.top, b.body.top),
            bottom = math.max(a.body.bottom, b.body.bottom);
        final centerX = (a.body.right + b.body.left) / 2;
        final hero = Offset(centerX - s.hero.body.width / 2, top - 140);
        final queue = [
          for (var i = 0; i < 3; i++)
            Offset(centerX - body.width / 2, bottom + 55 + i * 50),
        ];
        if (s.world.blocked(hero & s.hero.body.size) ||
            queue.any((at) => s.world.blocksEnemy(at & body)) ||
            !s.world.clearEnemyLine(queue.last, hero, body)) {
          continue;
        }
        corridor = (hero: hero, queue: queue, exit: top);
        break;
      }
      if (corridor != null) break;
    }
    expect(
      corridor,
      isNotNull,
      reason: 'use a real narrow tree corridor, with actual terrain clearance',
    );
    final c = corridor!;
    s.hero.position.setValues(c.hero.dx, c.hero.dy);
    for (final at in c.queue) {
      s.spawnEnemy('goblin', at)!.attackClock = 999;
    }
    advance(s, 6);
    for (var i = 0; i < s.mobs.length; i++) {
      final mob = s.mobs[i];
      expect(s.world.blocksEnemy(mob.body), false);
      expect(mob.body.bottom, lessThan(c.exit));
      for (final other in s.mobs.skip(i + 1)) {
        expect(mob.body.overlaps(other.body), false);
      }
    }
  });

  test('a settled idle crowd does not oscillate against its attack radius', () {
    final s = session();
    for (var i = 0; i < 4; i++) {
      final mob = s.spawnEnemy('goblin', Offset(6180 + i * 40, 4200))!;
      mob.position.setValues(6038, 4200);
      mob.attackClock = 999;
      s.updateEnemySpacing(mob);
    }
    advance(s, 5);
    final origins = [for (final mob in s.mobs) mob.body.topLeft];
    final travel = List<double>.filled(s.mobs.length, 0);
    for (var frame = 0; frame < 30; frame++) {
      final before = [for (final mob in s.mobs) mob.body.topLeft];
      advance(s, 1 / 30);
      for (var i = 0; i < s.mobs.length; i++) {
        travel[i] += (s.mobs[i].body.topLeft - before[i]).distance;
      }
    }
    for (var i = 0; i < s.mobs.length; i++) {
      final displacement = (s.mobs[i].body.topLeft - origins[i]).distance;
      expect(
        travel[i] - displacement,
        lessThan(.5),
        reason:
            'the attack ring must settle instead of vibrating backwards and forwards',
      );
    }
  });
}

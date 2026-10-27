import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/enemy_catalog.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  late TestGame game;
  setUp(() {
    game = TestGame();
    s = inCombatField(Adventure(GameArt()))..start(game);
    s.mobs.clear();
    s.hero.position.setValues(6000, 4200);
    s.hero.invulnerable = 0;
  });
  tearDown(() => s.dispose());

  test('new species belong to their distinct chapter populations', () {
    const expected = {
      WorldStage.tombs: 'bonehound',
      WorldStage.foundry: 'clockwork-spider',
      WorldStage.convergence: 'crystal-beetle',
    };
    for (final stage in WorldStage.values) {
      for (final wooded in [false, true]) {
        for (final ruins in [false, true]) {
          final pool = biomeEnemies(stage, wooded: wooded, ruins: ruins);
          expect(pool.every(enemyCatalog.containsKey), true);
          for (final entry in expected.entries) {
            expect(
              pool.contains(entry.value),
              stage == entry.key,
              reason: '${entry.value} belongs only to ${entry.key.name}',
            );
          }
        }
      }
    }
  });

  test(
    'baseline attacks stay intact and control shots give longer warnings',
    () {
      for (final (kind, warning, range, speed, height) in [
        ('wolf', .42, 240.0, 520.0, 55.0),
        ('scorpion', .58, 200.0, 440.0, 62.0),
        ('viper', .55, 170.0, 420.0, 44.0),
      ]) {
        final enemy = HuntEnemy(s, kind, const Offset(6000, 4000));
        expect(enemy.pounceWarning, warning);
        expect(enemy.pounceRange, range);
        expect(enemy.pounceSpeed, speed);
        expect(enemy.definition!.renderHeight, height);
      }
      final troll = HuntEnemy(s, 'troll', const Offset(6000, 4000));
      expect(
        (
          troll.sweepRange,
          troll.sweepWarning,
          troll.sweepDamage,
          troll.sweepRecovery,
        ),
        (120, .85, 14, 2.6),
      );
      expect(troll.definition!.renderHeight, 80);
      final guard = HuntEnemy(s, 'gunner', const Offset(6000, 4000));
      expect(guard.boltWarning, .9);
      expect(guard.definition!.onHitStatus, PlayerStatus.blind);
      expect(guard.technological, true);
      expect(HuntEnemy(s, 'cultist', Offset.zero).technological, false);
    },
  );

  test('bonehound gives a readable committed lunge that a sidestep avoids', () {
    final enemy = s.spawnEnemy('bonehound', const Offset(6160, 4200))!
      ..attackClock = 0;
    enemy.update(.05);
    expect(enemy.windup, .6);
    final locked = enemy.pounceGoal, hp = s.progress.hp;
    s.pause();
    enemy.update(.5);
    expect(enemy.windup, .6);
    s.resume();
    s.hero.position.y += 130;
    var started = false;
    for (var i = 0; i < 40; i++) {
      enemy.update(.05);
      started |= enemy.pounceRemaining > 0;
      if (started && enemy.pounceRemaining == 0) break;
    }
    expect(started, true);
    expect(s.progress.hp, hp);
    expect((enemy.body.center.dy - locked!.dy).abs(), lessThan(2));
    expect(enemy.attackClock, greaterThan(3));
  });

  test('bonehound lunge scales nine base damage once and respects a stun', () {
    final enemy = s.spawnEnemy('bonehound', const Offset(6160, 4200))!
      ..attackClock = 0;
    final hp = s.progress.hp;
    for (var i = 0; i < 26; i++) {
      enemy.update(.05);
    }
    expect(
      s.progress.hp,
      closeTo(hp - s.progress.mitigate(enemy.outgoingDamage(9)), .001),
    );
    expect(enemy.body.overlaps(s.hero.body), false);
    final after = s.progress.hp;
    s.hero.invulnerable = 0;
    for (var i = 0; i < 20; i++) {
      enemy.update(.05);
    }
    expect(s.progress.hp, after);
    enemy.position.setValues(6160, 4200);
    enemy.attackClock = 0;
    enemy.update(.05);
    expect(enemy.windup, .6);
    enemy.stun = 1;
    enemy.update(.05);
    expect(enemy.windup, 0);
    expect(enemy.pounceGoal, isNull);
    expect(s.progress.hp, after);
  });

  test(
    'clockwork spider warns before a slower net at the last locked point',
    () {
      final enemy = s.spawnEnemy('clockwork-spider', const Offset(6260, 4200))!
        ..attackClock = 0;
      enemy.update(.05);
      expect(enemy.windup, .9);
      expect(enemy.lowProfile, true);
      final locked = enemy.slamTarget!, hp = s.progress.hp;
      s.hero.position.y += 120;
      for (var i = 0; i < 17; i++) {
        enemy.update(.05);
      }
      expect(game.added.whereType<ShadowBolt>(), isEmpty);
      for (var i = 0; i < 2; i++) {
        enemy.update(.05);
      }
      final bolt = game.added.whereType<ShadowBolt>().single;
      expect(bolt.technological, true);
      expect(bolt.damage, enemy.outgoingDamage(8));
      expect(bolt.status, PlayerStatus.root);
      expect(bolt.statusPotency, enemy.outgoingDamage(1));
      final toward = locked - enemy.body.center;
      expect(
        math.atan2(bolt.direction.dy, bolt.direction.dx),
        closeTo(math.atan2(toward.dy, toward.dx), .001),
      );
      final beforeShot = bolt.position.clone();
      bolt.update(.05);
      expect((bolt.position - beforeShot).length, closeTo(12, .001));
      for (var i = 0; i < 44; i++) {
        bolt.update(.05);
      }
      expect(s.progress.hp, hp);
      expect(bolt.resolved, true);
      expect(enemy.attackClock, greaterThan(4.4));
    },
  );

  test('crystal beetle braces before its fixed cone and hits only once', () {
    final enemy = s.spawnEnemy('crystal-beetle', const Offset(6090, 4200))!
      ..attackClock = 0;
    final body = enemy.body, hp = s.progress.hp;
    enemy.update(.05);
    expect(enemy.windup, .7);
    expect(enemy.lowProfile, true);
    expect(enemy.body, body);
    for (var i = 0; i < 15; i++) {
      enemy.update(.05);
    }
    expect(
      s.progress.hp,
      closeTo(hp - s.progress.mitigate(enemy.outgoingDamage(9)), .001),
    );
    expect(game.added.whereType<EnemySwipe>(), hasLength(1));
    final after = s.progress.hp;
    s.hero.invulnerable = 0;
    for (var i = 0; i < 20; i++) {
      enemy.update(.05);
    }
    expect(s.progress.hp, after);
    expect(enemy.body, body);
  });

  for (final kind in ['bonehound', 'clockwork-spider', 'crystal-beetle']) {
    test(
      '$kind stays on the ground collision layer and persists with its health',
      () {
        final tree = s.world.props.firstWhere(
          (p) =>
              p.kind == 'tree' &&
              !s.world.blocked(
                Rect.fromLTWH(p.body.left - 70, p.body.center.dy - 11, 24, 22),
                avoidSanctuary: true,
              ) &&
              !s.world.blocked(
                Rect.fromLTWH(p.body.right + 30, p.body.center.dy - 11, 24, 22),
                avoidSanctuary: true,
              ),
        );
        final at = Offset(tree.body.left - 70, tree.body.center.dy - 11);
        final enemy = s.spawnEnemy(kind, at)!;
        final moved = s.moveEnemyBody(
          enemy,
          at,
          const Offset(200, 0),
          steer: false,
        );
        expect(
          moved.dx,
          lessThanOrEqualTo(tree.body.left - enemy.size.x + .001),
        );
        enemy.position.setValues(moved.dx, moved.dy);
        expect(s.world.blocksEnemy(enemy.body), false);
        enemy.life.update(enemy.life.value - 7);
        final checkpoint = GameCheckpoint.capture(s)!;
        final restored = GameCheckpoint.decode(
          checkpoint.encode(),
        )!.restore(GameArt());
        addTearDown(restored.dispose);
        final saved = restored.dormantEnemies.single;
        expect(saved['kind'], kind);
        expect(saved['hp'], enemy.life.value);
        s.hero.position.setValues(s.world.spawn.dx, s.world.spawn.dy);
        enemy.windup = .1;
        enemy.update(.05);
        expect(
          enemy.windup,
          0,
          reason: 'sanctuary cancels every attack family',
        );
        expect(s.progress.hp, s.progress.maxHp);
      },
    );
  }
}

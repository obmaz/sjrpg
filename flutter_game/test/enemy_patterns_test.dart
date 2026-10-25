import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  late TestGame game;
  setUp(() {
    s = Adventure(GameArt());
    game = TestGame();
    s.start(game);
    s.mobs.clear();
    s.hero.position.setValues(6000, 4200);
  });
  tearDown(() => s.dispose());
  test(
    'wolf commits to its warning direction, pauses and can be sidestepped',
    () {
      final wolf = s.spawnEnemy('wolf', const Offset(6200, 4200))!
        ..attackClock = 0;
      wolf.update(.05);
      expect(wolf.windup, greaterThan(0));
      final goal = wolf.pounceGoal, windup = wolf.windup;
      s.hero.position.y += 120;
      s.pause();
      wolf.update(.5);
      expect(wolf.windup, windup);
      s.resume();
      final hp = s.progress.hp;
      var started = false;
      for (var i = 0; i < 35; i++) {
        wolf.update(.05);
        if (wolf.pounceRemaining > 0) started = true;
        if (started && wolf.pounceRemaining == 0) break;
      }
      expect(started, true);
      expect(s.progress.hp, hp);
      expect(wolf.position.x, lessThan(6100));
      expect((wolf.body.center.dy - goal!.dy).abs(), lessThan(2));
      expect(wolf.pounceRemaining, 0);
    },
  );
  test(
    'pounce hits once, stops before overlap and respects roll invulnerability',
    () {
      final wolf = s.spawnEnemy('wolf', const Offset(6160, 4200))!
        ..attackClock = 0;
      final hp = s.progress.hp;
      for (var i = 0; i < 22; i++) {
        wolf.update(.05);
      }
      expect(s.progress.hp, lessThan(hp));
      final after = s.progress.hp;
      expect(wolf.body.overlaps(s.hero.body), false);
      s.hero.invulnerable = 0;
      for (var i = 0; i < 25; i++) {
        wolf.update(.05);
      }
      expect(s.progress.hp, after);
      wolf.position.setValues(6160, 4200);
      wolf.attackClock = 0;
      s.hero.invulnerable = 2;
      for (var i = 0; i < 22; i++) {
        wolf.update(.05);
      }
      expect(s.progress.hp, after);
    },
  );
  test('a pounce cannot pass a tree or another ground enemy', () {
    final tree = s.world.props.firstWhere(
      (p) =>
          p.kind == 'tree' &&
          !s.world.blocked(
            Rect.fromLTWH(p.body.left - 70, p.body.center.dy - 11, 24, 22),
          ) &&
          !s.world.blocked(
            Rect.fromLTWH(p.body.right + 30, p.body.center.dy - 11, 24, 22),
          ),
    );
    s.hero.position.setValues(tree.body.right + 30, tree.body.center.dy - 11);
    final wolf =
        s.spawnEnemy(
            'wolf',
            Offset(tree.body.left - 70, tree.body.center.dy - 11),
          )!
          ..pounceRemaining = .5
          ..pounceDuration = .5
          ..pounceBearing = 0;
    final hp = s.progress.hp;
    for (var i = 0; i < 12; i++) {
      wolf.update(.05);
      expect(s.world.blocked(wolf.body), false);
      if (wolf.pounceRemaining == 0) break;
    }
    expect(wolf.body.right, lessThanOrEqualTo(tree.body.left + 1));
    expect(s.progress.hp, hp);
    s.mobs.clear();
    s.hero.position.setValues(6200, 4200);
    final blocker = s.spawnEnemy('skeleton', const Offset(6070, 4200))!;
    final runner = s.spawnEnemy('wolf', const Offset(6000, 4200))!
      ..pounceRemaining = .4
      ..pounceDuration = .4
      ..pounceBearing = 0;
    for (var i = 0; i < 8; i++) {
      runner.update(.05);
      if (runner.pounceRemaining == 0) break;
    }
    expect(runner.body.overlaps(blocker.body), false);
    expect(runner.body.right, lessThanOrEqualTo(blocker.body.left));
    expect(s.progress.hp, hp);
  });
  test(
    'stun interrupts a charging or leaping wolf and prevents an immediate retry',
    () {
      final wolf = s.spawnEnemy('wolf', const Offset(6160, 4200))!
        ..attackClock = 0;
      wolf.update(.05);
      wolf.stun = .5;
      wolf.update(.05);
      expect(wolf.windup, 0);
      expect(wolf.pounceGoal, null);
      expect(wolf.attackClock, greaterThan(1));
      wolf.stun = 0;
      wolf.attackClock = 0;
      for (var i = 0; i < 10; i++) {
        wolf.update(.05);
      }
      expect(wolf.pounceRemaining, greaterThan(0));
      wolf.stun = 1;
      final before = wolf.position.clone();
      wolf.update(.05);
      expect(wolf.pounceRemaining, 0);
      expect(wolf.position, before);
      expect(wolf.attackClock, greaterThan(1));
    },
  );
  test(
    'skeleton warns before its fixed cone; a sidestep or stun cancels damage',
    () {
      final enemy = s.spawnEnemy('skeleton', const Offset(6080, 4200))!
        ..attackClock = 0;
      enemy.update(.05);
      expect(enemy.windup, greaterThan(0));
      final hp = s.progress.hp;
      for (var i = 0; i < 4; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, hp);
      s.hero.position.y += 100;
      for (var i = 0; i < 9; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, hp);
      expect(game.added.whereType<EnemySwipe>().length, 1);
      s.hero.position.setValues(6000, 4200);
      enemy.attackClock = 0;
      enemy.update(.05);
      enemy.stun = 1;
      enemy.update(.05);
      expect(enemy.windup, 0);
      expect(s.progress.hp, hp);
      enemy.stun = 0;
      enemy.attackClock = 0;
      for (var i = 0; i < 13; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, lessThan(hp));
      expect(game.added.whereType<EnemySwipe>().length, 2);
    },
  );
  test(
    'skeleton sweeps cannot damage through terrain even with a prestarted swing',
    () {
      final tree = s.world.props.firstWhere(
        (p) =>
            p.kind == 'tree' &&
            !s.world.blocked(
              Rect.fromLTWH(p.body.left - 40, p.body.center.dy - 11, 24, 22),
            ) &&
            !s.world.blocked(
              Rect.fromLTWH(p.body.right + 15, p.body.center.dy - 11, 24, 22),
            ),
      );
      s.hero.position.setValues(tree.body.right + 15, tree.body.center.dy - 11);
      final enemy =
          s.spawnEnemy(
              'skeleton',
              Offset(tree.body.left - 40, tree.body.center.dy - 11),
            )!
            ..windup = .3
            ..bearing = 0
            ..slamTarget = s.hero.body.center;
      final hp = s.progress.hp;
      for (var i = 0; i < 8; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, hp);
      final effect = game.added.whereType<EnemySwipe>().single;
      s.pause();
      effect.update(.1);
      expect(effect.age, 0);
      s.resume();
      effect.update(.05);
      expect(effect.age, closeTo(.05, .001));
      expect(enemy.bearing.abs(), lessThanOrEqualTo(math.pi));
    },
  );
}

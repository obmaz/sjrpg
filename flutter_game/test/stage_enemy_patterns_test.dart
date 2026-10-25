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
  test('scorpion warns, commits to a dodgeable lunge and stops at terrain', () {
    final enemy = s.spawnEnemy('scorpion', const Offset(6160, 4200))!
      ..attackClock = 0;
    enemy.update(.05);
    expect(enemy.windup, closeTo(.58, .001));
    final goal = enemy.pounceGoal!;
    s.hero.position.y += 120;
    final hp = s.progress.hp;
    var started = false;
    for (var i = 0; i < 35; i++) {
      enemy.update(.05);
      if (enemy.pounceRemaining > 0) started = true;
      if (started && enemy.pounceRemaining == 0) break;
    }
    expect(started, true);
    expect(s.progress.hp, hp);
    expect((enemy.body.center.dy - goal.dy).abs(), lessThan(2));
    expect(enemy.position.x, lessThan(6100));
    expect(enemy.pounceRemaining, 0);
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
    enemy.position.setValues(tree.body.left - 70, tree.body.center.dy - 11);
    enemy.pounceRemaining = .5;
    enemy.pounceBearing = 0;
    final startX = enemy.position.x;
    for (var i = 0; i < 12; i++) {
      enemy.update(.05);
      expect(s.world.blocked(enemy.body), false);
      if (enemy.pounceRemaining == 0) break;
    }
    expect(enemy.position.x, greaterThan(startX));
    expect(enemy.pounceRemaining, 0);
    expect(enemy.body.right, lessThanOrEqualTo(tree.body.left + 1));
    expect(s.progress.hp, hp);
  });
  test(
    'troll sweep has a longer warning, a fixed cone and one damage event',
    () {
      final enemy = s.spawnEnemy('troll', const Offset(6090, 4200))!
        ..attackClock = 0;
      enemy.update(.05);
      expect(enemy.windup, closeTo(.85, .001));
      final hp = s.progress.hp;
      for (var i = 0; i < 12; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, hp);
      s.hero.position.y += 130;
      for (var i = 0; i < 6; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, hp);
      expect(game.added.whereType<EnemySwipe>().length, 1);
      s.hero.position.setValues(6000, 4200);
      enemy.position.setValues(6090, 4200);
      enemy.attackClock = 0;
      for (var i = 0; i < 20; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, lessThan(hp));
      final after = s.progress.hp;
      for (var i = 0; i < 20; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, after);
      expect(game.added.whereType<EnemySwipe>().length, 2);
    },
  );
  test(
    'pulse rifle guard locks a charged shot, pauses and lets a sidestep escape',
    () {
      final enemy = s.spawnEnemy('gunner', const Offset(6300, 4200))!
        ..attackClock = 0;
      enemy.update(.05);
      expect(enemy.windup, closeTo(.8, .001));
      final warning = enemy.windup;
      s.pause();
      enemy.update(.5);
      expect(enemy.windup, warning);
      s.resume();
      s.hero.position.y += 100;
      for (var i = 0; i < 18; i++) {
        enemy.update(.05);
      }
      final bolt = game.added.whereType<ShadowBolt>().single;
      expect(bolt.technological, true);
      expect(bolt.direction.dx, closeTo(-1, .001));
      expect(bolt.direction.dy, closeTo(0, .001));
      final hp = s.progress.hp;
      for (var i = 0; i < 45; i++) {
        bolt.update(.05);
      }
      expect(s.progress.hp, hp);
      expect(bolt.resolved, true);
    },
  );
  test(
    'cyber sword guard warns before a fixed sweep and never fires a rifle projectile',
    () {
      final enemy = s.spawnEnemy('cyber', const Offset(6070, 4200))!
        ..attackClock = 0;
      enemy.update(.05);
      expect(enemy.windup, closeTo(.65, .001));
      final hp = s.progress.hp;
      for (var i = 0; i < 10; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, hp);
      final warning = enemy.windup;
      s.pause();
      enemy.update(.5);
      expect(enemy.windup, warning);
      s.resume();
      s.hero.position.y += 130;
      for (var i = 0; i < 5; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, hp);
      expect(game.added.whereType<EnemySwipe>().length, 1);
      s.hero.position.setValues(6000, 4200);
      enemy.position.setValues(6070, 4200);
      enemy.attackClock = 0;
      for (var i = 0; i < 16; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, lessThan(hp));
      final after = s.progress.hp;
      for (var i = 0; i < 15; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, after);
      expect(game.added.whereType<EnemySwipe>().length, 2);
      expect(game.added.whereType<ShadowBolt>(), isEmpty);
    },
  );
  for (final kind in ['scorpion', 'troll', 'cyber', 'gunner']) {
    test('$kind stun cancels its warning and gives a recovery window', () {
      final enemy = s.spawnEnemy(kind, const Offset(6080, 4200))!
        ..attackClock = 0;
      enemy.update(.05);
      expect(enemy.windup, greaterThan(0));
      enemy.stun = .2;
      enemy.update(.05);
      expect(enemy.windup, 0);
      expect(enemy.slamTarget, null);
      expect(enemy.pounceGoal, null);
      expect(enemy.attackClock, greaterThanOrEqualTo(1.2));
      enemy.stun = 0;
      enemy.update(.05);
      expect(enemy.windup, 0);
      expect(game.added.whereType<ShadowBolt>(), isEmpty);
      expect(game.added.whereType<EnemySwipe>(), isEmpty);
    });
  }
}

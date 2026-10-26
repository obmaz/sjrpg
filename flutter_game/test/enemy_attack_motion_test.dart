import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_motion.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  setUp(() {
    s = inCombatField(Adventure(GameArt()))..start(TestGame());
    s.mobs.clear();
    s.hero.position.setValues(6000, 4200);
    s.hero.invulnerable = 0;
  });
  tearDown(() => s.dispose());

  HuntEnemy attacker(String kind, {bool boss = false}) =>
      s.spawnEnemy(kind, const Offset(6034, 4200), boss: boss)!
        ..attackClock = 0
        ..slamClock = 10;
  void impact(HuntEnemy enemy) {
    for (var i = 0; i < 12 && enemy.meleeWindup > 0; i++) {
      enemy.update(1 / 30);
    }
  }

  for (final (kind, boss) in [
    ('goblin', false),
    ('mummy', false),
    ('golem', true),
  ]) {
    test('$kind melee announces its strike before dealing one hit', () {
      final enemy = attacker(kind, boss: boss), hp = s.progress.hp;
      enemy.update(1 / 30);
      expect(enemy.meleeWindup, greaterThan(0));
      expect(s.progress.hp, hp);
      expect(enemy.preparingAttack, true);
      final body = enemy.body, clock = enemy.attackClock;
      s.pause();
      enemy.update(.5);
      expect(enemy.attackClock, clock);
      expect(enemy.body, body);
      s.resume();
      impact(enemy);
      expect(s.progress.hp, lessThan(hp));
      expect(enemy.attackMotion.active, true);
      expect(enemy.attackMotion.pose, EnemyAttackPose.melee);
      expect(enemy.body, body);
      final after = s.progress.hp;
      s.hero.invulnerable = 0;
      enemy.update(1 / 30);
      expect(s.progress.hp, after);
    });
  }
  test(
    'leaving reach during a melee warning makes the physical strike miss',
    () {
      final enemy = attacker('goblin'), hp = s.progress.hp;
      enemy.update(1 / 30);
      s.hero.position.x -= 120;
      impact(enemy);
      expect(s.progress.hp, hp);
      expect(enemy.attackMotion.active, true);
    },
  );
  test('stun or a sanctuary cancels the pending melee damage and pose', () {
    for (final sanctuary in [false, true]) {
      final enemy = attacker('goblin'), hp = s.progress.hp;
      enemy.update(1 / 30);
      expect(enemy.meleeWindup, greaterThan(0));
      if (sanctuary) {
        s.hero.position.setValues(s.world.spawn.dx, s.world.spawn.dy);
      } else {
        enemy.stun = .5;
      }
      enemy.update(1 / 30);
      expect(enemy.meleeWindup, 0);
      expect(enemy.attackMotion.active, false);
      expect(s.progress.hp, hp);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
    }
  });
}

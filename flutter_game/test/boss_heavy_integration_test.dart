import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/boss_attacks.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'twenty seconds of held selected heavy basic cannot suppress every boss special',
    () {
      final s = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.waveTime = 10000;
      s.progress.gainXp(8000);
      s.syncLife();
      for (final id in ['cleave', 'mastery', 'heavyStrike']) {
        expect(
          s.progress.learn(
            s.progress.skills.firstWhere((skill) => skill.id == id),
          ),
          true,
        );
      }
      expect(s.progress.selectBasic('heavyStrike'), true);
      final at = s.hero.position.toOffset();
      s.hero.position.x += 90;
      final boss = s.spawnEnemy('golem', at, boss: true)!
        ..slamClock = 0
        ..attackClock = 100;
      final initialBossHp = boss.life.value, initialHeroHp = s.progress.hp;
      s.holdAttack('touch:heavy-basic', true);
      for (var i = 0; i < 400 && s.active; i++) {
        s.hero.update(.05);
        boss.update(.05);
        s.tick(.05);
      }
      final impacts = (s.game! as TestGame).added
          .whereType<BossAttackVisual>()
          .where(
            (effect) =>
                effect.impact && effect.pattern.power != BossPower.impact,
          )
          .toList();
      expect(s.hero.strikes, greaterThan(12));
      expect(boss.life.value, lessThan(initialBossHp));
      expect(boss.isDead, false);
      expect(impacts.length, greaterThanOrEqualTo(2));
      expect(
        impacts.any(
          (effect) =>
              effect.pattern.power == BossPower.dispel ||
              effect.pattern.power == BossPower.freeze,
        ),
        true,
      );
      expect(s.progress.hp, lessThan(initialHeroHp));
    },
  );
}

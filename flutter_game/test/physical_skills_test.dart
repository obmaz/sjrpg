import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  setUp(() {
    s = Adventure(GameArt())..start(TestGame());
    s.mobs.clear();
    s.hero.position.setValues(6000, 4200);
    s.hero.bearing = 0;
    s.progress.gainXp(8000);
    s.progress.ranks.addAll({'charge': 1, 'crushingBlow': 1});
    s.progress.energy = s.progress.maxEnergy;
  });
  tearDown(() => s.dispose());
  void step(int frames) {
    for (var i = 0; i < frames; i++) {
      s.hero.update(.05);
    }
  }

  test(
    'charge moves the body, hits each victim once, respects its cap and keeps its cooldown',
    () {
      s.progress.selectSkill('charge');
      final targets = [
        for (var i = 0; i < 4; i++)
          s.spawnEnemy('goblin', Offset(6050 + i * 60, 4200))!
            ..life.initial(500),
      ];
      final energy = s.progress.energy;
      s.hero.skill();
      s.hero.skill();
      expect(s.progress.energy, energy - 16);
      expect(s.hero.chargeTime, .36);
      expect(s.boardNearbyMount(), false);
      s.pause();
      step(10);
      expect(s.hero.position.x, 6000);
      s.resume();
      step(10);
      expect(s.hero.position.x, greaterThan(6100));
      expect(s.hero.chargeVictims.length, 3);
      expect(targets.where((m) => m.life.value < 500).length, 3);
      final damage = s.progress.skillDamage(
        s.progress.skills.firstWhere((d) => d.id == 'charge'),
      );
      for (final m in s.hero.chargeVictims) {
        expect(m.life.value, closeTo(500 - damage, .001));
      }
      expect(s.hero.cooldowns['charge'], greaterThan(2.8));
      expect(
        GameCheckpoint.capture(s)!.data['cooldowns']['charge'],
        greaterThan(2.8),
      );
    },
  );
  test(
    'charge stops at solid world boundaries and cannot roll or cast through its motion',
    () {
      s.hero.position.setValues(60, 100);
      s.hero.bearing = math.pi;
      s.progress.selectSkill('charge');
      s.hero.skill();
      s.hero.dodge();
      expect(s.hero.dashing, 0);
      step(10);
      expect(s.hero.position.x, inInclusiveRange(0, 60));
      expect(s.world.blocked(s.hero.body), false);
      expect(s.hero.chargeTime, 0);
    },
  );
  test(
    'heavy strike has a real windup, front cone and target cap; holding raises damage',
    () {
      s.progress.selectSkill('crushingBlow');
      final targets = [
        for (final at in [
          const Offset(6050, 4200),
          const Offset(6090, 4200),
          const Offset(6050, 4240),
          const Offset(6090, 4240),
          const Offset(5920, 4200),
        ])
          s.spawnEnemy('goblin', at)!..life.initial(500),
      ];
      final energy = s.progress.energy;
      s.hero.beginAim(0);
      step(24);
      expect(s.progress.energy, energy);
      s.hero.finishAim(false);
      expect(s.progress.energy, energy - 22);
      expect(targets.every((m) => m.life.value == 500), true);
      step(8);
      expect(targets.every((m) => m.life.value == 500), true);
      s.pause();
      step(20);
      expect(targets.every((m) => m.life.value == 500), true);
      s.resume();
      step(1);
      final damage =
          s.progress.skillDamage(
            s.progress.skills.firstWhere((d) => d.id == 'crushingBlow'),
          ) *
          1.8;
      expect(targets.where((m) => m.life.value < 500).length, 3);
      for (final m in targets.where((m) => m.life.value < 500)) {
        expect(m.life.value, closeTo(500 - damage, .001));
      }
      expect(targets.last.life.value, 500);
      expect(s.hero.strikePose, 2);
      expect(
        s.hero.swing,
        lessThan(s.hero.swingDuration * .58),
        reason: 'the impact displays the released sword, not another windup',
      );
    },
  );
  test(
    'cancelled charge-up spends no resource and causes no delayed strike',
    () {
      s.progress.selectSkill('crushingBlow');
      final energy = s.progress.energy;
      s.hero.beginAim(0);
      step(24);
      s.hero.finishAim(true);
      step(20);
      expect(s.progress.energy, energy);
      expect(s.hero.cooldowns['crushingBlow'], isNull);
      expect(s.hero.heavySkill, null);
    },
  );
  test(
    'reset cancels pending physical motion while retaining spent cooldowns',
    () {
      s.progress.selectSkill('crushingBlow');
      s.hero.skill();
      s.progress.gold = 10000;
      expect(s.resetSkills(), true);
      expect(s.hero.heavyWindup, 0);
      expect(s.hero.heavySkill, null);
      expect(s.hero.cooldowns['crushingBlow'], closeTo(4.2, .000001));
      step(20);
      expect(s.hero.heavySkill, null);
    },
  );
}

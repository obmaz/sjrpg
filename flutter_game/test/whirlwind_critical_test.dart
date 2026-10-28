import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

class _FixedRandom implements math.Random {
  _FixedRandom(this.value);
  final double value;
  int doubleCalls = 0;
  @override
  double nextDouble() {
    doubleCalls++;
    return value;
  }

  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

class _FixedAdventure extends Adventure {
  _FixedAdventure(double value)
    : _fixedRandom = _FixedRandom(value),
      super(GameArt());
  @override
  _FixedRandom get random => _fixedRandom;
  final _FixedRandom _fixedRandom;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    (mastery: 20, roll: .0, critical: true),
    (mastery: 20, roll: .99, critical: false),
    (mastery: 0, roll: .0, critical: false),
  ]) {
    test('whirlwind pulse critical and shared damage agree for $scenario', () {
      final s = inCombatField(_FixedAdventure(scenario.roll))
        ..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.progress.level = 100;
      s.progress.ranks['whirlwind'] = 1;
      if (scenario.mastery > 0) {
        s.progress.ranks['swordMastery'] = scenario.mastery;
      }
      final targets = [
        s.spawnEnemy('goblin', const Offset(6050, 4200))!..life.initial(100000),
        s.spawnEnemy('goblin', const Offset(6090, 4200))!..life.initial(100000),
      ];
      final def = s.progress.skills.firstWhere(
        (skill) => skill.id == 'whirlwind',
      );
      final base = s.progress.skillDamage(def);
      final pulse = WhirlwindPulse(s, s.hero, base);
      s.random.doubleCalls = 0;
      pulse.update(0);
      final expected = base * .8 * (scenario.critical ? 2 : 1);
      for (final target in targets) {
        expect(100000 - target.life.value, closeTo(expected, .001));
      }
      expect(s.texts.where((text) => !text.isReward).length, 2);
      expect(s.texts.every((text) => text.critical == scenario.critical), true);
      expect(
        s.random.doubleCalls,
        scenario.mastery == 0 ? 0 : 1,
        reason: 'one mastery roll for the whole pulse',
      );
      expect(pulse.targets.length, 2);
      expect(pulse.pulses, 1);
    });
    test(
      'berserk converts a mastery-critical weapon strike to magic for $scenario',
      () {
        final s = inCombatField(_FixedAdventure(scenario.roll))
          ..start(TestGame());
        addTearDown(s.dispose);
        s.mobs.clear();
        s.progress.level = 100;
        s.progress.ranks['berserk'] = 1;
        if (scenario.mastery > 0) {
          s.progress.ranks['swordMastery'] = scenario.mastery;
        }
        s.progress.selectSkill('berserk');
        s.progress.energy = s.progress.maxEnergy;
        final target = s.spawnEnemy('goblin', const Offset(6050, 4200))!
          ..life.initial(100000);
        final def = s.progress.skillAt(0)!;
        final damage = s.progress.skillDamage(def);
        s.random.doubleCalls = 0;
        s.hero.skill();
        expect(
          100000 - target.life.value,
          closeTo(damage * (scenario.critical ? 2 : 1), .001),
        );
        expect(s.texts.single.critical, scenario.critical);
        expect(s.progress.armor, 0);
        expect(s.random.doubleCalls, scenario.mastery == 0 ? 0 : 1);
      },
    );
  }
}

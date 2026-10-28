import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/sorceress_combat.dart';
import 'package:guardian_new/world_model.dart';

import 'support/sorceress_fixture.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  setUp(() {
    s = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage))
      ..start(TestGame());
    s.mobs.clear();
    s.progress.level = 100;
    s.progress.skillPoints = 1000;
    for (final id in ['frostNova', 'chainLightning', 'frozenArmor', 'meteor']) {
      trainSkill(s.progress, id);
    }
    s.progress.selectBasic('firebolt');
    for (final entry in [
      'frostNova',
      'chainLightning',
      'frozenArmor',
      'meteor',
    ].asMap().entries) {
      expect(s.progress.selectSkill(entry.value, slot: entry.key), true);
    }
    s.progress.energy = s.progress.maxEnergy;
  });
  tearDown(() => s.dispose());
  void step(int count) {
    for (var i = 0; i < count; i++) {
      s.hero.update(.05);
    }
  }

  void resolvePendingCast() {
    expect(s.hero.queuedCast, isNotNull);
    final maximumSteps = (s.hero.castLock / .05).ceil() + 1;
    for (var i = 0; i < maximumSteps && s.hero.queuedCast != null; i++) {
      step(1);
    }
    expect(s.hero.queuedCast, isNull);
  }

  test(
    'a skill tapped during a basic cast fires once before the next held attack',
    () {
      s.hero.slash();
      final energy = s.progress.energy;
      final cost = s.progress.skillCost(s.progress.activeSkill);
      s.holdAttack('test', true);
      s.hero.skill();
      expect(s.hero.cooldowns['frostNova'], isNull);
      expect(s.progress.energy, energy);
      resolvePendingCast();
      expect(
        s.hero.cooldowns['frostNova'],
        s.progress.skillCooldown(s.progress.activeSkill),
      );
      expect(
        s.hero.strikes,
        1,
        reason: 'the queued spell precedes a second held basic',
      );
      expect(s.progress.energy, energy - cost);
      final lock = s.hero.castLock;
      expect(
        s.hero.cooldowns['frostNova'],
        0,
        reason:
            'D2 Frost Nova is limited by cast animation, not a synthetic cooldown',
      );
      step(3);
      expect(s.hero.castLock, lessThan(lock));
      expect(s.progress.energy, energy - cost);
    },
  );
  test(
    'rapid taps retain only the last valid spell and keep individual cooldowns',
    () {
      s.hero.slash();
      final energy = s.progress.energy;
      final cost = s.progress.skillCost(s.progress.skillAt(1)!);
      s.hero.skill(slot: 0);
      s.hero.skill(slot: 1);
      resolvePendingCast();
      expect(s.hero.cooldowns['frostNova'], isNull);
      expect(
        s.hero.cooldowns['chainLightning'],
        s.progress.skillCooldown(s.progress.skillAt(1)!),
      );
      expect(s.progress.energy, energy - cost);
    },
  );
  for (final action in ['pause', 'roll', 'reset', 'slot']) {
    test('$action cancels a pending cast without spending its resource', () {
      s.progress.energy = 60;
      s.hero.slash();
      final energy = s.progress.energy;
      s.hero.skill();
      switch (action) {
        case 'pause':
          s.pause();
          s.resume();
        case 'roll':
          s.hero.dodge();
        case 'reset':
          s.progress.awardSkillResetTicket(WorldStage.forest);
          expect(s.resetSkills(), true);
        case 'slot':
          s.progress.selectSkill('meteor');
      }
      step(15);
      expect(s.hero.cooldowns['frostNova'], isNull);
      expect(s.hero.cooldowns['meteor'], isNull);
      expect(s.progress.energy, energy);
    });
  }
  test('resource is checked again when the pending cast can execute', () {
    s.hero.slash();
    s.hero.skill();
    s.progress.energy = 0;
    resolvePendingCast();
    expect(s.hero.cooldowns['frostNova'], isNull);
    expect(s.progress.energy, 0);
  });
  test(
    'paid basic projectile flies from its casting origin and freezes with pause',
    () {
      final game = TestGame(),
          mage = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage))
            ..start(game);
      addTearDown(mage.dispose);
      mage.mobs.clear();
      final mana = mage.progress.energy, skill = mage.progress.basicSkill;
      mage.hero.slash();
      final bolt = game.added.whereType<SorceressProjectile>().single;
      expect(bolt.position.toOffset(), mage.hero.body.center);
      expect(mage.progress.energy, mana - mage.progress.skillCost(skill));
      expect(mage.hero.castLock, greaterThan(0));
      final origin = bolt.position.clone();
      mage.pause();
      bolt.update(.5);
      expect(bolt.position, origin);
      expect(bolt.age, 0);
      mage.resume();
      mage.hero.position.x += 20;
      bolt.update(.05);
      expect(
        (bolt.position - origin).length,
        closeTo(bolt.spec.boltSpeed * .05, .001),
      );
      expect(bolt.travelled, greaterThan(0));
      expect(
        mage.hero.castLock,
        greaterThan(0),
        reason: 'the launched missile does not erase the release animation',
      );
    },
  );
  test(
    'rolling cancels buffered input while already launched spells remain physical',
    () {
      final game = TestGame(),
          mage = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage))
            ..start(game);
      addTearDown(mage.dispose);
      mage.mobs.clear();
      mage.hero.slash();
      final bolt = game.added.whereType<SorceressProjectile>().single;
      mage.hero.skill();
      expect(mage.hero.queuedCast, isNotNull);
      final mana = mage.progress.energy;
      mage.hero.dodge();
      expect(mage.hero.queuedCast, isNull);
      bolt.update(.05);
      expect(bolt.travelled, greaterThan(0));
      expect(mage.progress.energy, mana);
    },
  );
}

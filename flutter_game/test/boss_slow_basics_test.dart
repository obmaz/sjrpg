import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/sorceress_combat.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final heroClass in HeroClass.values) {
    test(
      '$heroClass basic tempo loses 28% once; skills keep their own costs and cooldowns',
      () {
        Adventure make() {
          final s = inCombatField(Adventure(GameArt(), heroClass: heroClass))
            ..start(TestGame());
          s.mobs.clear();
          s.waveTime = 10000;
          s.progress.energy = s.progress.maxEnergy;
          addTearDown(s.dispose);
          return s;
        }

        final normal = make(), slowed = make();
        slowed.afflictions.apply(PlayerStatus.attackSlow);
        normal.hero.slash();
        slowed.hero.slash();
        expect(
          slowed.hero.attackClock / normal.hero.attackClock,
          closeTo(1 / .72, .001),
        );
        expect(
          slowed.hero.swingDuration / normal.hero.swingDuration,
          closeTo(1 / .72, .001),
        );
        if (heroClass == HeroClass.mage) {
          expect(
            slowed.hero.castLock / normal.hero.castLock,
            closeTo(1 / .72, .001),
          );
          expect(normal.hero.castLock, closeTo(.52, .000001));
          expect(slowed.hero.castLock, closeTo(.52 / .72, .000001));
          final a = (normal.game! as TestGame).added
              .whereType<SorceressProjectile>()
              .single;
          final b = (slowed.game! as TestGame).added
              .whereType<SorceressProjectile>()
              .single;
          expect(
            b.spec.boltSpeed,
            a.spec.boltSpeed,
            reason:
                'cast slow changes the hand motion, not an already emitted projectile',
          );
        }
        // Cast a real starter/combat skill rather than an empty-target Howl.
        if (heroClass == HeroClass.warrior) {
          for (final session in [normal, slowed]) {
            final bash = session.progress.skills.firstWhere(
              (skill) => skill.id == 'bash',
            );
            expect(session.progress.learn(bash), true);
            expect(session.progress.selectSkill('bash'), true);
          }
        }
        // Clear the already-started basic animation, not its active debuff.
        normal.hero.castLock = slowed.hero.castLock = 0;
        normal.hero.swing = slowed.hero.swing = 0;
        final beforeA = normal.progress.energy,
            beforeB = slowed.progress.energy;
        normal.hero.skill();
        slowed.hero.skill();
        final activeId = heroClass == HeroClass.warrior ? 'bash' : 'firebolt';
        expect(normal.hero.cooldowns, contains(activeId));
        expect(beforeA - normal.progress.energy, greaterThan(0));
        expect(slowed.hero.cooldowns, normal.hero.cooldowns);
        expect(
          beforeB - slowed.progress.energy,
          beforeA - normal.progress.energy,
        );
      },
    );
  }
  test(
    'original rank5 Frenzy preserves attack slow on scheduled basic attacks',
    () {
      Adventure make() {
        final s = inCombatField(Adventure(GameArt()))..start(TestGame());
        s.mobs.clear();
        s.waveTime = 10000;
        while (s.progress.level < 30) {
          s.progress.gainXp(s.progress.nextLevelXp - s.progress.xp);
        }
        final weapon = s.progress.createGear(gearById('twinaxes'));
        s.progress.inventory.add(weapon);
        expect(s.progress.equip(weapon), true);
        void train(String id, int rank) {
          final skill = s.progress.skills.firstWhere((skill) => skill.id == id);
          for (final parent in skill.requires.entries) {
            train(parent.key, parent.value);
          }
          while (s.progress.rank(id) < rank) {
            expect(s.progress.learn(skill), true, reason: id);
          }
        }

        for (final id in ['cleave', 'frenzy']) {
          train(id, 5);
        }
        expect(s.progress.selectSkill('frenzy'), true);
        s.progress.energy = s.progress.maxEnergy;
        final target = s.spawnEnemy(
          'goblin',
          s.hero.body.center + const Offset(55, 0),
        )!..life.initial(10000);
        s.hero.skill();
        expect(s.hero.frenzyTime, s.progress.frenzyDuration);
        expect(s.progress.frenzyStacks, 1);
        while (s.hero.barbarianCombat.busy ||
            s.hero.castLock > 0 ||
            s.hero.attackClock > 0) {
          s.tick(.01);
          s.hero.update(.01);
        }
        expect(s.progress.frenzyStacks, 2);
        expect(target.life.value, lessThan(target.life.max));
        s.mobs.clear();
        addTearDown(s.dispose);
        return s;
      }

      final normal = make(), slowed = make();
      slowed.afflictions.apply(PlayerStatus.attackSlow);
      normal.hero.slash();
      slowed.hero.slash();
      final expected =
          normal.progress.attackInterval / normal.progress.frenzyAttackTempo;
      // The reduced haste and frenzy caps no longer let a legal build reach
      // the strike floor. The debuff must still follow the whole interval.
      expect(expected, greaterThan(CombatBalance.minimumStrikeInterval));
      expect(normal.hero.attackClock, closeTo(expected, .000001));
      expect(
        slowed.hero.attackClock / normal.hero.attackClock,
        closeTo(1 / .72, .001),
      );
      for (final s in [normal, slowed]) {
        final strikes = s.hero.strikes;
        s.hero.slash();
        expect(s.hero.strikes, strikes, reason: 'no cooldown bypass');
      }
      double untilNextAttack(Adventure s) {
        final strikes = s.hero.strikes;
        var elapsed = 0.0;
        s.holdAttack('cadence-test', true);
        while (s.hero.strikes == strikes && elapsed < 2) {
          s.tick(.005);
          s.hero.update(.005);
          elapsed += .005;
        }
        s.holdAttack('cadence-test', false);
        expect(s.hero.strikes, strikes + 1);
        return elapsed;
      }

      expect(untilNextAttack(normal), closeTo(expected, .005001));
      expect(untilNextAttack(slowed), closeTo(expected / .72, .005001));
    },
  );
}

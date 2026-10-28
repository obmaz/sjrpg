import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';

import 'basic_selection_test.dart' show train;
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Preserve historical cadence comparisons for the supported canonical basic
  // and all three mage basics. Original Barbarian actions are paid skills below.
  final originalCases =
      jsonDecode(
            File('test/fixtures/basic_pacing_mobile61.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final baseline =
      jsonDecode(
            File(
              'test/fixtures/skill_balance_mobile69.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final row in originalCases['rows'] as List) {
    final heroClass = HeroClass.values.byName(row['hero'] as String);
    final mode = row['mode'] as String, rank = row['rank'] as int;
    if (heroClass == HeroClass.warrior && mode != 'cleave') continue;
    test('$mode rank $rank uses slower actual cadence and weaker hits', () {
      final s = inCombatField(Adventure(GameArt(), heroClass: heroClass))
        ..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.waveTime = 10000;
      final p = s.progress;
      p.level = 30; // The independent mobile69 fixture uses this same level.
      s.syncLife();
      p.ranks[mode] = rank;
      expect(p.selectBasic(mode), true);
      final old = baseline[heroClass.name]['$rank'][mode] as Map;
      final oldTempo = (old['tempo'] as num).toDouble();
      final oldInterval = p.weapon.base.tempo / oldTempo;
      final interval = p.attackInterval, tempo = p.basicTempo;
      expect(interval / oldInterval, inInclusiveRange(1.35, 1.56));
      expect(tempo / oldTempo, inInclusiveRange(.64, .75));
      expect(
        interval,
        greaterThanOrEqualTo(CombatBalance.minimumBasicInterval),
      );
      expect(
        p.basicDamage / (old['damage'] as num),
        inInclusiveRange(.50, .600001),
      );
      final oldActive = originalCases['actives'][heroClass.name];
      for (final def in p.skills.where(
        (s) =>
            heroClass == HeroClass.mage &&
            !s.basic &&
            !s.passive &&
            !s.mobility &&
            (oldActive['costs'] as Map).containsKey(s.id),
      )) {
        expect(
          p.skillCooldown(def, atRank: 1),
          closeTo(
            baseline[heroClass.name]['1'][def.id]['cooldown'] * 9 / 7,
            .000001,
          ),
        );
        expect(def.cost, oldActive['costs'][def.id]);
      }
      final energy = p.energy, slots = p.skillSlots.toList();
      s.hero.slash();
      expect(s.hero.attackClock, closeTo(interval, .000001));
      expect(
        s.hero.attackClock,
        greaterThanOrEqualTo(CombatBalance.minimumStrikeInterval),
      );
      expect(p.energy, energy);
      expect(p.skillSlots, slots);
      final motionBase = heroClass == HeroClass.mage || mode == 'heavyStrike'
          ? .32
          : .26;
      expect(s.hero.swingDuration, closeTo(motionBase / tempo, .000001));
      // The real gate cannot be bypassed by calling slash a second time.
      s.hero.slash();
      expect(s.hero.strikes, 1);
      if (heroClass == HeroClass.mage) {
        expect(s.hero.castLock, closeTo(.26 / tempo, .000001));
        final bolt = (s.game! as TestGame).added.whereType<ArcaneBolt>().single;
        final releaseDelay = .13 / tempo;
        expect(bolt.launchDelay, closeTo(releaseDelay, .000001));
        expect(bolt.damage, p.basicDamage);
        // Hand release follows the new cadence; projectile travel still
        // starts only after its complete, positive simulation delay.
        void stepBolt(double seconds) {
          while (seconds > 0) {
            final dt = seconds > .02 ? .02 : seconds;
            bolt.update(dt);
            seconds -= dt;
          }
        }

        stepBolt(releaseDelay * .75);
        expect(bolt.launchDelay, greaterThan(0));
        expect(bolt.remaining, p.weapon.base.range / ArcaneBolt.speed);
        stepBolt(releaseDelay * .35);
        expect(bolt.launchDelay, 0);
        expect(
          bolt.remaining,
          lessThan(p.weapon.base.range / ArcaneBolt.speed),
        );
      }
      void stepHero(double seconds) {
        while (seconds > 0) {
          final dt = seconds > .02 ? .02 : seconds;
          s.hero.update(dt);
          seconds -= dt;
        }
      }

      stepHero(oldInterval);
      s.hero.slash();
      expect(
        s.hero.strikes,
        1,
        reason: 'the previous interval is now too early',
      );
      stepHero(interval - oldInterval + .001);
      s.hero.slash();
      expect(s.hero.strikes, 2, reason: 'the actual new gate reopens normally');
    });
  }
  for (final id in ['bash', 'stun']) {
    for (final rank in [1, 5]) {
      test(
        '$id rank$rank has a paid active cadence independent of the canonical basic',
        () {
          final session = inCombatField(Adventure(GameArt()))
            ..start(TestGame());
          addTearDown(session.dispose);
          session.mobs.clear();
          final p = session.progress
            ..level = 100
            ..skillPoints = 1000;
          train(p, id, rank);
          expect(p.selectSkill(id), true);
          p.energy = p.maxEnergy;
          final skill = p.skills.firstWhere((skill) => skill.id == id);
          final target = session.spawnEnemy(
            'goblin',
            session.hero.body.center + const Offset(50, 0),
          )!..life.initial(10000);
          final energy = p.energy, points = p.skillPoints;
          final damage = p.skillDamage(skill), cost = p.skillCost(skill);
          session.hero.skill();
          expect(target.life.value, closeTo(10000 - damage, .00001));
          expect(session.hero.cooldowns[id], p.skillCooldown(skill));
          expect(p.energy, closeTo(energy - cost, .00001));
          expect(p.skillPoints, points);
          expect(p.selectedBasic, 'cleave');
          final hp = target.life.value, cooldown = session.hero.cooldowns[id];
          session.hero.skill();
          expect(target.life.value, hp);
          expect(p.energy, closeTo(energy - cost, .00001));
          expect(session.hero.cooldowns[id], cooldown);
        },
      );
    }
  }
}

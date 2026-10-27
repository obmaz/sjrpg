import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Captured from actual Progress at the preceding production source, not
  // calculated using the new rate constant being tested.
  final baseline =
      jsonDecode(
            File('test/fixtures/basic_pacing_mobile61.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final row in baseline['rows'] as List) {
    final heroClass = HeroClass.values.byName(row['hero'] as String);
    final mode = row['mode'] as String, rank = row['rank'] as int;
    test(
      '$mode rank $rank doubles real cadence without changing hit or skills',
      () {
        final s = inCombatField(Adventure(GameArt(), heroClass: heroClass))
          ..start(TestGame());
        addTearDown(s.dispose);
        s.mobs.clear();
        s.waveTime = 10000;
        final p = s.progress;
        p.ranks[mode] = rank;
        expect(p.selectBasic(mode), true);
        final oldInterval = (row['interval'] as num).toDouble();
        final oldTempo = (row['tempo'] as num).toDouble();
        expect(p.attackInterval, closeTo(oldInterval * 2, .000001));
        expect(p.basicTempo, closeTo(oldTempo / 2, .000001));
        expect(
          p.basicDamage,
          closeTo((row['damage'] as num).toDouble(), .000001),
        );
        final oldActive = baseline['actives'][heroClass.name];
        for (final def in p.skills.where((s) => !s.basic && !s.passive)) {
          expect(
            p.skillCooldown(def, atRank: 1),
            oldActive['cooldowns'][def.id],
          );
          expect(def.cost, oldActive['costs'][def.id]);
        }
        final energy = p.energy, slots = p.skillSlots.toList();
        s.hero.slash();
        expect(s.hero.attackClock, closeTo(oldInterval * 2, .000001));
        expect(p.energy, energy);
        expect(p.skillSlots, slots);
        final motionBase = heroClass == HeroClass.mage || mode == 'heavyStrike'
            ? .32
            : .26;
        expect(
          s.hero.swingDuration,
          closeTo(motionBase / oldTempo * 2, .000001),
        );
        // The real gate cannot be bypassed by calling slash a second time.
        s.hero.slash();
        expect(s.hero.strikes, 1);
        if (heroClass == HeroClass.mage) {
          expect(s.hero.castLock, closeTo(.26 / oldTempo * 2, .000001));
          final bolt = (s.game! as TestGame).added
              .whereType<ArcaneBolt>()
              .single;
          expect(bolt.launchDelay, closeTo(.13 / oldTempo * 2, .000001));
          // Doubling the interval also doubles the actual hand-release delay,
          // while the projectile's travel clock starts only after release.
          void stepBolt(double seconds) {
            while (seconds > 0) {
              final dt = seconds > .02 ? .02 : seconds;
              bolt.update(dt);
              seconds -= dt;
            }
          }

          stepBolt(.13 / oldTempo * 1.5);
          expect(bolt.launchDelay, greaterThan(0));
          expect(bolt.remaining, .88);
          stepBolt(.13 / oldTempo * .6);
          expect(bolt.launchDelay, 0);
          expect(bolt.remaining, lessThan(.88));
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
        stepHero(oldInterval + .001);
        s.hero.slash();
        expect(s.hero.strikes, 2, reason: 'the doubled gate reopens normally');
      },
    );
  }
}

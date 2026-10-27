import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/rpg_model.dart';

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
          final a = (normal.game! as TestGame).added
              .whereType<ArcaneBolt>()
              .single;
          final b = (slowed.game! as TestGame).added
              .whereType<ArcaneBolt>()
              .single;
          expect(b.launchDelay / a.launchDelay, closeTo(1 / .72, .001));
        }
        // Clear the already-started basic animation, not its active debuff.
        normal.hero.castLock = slowed.hero.castLock = 0;
        normal.hero.swing = slowed.hero.swing = 0;
        final beforeA = normal.progress.energy,
            beforeB = slowed.progress.energy;
        normal.hero.skill();
        slowed.hero.skill();
        expect(slowed.hero.cooldowns, normal.hero.cooldowns);
        expect(
          beforeB - slowed.progress.energy,
          beforeA - normal.progress.energy,
        );
      },
    );
  }
  test(
    'attack slow still applies after the minimum interval on a fast frenzied build',
    () {
      Adventure make() {
        final s = inCombatField(Adventure(GameArt()))..start(TestGame());
        s.mobs.clear();
        s.waveTime = 10000;
        final weapon = s.progress.createGear(gearById('twinaxes'));
        s.progress.inventory.add(weapon);
        expect(s.progress.equip(weapon), true);
        s.progress.ranks.addAll({
          'cleave': 5,
          'battleFocus': 5,
          'weaponTempo': 5,
          'frenzy': 5,
        });
        s.hero.frenzyTime = 8;
        addTearDown(s.dispose);
        return s;
      }

      final normal = make(), slowed = make();
      slowed.afflictions.apply(PlayerStatus.attackSlow);
      normal.hero.slash();
      slowed.hero.slash();
      expect(normal.hero.attackClock, lessThan(.18));
      expect(
        slowed.hero.attackClock / normal.hero.attackClock,
        closeTo(1 / .72, .001),
      );
    },
  );
}

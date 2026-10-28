import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/weapon_profiles.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field(String weapon) {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    s.mobs.clear();
    final gear = s.progress.createGear(gearById(weapon));
    s.progress.inventory.add(gear);
    s.progress.equip(gear);
    addTearDown(s.dispose);
    return s;
  }

  void advance(Adventure s, double seconds) {
    while (seconds > .000001) {
      final dt = math.min(.01, seconds);
      s.hero.update(dt);
      seconds -= dt;
    }
  }

  test(
    'fresh heroes receive two points; old saves never receive them again',
    () {
      for (final hero in HeroClass.values) {
        final p = Progress(heroClass: hero);
        expect(p.skillPoints, 2);
        expect(Progress.fromSave(p.toSave())!.skillPoints, 2);
        final old = p.toSave()..['skillPoints'] = 0;
        final restored = Progress.fromSave(old)!;
        expect(restored.skillPoints, 0);
        expect(Progress.fromSave(restored.toSave())!.skillPoints, 0);
      }
    },
  );
  test(
    'successful timing keeps attacking with no held button then expires',
    () {
      final s = field('shortsword'), h = s.hero;
      h.slash();
      final v = h.comboHud.value, p = s.progress.weapon.base.comboProfile!;
      advance(s, p.barDuration * (v.windowStart + v.windowEnd) / 2);
      h.slash();
      while (h.comboHud.value.count < 2) {
        h.update(.01);
      }
      expect(h.comboFlow, true);
      expect(s.attackSources, isEmpty);
      final strikes = h.strikes, count = h.comboHud.value.count;
      advance(s, s.progress.attackInterval * .46);
      expect(h.strikes, greaterThan(strikes));
      expect(
        h.comboHud.value.count,
        count,
        reason: 'automatic follow-ups never earn a timing link',
      );
      advance(s, 1);
      expect(h.comboFlow, false);
      final after = h.strikes;
      advance(s, 1);
      expect(h.strikes, after);
    },
  );
  test(
    'every melee weapon deals more damage with correct rhythms than holding',
    () {
      for (final trained in [false, true]) {
        for (final def in gearCatalog.where((g) => g.comboProfile != null)) {
          final amounts = <double>[];
          for (final rhythm in [false, true]) {
            final s = field(def.id), h = s.hero;
            if (trained) {
              s.progress.level = 30;
              s.progress.ranks.addAll({
                'cleave': 5,
                'battleFocus': 5,
                'weaponTempo': 5,
                'frenzy': 5,
              });
              h.frenzyTime = 60;
            }
            final mob = s.spawnEnemy(
              'goblin',
              h.body.center + const Offset(50, 0),
            )!..life.initial(1000000);
            if (rhythm) {
              h.slash();
            } else {
              s.holdAttack('comparison', true);
            }
            for (var i = 0; i < 1000; i++) {
              mob.position.setValues(
                h.body.center.dx + 50,
                h.body.center.dy - 12,
              );
              if (rhythm) {
                final v = h.comboHud.value;
                if (!v.queued &&
                    h.timedCombo.active &&
                    v.progress >= (v.windowStart + v.windowEnd) / 2 &&
                    v.progress <= v.windowEnd) {
                  h.slash();
                } else if (!h.timedCombo.active &&
                    !v.queued &&
                    h.attackClock <= 0) {
                  h.slash();
                }
              }
              h.update(.01);
            }
            amounts.add(1000000 - mob.life.value);
          }
          final ratio = amounts[1] / amounts[0];
          expect(
            ratio,
            greaterThan(1.2),
            reason:
                '${def.id} trained=$trained: timed ${amounts[1]} vs held ${amounts[0]}',
          );
        }
      }
    },
  );
  test('interruptions stop automatic follow-ups immediately', () {
    for (final interrupt in ['pause', 'dodge', 'weapon', 'shelter']) {
      final s = field('dualblades'), h = s.hero;
      h.slash();
      final v = h.comboHud.value, p = s.progress.weapon.base.comboProfile!;
      advance(s, p.barDuration * (v.windowStart + v.windowEnd) / 2);
      h.slash();
      while (h.comboHud.value.count < 2) {
        h.update(.01);
      }
      final strikes = h.strikes;
      switch (interrupt) {
        case 'pause':
          s.pause();
          s.resume();
        case 'dodge':
          h.dodge();
        case 'weapon':
          final g = s.progress.createGear(gearById('spear'));
          s.progress.inventory.add(g);
          s.equip(g);
        case 'shelter':
          h.position.setValues(s.world.spawn.dx, s.world.spawn.dy);
      }
      advance(s, 2);
      expect(h.strikes, strikes, reason: interrupt);
    }
  });
  test(
    'every non-final successful link produces hands-free attacks before the next bar expires',
    () {
      for (final def in gearCatalog.where(
        (g) =>
            g.comboProfile != null && (g.comboProfile!.chainLength ?? 3) >= 3,
      )) {
        final s = field(def.id), h = s.hero;
        h.slash();
        final v = h.comboHud.value, p = def.comboProfile!;
        advance(s, p.barDuration * (v.windowStart + v.windowEnd) / 2);
        h.slash();
        while (h.comboHud.value.count < 2) {
          h.update(.01);
        }
        final strikes = h.strikes;
        advance(s, p.barDuration * .65);
        expect(h.strikes, greaterThan(strikes), reason: def.id);
        expect(h.comboHud.value.count, 2, reason: def.id);
        expect(s.attackSources, isEmpty);
      }
    },
  );
  test(
    'all timing bars are faster, with dual blades keeping the shortest cycle',
    () {
      for (final p in meleeWeaponProfiles.values) {
        expect(p.barDuration, lessThan(.8));
      }
      expect(meleeWeaponProfiles['dualblades']!.barDuration, .32);
    },
  );
}

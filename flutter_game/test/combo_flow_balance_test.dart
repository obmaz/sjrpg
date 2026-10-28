import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field(String weapon) {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    s.mobs.clear();
    s.waveTime = 10000;
    final gear = s.progress.createGear(gearById(weapon));
    s.progress.inventory.add(gear);
    expect(s.progress.equip(gear), true);
    addTearDown(s.dispose);
    return s;
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

  test('tapping once cannot start hands-free follow-up attacks', () {
    final s = field('shortsword'), h = s.hero;
    h.slash();
    expect(h.strikes, 1);
    for (var frame = 0; frame < 1000; frame++) {
      h.update(.01);
    }
    expect(h.strikes, 1);
    expect(s.attackSources, isEmpty);
    expect(h.comboFlow, false);
    expect(h.comboHud.value.visible, false);
  });

  test(
    'holding and tapping repeatedly have the same ordinary attack cadence',
    () {
      for (final trained in [false, true]) {
        for (final def in gearCatalog.where((g) => g.comboProfile != null)) {
          final strikes = <int>[], amounts = <double>[];
          for (final held in [false, true]) {
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
            if (held) s.holdAttack('comparison', true);
            for (var frame = 0; frame < 1000; frame++) {
              mob.position.setValues(
                h.body.center.dx + 50,
                h.body.center.dy - 12,
              );
              h.update(.01);
              if (!held) h.slash();
              expect(h.comboHud.value.visible, false, reason: def.id);
              expect(h.comboFlow, false, reason: def.id);
            }
            strikes.add(h.strikes);
            amounts.add(1000000 - mob.life.value);
          }
          expect(strikes[0], strikes[1], reason: '${def.id} trained=$trained');
          expect(
            amounts[0],
            closeTo(amounts[1], .001),
            reason: '${def.id} trained=$trained',
          );
        }
      }
    },
  );

  test('releasing the final held source stops attacking immediately', () {
    final s = field('dualblades'), h = s.hero;
    s.holdAttack('touch', true);
    s.holdAttack('keyboard', true);
    h.update(.01);
    final first = h.strikes;
    s.holdAttack('touch', false);
    for (var frame = 0; frame < 200; frame++) {
      h.update(.01);
    }
    expect(h.strikes, greaterThan(first));
    s.holdAttack('keyboard', false);
    final released = h.strikes;
    for (var frame = 0; frame < 300; frame++) {
      h.update(.01);
    }
    expect(h.strikes, released);
    expect(h.comboFlow, false);
    expect(h.comboHud.value.visible, false);
  });

  test('pause clears held input and cannot resume an automatic attack', () {
    final s = field('shortsword'), h = s.hero;
    s.holdAttack('touch', true);
    h.update(.01);
    final first = h.strikes;
    s.pause();
    s.resume();
    for (var frame = 0; frame < 400; frame++) {
      h.update(.01);
    }
    expect(h.strikes, first);
    expect(s.attackSources, isEmpty);
    expect(h.comboHud.value.visible, false);
  });
}

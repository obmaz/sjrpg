import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/rpg_model.dart';
import 'support/sorceress_fixture.dart';

void main() {
  for (final hero in HeroClass.values) {
    test(
      '$hero equipment projections preserve inventory and match real equip',
      () {
        final p = Progress(heroClass: hero)
          ..level = 100
          ..skillPoints = 1000;
        for (final entry
            in (hero == HeroClass.warrior
                    ? {'swordMastery': 2, 'ironSkin': 3, 'cleave': 3}
                    : {'fireMastery': 2, 'coldMastery': 4, 'firebolt': 3})
                .entries) {
          trainSkill(p, entry.key, entry.value);
        }
        final charm = p.createGear(gearById('fang'));
        p.inventory.add(charm);
        expect(p.equip(charm), true);
        final candidate = p.createGear(
          gearById(hero == HeroClass.warrior ? 'twinaxes' : 'frostwand'),
          rarity: Rarity.magic,
          power: 4,
        )..locked = true;
        final before = jsonEncode(p.toSave());
        final prediction = p.previewBasicAttack(candidate)!;
        expect(jsonEncode(p.toSave()), before);
        p.inventory.add(candidate);
        expect(p.equip(candidate), true);
        expect(p.basicDamage, prediction.damage);
        expect(
          CombatBalance.realSeconds(p.actualBasicInterval()),
          prediction.interval,
        );
        expect(p.basicDps, prediction.dps);
        expect(candidate.locked, true);
      },
    );
  }
  test(
    'spell projections preserve elemental identity while weapon attacks retain gear ordering and class locks',
    () {
      final p = trainedSorceress();
      final ice = p.createGear(gearById('frostwand'));
      final lightning = p.createGear(gearById('stormrod'));
      expect(
        p.previewBasicAttack(ice)!.dps,
        p.previewBasicAttack(lightning)!.dps,
        reason:
            'spell base damage comes from its skill rather than weapon attack',
      );
      trainSkill(p, 'iceBolt');
      trainSkill(p, 'coldMastery', 5);
      p.selectBasic('iceBolt');
      expect(p.basicElement, 'ice');
      expect(p.sorceressColdPierce, greaterThan(0));
      expect(
        p.previewBasicAttack(ice)!.dps,
        p.previewBasicAttack(lightning)!.dps,
        reason:
            'Cold Mastery affects enemy resistance, not a weapon-style raw DPS multiplier',
      );
      expect(p.selectBasic('sorceressAttack'), false);
      expect(p.selectedBasic, 'iceBolt');
      expect(p.previewBasicAttack(p.createGear(gearById('longsword'))), null);
    },
  );
}

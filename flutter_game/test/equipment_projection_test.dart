import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/rpg_model.dart';

void main() {
  for (final hero in HeroClass.values) {
    test(
      '$hero equipment projections preserve inventory and match real equip',
      () {
        final p = Progress(heroClass: hero)..gainXp(1000);
        p.ranks.addAll(
          hero == HeroClass.warrior
              ? {'mastery': 2, 'battleFocus': 3, 'cleave': 3}
              : {'arcaneMastery': 2, 'coldMastery': 4, 'firebolt': 3},
        );
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
    'elemental specialization changes weapon ordering and class locks apply',
    () {
      final p = Progress(heroClass: HeroClass.mage)..gainXp(1000);
      final ice = p.createGear(gearById('frostwand'));
      final lightning = p.createGear(gearById('stormrod'));
      expect(
        p.previewBasicAttack(ice)!.dps,
        lessThan(p.previewBasicAttack(lightning)!.dps),
      );
      p.ranks['coldMastery'] = 5;
      expect(
        p.previewBasicAttack(ice)!.dps,
        greaterThan(p.previewBasicAttack(lightning)!.dps),
      );
      expect(p.previewBasicAttack(p.createGear(gearById('longsword'))), null);
    },
  );
}

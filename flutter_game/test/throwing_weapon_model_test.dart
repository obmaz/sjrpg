import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/weapon_profiles.dart';

void main() {
  Progress equipped(String id) {
    final p = Progress()
      ..level = 100
      ..skillPoints = 1000;
    final gear = p.createGear(gearById(id));
    p.inventory.add(gear);
    expect(p.equip(gear), true);
    return p;
  }

  test('all six Barbarian masteries have a real matching equipped weapon', () {
    final weapons = gearCatalog.where(
      (g) => g.slot == GearSlot.weapon && g.heroClass == HeroClass.warrior,
    );
    expect(weapons.length, 18);
    final matching = <String>{};
    for (final def in weapons) {
      final p = equipped(def.id);
      final id = p.weaponMasteryId;
      matching.add(id);
      final before = p.basicDamage;
      expect(p.learn(p.skills.firstWhere((s) => s.id == id)), true);
      expect(p.basicDamage, closeTo(before * 1.02, 1e-9), reason: def.id);
      expect(p.weaponCriticalChance, closeTo(.034, 1e-9), reason: def.id);
    }
    expect(matching, {
      'swordMastery',
      'axeMastery',
      'maceMastery',
      'polearmMastery',
      'throwingMastery',
      'spearMastery',
    });
  });

  test(
    'throwing mastery scales real basic damage and critical DPS exactly once',
    () {
      for (final id in throwingWeaponProfiles.keys) {
        final p = equipped(id), before = equipped(id);
        p.ranks['throwingMastery'] = 20;
        p.ranks['swordMastery'] = 20;
        p.ranks['axeMastery'] = 20;
        p.ranks['spearMastery'] = 20;
        p.ranks['cleave'] = 5;
        before.ranks['cleave'] = 5;
        expect(p.weaponMasteryId, 'throwingMastery');
        expect(p.basicDamage, closeTo(before.basicDamage * 1.4, 1e-9));
        expect(p.basicTargetLimit, 1);
        expect(p.weaponCriticalChance, closeTo(.11, 1e-9));
        expect(p.skillRange(p.basicSkill), p.weapon.base.range);
        expect(p.skillRange(p.skills.firstWhere((s) => s.id == 'bash')), 115);
        expect(
          p.skillRange(p.skills.firstWhere((s) => s.id == 'doubleThrow')),
          420,
        );
        final stats = p.basicAttackStats();
        expect(stats.damage, p.basicDamage);
        expect(stats.dps, closeTo(stats.damage * 1.11 / stats.interval, 1e-9));
        final restored = Progress.fromSave(p.toSave())!;
        expect(restored.weapon.base.id, id);
        expect(restored.basicDamage, p.basicDamage);
        expect(restored.basicDps, p.basicDps);
        expect(restored.weapon.base.comboProfile, isNull);
      }
    },
  );

  test(
    'equipping preview switches mastery families without altering live gear',
    () {
      final p = equipped('shortsword')
        ..ranks['swordMastery'] = 20
        ..ranks['throwingMastery'] = 6;
      final candidate = p.createGear(gearById('javelin'));
      p.inventory.add(candidate);
      final saved = jsonEncode(p.toSave());
      final preview = p.previewBasicAttack(candidate)!;
      expect(jsonEncode(p.toSave()), saved);
      expect(p.equip(candidate), true);
      expect(preview.damage, p.basicDamage);
      expect(preview.criticalChance, p.weaponCriticalChance);
      expect(preview.dps, p.basicDps);
    },
  );

  test(
    'throwing weapons have bounded physical profiles and reachable acquisition',
    () {
      final p = Progress(), mage = Progress(heroClass: HeroClass.mage);
      final axes = gearById('throwingaxes'), javelin = gearById('javelin');
      expect(p.shopGear, contains(axes));
      expect(p.shopGear, isNot(contains(javelin)));
      p.level = 3;
      expect(p.shopGear, containsAll([axes, javelin]));
      expect(mage.shopGear, isNot(contains(axes)));
      expect(mage.shopGear, isNot(contains(javelin)));
      final drops = <String>{};
      final random = math.Random(405);
      for (var i = 0; i < 1500; i++) {
        drops.add(p.rollLoot(random, elite: true).base.id);
      }
      for (final def in [axes, javelin]) {
        expect(drops, contains(def.id));
        expect(def.style, 'throwing');
        expect(def.isThrowingWeapon, true);
        expect(def.range, inInclusiveRange(350, 500));
        expect(def.tempo, inInclusiveRange(.35, .5));
        expect(def.throwingProfile!.speed, inInclusiveRange(450, 700));
        expect(def.throwingProfile!.impactRadius, inInclusiveRange(5, 10));
        expect(WeaponGift.comboFury.supports(def), false);
        expect(WeaponGift.comboGuard.supports(def), false);
      }
    },
  );
}

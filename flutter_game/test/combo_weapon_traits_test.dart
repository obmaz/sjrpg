import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';

void main() {
  test(
    'combo affixes roll only on timed melee and survive equipment saves',
    () {
      final seen = <WeaponGift>{};
      for (final hero in HeroClass.values) {
        final p = Progress(heroClass: hero);
        for (var seed = 0; seed < 100; seed++) {
          for (final unique in [false, true]) {
            final item = p.rollLoot(
              Random(seed),
              elite: !unique,
              unique: unique,
            );
            expect(item.gifts.toSet().length, item.gifts.length);
            expect(item.gifts.length, unique ? 2 : 1);
            for (final gift in item.gifts.where((gift) => gift.isCombo)) {
              seen.add(gift);
              expect(hero, HeroClass.warrior);
              expect(item.base.comboProfile, isNotNull);
              expect(WeaponGift.comboFury.supports(item.base), true);
              expect(item.stats, contains(gift.description));
            }
            expect(Gear.fromSave(item.toSave()).toSave(), item.toSave());
          }
        }
      }
      expect(seen, {WeaponGift.comboFury, WeaponGift.comboGuard});
    },
  );

  test('armor charms and mage weapons retain only the original affix pool', () {
    for (final base in gearCatalog.where(
      (base) => !WeaponGift.comboFury.supports(base),
    )) {
      for (var serial = 1; serial <= 12; serial++) {
        final gear = Gear(serial, base, rarity: Rarity.unique);
        expect(gear.gifts.any((gift) => gift.isCombo), false, reason: base.id);
        expect(Gear.fromSave(gear.toSave()).toSave(), gear.toSave());
      }
    }
  });

  test(
    'both combo traits persist together and retain the weapon on upgrade',
    () {
      final item = Gear(
        333,
        gearById('dualblades'),
        rarity: Rarity.unique,
        gifts: [WeaponGift.comboFury, WeaponGift.comboGuard],
      );
      final saved = Gear.fromSave(item.toSave());
      expect(saved.gifts, item.gifts);
      expect(saved.withWeaponLevel(9).gifts, item.gifts);
      expect(saved.base.comboProfile!.endless, true);
      expect(saved.stats, contains('무한 콤보'));
      expect(gearById('longsword').comboProfile!.chainLabel, '4연격');
    },
  );

  test('inert combo affixes cannot enter constructors or forged saves', () {
    for (final id in [
      'leather',
      'amber',
      'wand',
      'axe',
      'greatsword',
      'warhammer',
    ]) {
      final base = gearById(id);
      expect(
        () => Gear(2, base, rarity: Rarity.rare, gifts: [WeaponGift.comboFury]),
        throwsArgumentError,
        reason: id,
      );
      final raw = Gear(2, base, rarity: Rarity.rare).toSave()
        ..['gifts'] = ['comboGuard']
        ..['gift'] = base.slot == GearSlot.weapon ? 'comboGuard' : null;
      expect(() => Gear.fromSave(raw), throwsFormatException, reason: id);
    }
  });

  test('legacy ability defaults keep their original serial mapping', () {
    const original = [
      WeaponGift.frost,
      WeaponGift.guardian,
      WeaponGift.renewal,
    ];
    for (var serial = 1; serial <= 15; serial++) {
      final gear = Gear(
        serial,
        gearById('shortsword'),
        rarity: Rarity.rare,
        affixVersion: 0,
      );
      final raw = gear.toSave()
        ..remove('affixVersion')
        ..remove('gifts')
        ..remove('gift');
      expect(Gear.fromSave(raw).gift, original[serial % 3]);
    }
    final forbidden = Gear(
      9,
      gearById('shortsword'),
      rarity: Rarity.rare,
      gifts: [WeaponGift.comboFury],
    ).toSave()..['affixVersion'] = 0;
    expect(() => Gear.fromSave(forbidden), throwsFormatException);
  });
}

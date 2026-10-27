import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

class _FailedRoll implements math.Random {
  @override
  double nextDouble() => .9999;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure withoutWeapon(HeroClass heroClass) {
    final s = Adventure(GameArt(), heroClass: heroClass)..start(TestGame());
    addTearDown(s.dispose);
    inCombatField(s);
    s.progress.gold = 1000;
    s.progress.enhanceWeapon(
      s.progress.smithQuote(s.progress.weapon)!,
      _FailedRoll(),
    );
    s.progress.hp = 47.5;
    s.progress.energy = 12;
    s.syncLife();
    expect(s.progress.usingFallbackWeapon, isTrue);
    return s;
  }

  for (final heroClass in HeroClass.values) {
    for (final fromShop in [false, true]) {
      test(
        '$heroClass autoequipped ${fromShop ? 'purchase' : 'loot'} reconciles real Bonfire life without healing',
        () {
          final s = withoutWeapon(heroClass);
          final p = s.progress;
          final hp = p.hp, energy = p.energy;
          final maxBefore = p.maxHp;
          final def = gearById(
            heroClass == HeroClass.warrior ? 'longsword' : 'oakstaff',
          );
          late final Gear gear;
          if (fromShop) {
            gear = s.buyGear(def)!;
          } else {
            gear = p.createGear(
              def,
              rarity: Rarity.rare,
              vitality: 12,
              focus: 7,
            );
            final loot = GroundLoot(s, gear, s.hero.body.center);
            s.loot.add(loot);
            loot.tryCollect();
            expect(loot.collected, isTrue);
          }
          expect(p.weapon, same(gear));
          expect(p.usingFallbackWeapon, isFalse);
          if (!fromShop || heroClass == HeroClass.mage) {
            expect(p.maxHp, greaterThan(maxBefore));
          }
          expect(s.hero.life.max, p.maxHp);
          expect(s.hero.life.value, hp);
          expect(p.hp, hp);
          expect(p.energy, energy);
          expect(p.weapon.gifts, gear.gifts);
          final damage = p.mitigate(1);
          s.hero.invulnerable = 0;
          s.hurtHero(1);
          expect(p.hp, closeTo(hp - damage, .000001));
          expect(s.hero.life.value, closeTo(p.hp, .000001));
          final checkpoint = GameCheckpoint.capture(s)!;
          final restored = checkpoint.restore(GameArt())..start(TestGame());
          addTearDown(restored.dispose);
          expect(restored.progress.weapon.serial, gear.serial);
          expect(restored.progress.weapon.gifts, gear.gifts);
          expect(restored.hero.life.max, p.maxHp);
          expect(restored.hero.life.value, p.hp);
        },
      );
    }
    test(
      '$heroClass death rejects autoequipment and cannot revive from a pickup or purchase',
      () {
        final s = withoutWeapon(heroClass);
        final p = s.progress;
        final gear = p.createGear(
          gearById(heroClass == HeroClass.warrior ? 'longsword' : 'oakstaff'),
          rarity: Rarity.rare,
          vitality: 12,
        );
        final loot = GroundLoot(s, gear, s.hero.body.center);
        s.loot.add(loot);
        s.hurtHero(10000);
        expect(s.defeated, isTrue);
        final gold = p.gold;
        final serial = p.toSave()['serial'];
        loot.tryCollect();
        expect(loot.collected, isFalse);
        expect(p.inventory.contains(gear), isFalse);
        expect(s.buyGear(gear.base), isNull);
        expect(p.gold, gold);
        expect(p.toSave()['serial'], serial);
        expect(p.usingFallbackWeapon, isTrue);
        expect(p.hp, 0);
        expect(s.hero.life.value, 0);
        expect(s.defeated, isTrue);
      },
    );
  }
}

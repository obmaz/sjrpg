import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/shop_content.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

class _Roll implements math.Random {
  _Roll(this.value);
  final double value;
  int calls = 0;
  @override
  double nextDouble() {
    calls++;
    return value;
  }

  @override
  int nextInt(int max) =>
      throw StateError('Enhancement uses one probability roll');
  @override
  bool nextBool() => throw StateError('Enhancement uses one probability roll');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('success probability uses current weapon level relative to hero', () {
    for (final (weapon, hero, expected) in [
      (1, 8, .9),
      (9, 10, .9),
      (10, 10, .7),
      (11, 10, .6),
      (12, 10, .5),
      (13, 10, .4),
      (14, 10, .3),
      (30, 10, .3),
      (1000000, 10, .3),
    ]) {
      expect(SmithQuote.chance(weapon, hero), expected);
    }
  });

  test('success boundary is strict and one quoted price pays once', () {
    for (final (roll, expectedSuccess) in [(.699999, true), (.7, false)]) {
      final p = Progress();
      final quote = p.smithQuote(p.weapon)!;
      p.gold = quote.price;
      final random = _Roll(roll);
      final result = p.enhanceWeapon(quote, random)!;
      expect(quote.weaponLevel, 1);
      expect(quote.heroLevel, 1);
      expect(quote.successChance, .7);
      expect(result.succeeded, expectedSuccess);
      expect(result.destroyed, !expectedSuccess);
      expect(p.gold, 0);
      expect(random.calls, 1);
      expect(p.enhanceWeapon(quote, random), isNull);
      expect(random.calls, 1);
    }
  });

  test(
    'success preserves identity, gifts and acquisition stats while attack grows',
    () {
      final p = Progress()..gold = 10000;
      final item = p.createGear(
        gearById('longsword'),
        rarity: Rarity.unique,
        power: 7,
        vitality: 9,
        focus: 4,
        weaponLevel: 6,
      );
      p.addOwnedGear(item);
      p.equip(item);
      p.unseenGear.add(item.serial);
      final index = p.inventory.indexOf(item);
      final quote = p.smithQuote(item)!;
      final oldAttack = item.attack, oldDamage = p.swordDamage;
      final random = _Roll(0);
      final result = p.enhanceWeapon(quote, random)!;
      final next = result.weapon!;
      expect(next, isNot(same(item)));
      expect(next.serial, item.serial);
      expect(next.base, same(item.base));
      expect(next.gifts, item.gifts);
      expect(next.acquiredLevel, item.acquiredLevel);
      expect(next.affixVersion, item.affixVersion);
      expect(
        (next.power, next.vitality, next.focus),
        (item.power, item.vitality, item.focus),
      );
      expect(next.weaponLevel, 7);
      expect(next.attack, oldAttack + 2);
      expect(quote.currentAttack, oldAttack);
      expect(quote.nextAttack, next.attack);
      expect(
        p.swordDamage,
        closeTo(oldDamage + 2 * p.attackMultiplier, .000001),
      );
      expect(p.inventory[index], same(next));
      expect(p.weapon, same(next));
      expect(p.inventory.contains(item), isFalse);
      expect(p.unseenGear.contains(item.serial), isFalse);
      expect(Progress.fromSave(p.toSave())!.weapon.toSave(), next.toSave());
    },
  );

  test(
    'no gameplay enhancement ceiling and floor probability stays thirty percent',
    () {
      final p = Progress()..gold = 10000000;
      final item = p.createGear(gearById('shortsword'), weaponLevel: 2000);
      p.addOwnedGear(item);
      p.equip(item);
      final initial = item.attack;
      final random = _Roll(0);
      for (var i = 0; i < 25; i++) {
        final quote = p.smithQuote(p.weapon)!;
        expect(quote.successChance, .3);
        expect(p.enhanceWeapon(quote, random)!.succeeded, isTrue);
      }
      expect(p.weapon.weaponLevel, 2025);
      expect(p.weapon.attack, initial + 50);
      expect(random.calls, 25);
      expect(Progress.fromSave(p.toSave())!.weapon.weaponLevel, 2025);
    },
  );

  test(
    'invalid, stale, locked, foreign, unowned or unaffordable requests consume nothing',
    () {
      for (final mutation in ['dead', 'locked', 'removed', 'level', 'funds']) {
        final p = Progress()..gold = 1000;
        final item = p.weapon;
        final quote = p.smithQuote(item)!;
        switch (mutation) {
          case 'dead':
            p.hp = 0;
          case 'locked':
            p.setGearLocked(item, true);
          case 'removed':
            p.inventory.remove(item);
          case 'level':
            p.level++;
          case 'funds':
            p.gold = quote.price - 1;
        }
        final before = p.gold;
        final random = _Roll(0);
        expect(p.enhanceWeapon(quote, random), isNull, reason: mutation);
        expect(p.gold, before);
        expect(random.calls, 0);
      }
      final p = Progress();
      expect(p.smithQuote(p.inventory.last), isNull);
      expect(p.smithQuote(Gear(999, gearById('longsword'))), isNull);
      final foreign = p.createGear(gearById('wand'));
      p.addOwnedGear(foreign);
      expect(p.smithQuote(foreign), isNull);
      p.weapon.locked = true;
      expect(p.smithQuote(p.weapon), isNull);
    },
  );

  test(
    'failure destroys equipped target and selects strongest usable owned alternative',
    () {
      final p = Progress()..gold = 10000;
      final target = p.weapon;
      final weaker = p.createGear(gearById('longsword'), weaponLevel: 1);
      final better = p.createGear(gearById('greatsword'), weaponLevel: 3);
      final foreign = p.createGear(gearById('crystalorb'), weaponLevel: 100);
      for (final item in [weaker, better, foreign]) {
        p.addOwnedGear(item);
      }
      better.locked = true;
      p.unseenGear.add(target.serial);
      final quote = p.smithQuote(target)!;
      final result = p.enhanceWeapon(quote, _Roll(.99999))!;
      expect(result.destroyed, isTrue);
      expect(result.weapon, isNull);
      expect(p.inventory.contains(target), isFalse);
      expect(p.unseenGear.contains(target.serial), isFalse);
      expect(p.weapon, same(better));
      expect(p.usingFallbackWeapon, isFalse);
      expect(p.gold, 10000 - quote.price);
      expect(Progress.fromSave(p.toSave())!.weapon.serial, better.serial);
    },
  );

  test('destroying an unequipped item keeps the current weapon', () {
    final p = Progress()..gold = 1000;
    final current = p.weapon;
    final target = p.createGear(gearById('longsword'));
    p.addOwnedGear(target);
    p.enhanceWeapon(p.smithQuote(target)!, _Roll(1));
    expect(p.weapon, same(current));
    expect(p.inventory.contains(target), isFalse);
  });

  for (final heroClass in HeroClass.values) {
    test(
      '$heroClass last-weapon destruction keeps combat, mounts and checkpoints valid',
      () {
        final s = Adventure(GameArt(), heroClass: heroClass)..start(TestGame());
        addTearDown(s.dispose);
        inCombatField(s);
        final p = s.progress..gold = 1000;
        final target = p.weapon;
        final mount = withOwnedMounts(s).mounts.first
          ..at = s.hero.body.center + const Offset(40, 0);
        expect(s.boardNearbyMount(), isTrue);
        final result = p.enhanceWeapon(p.smithQuote(target)!, _Roll(1))!;
        s.syncLife();
        expect(result.destroyed, isTrue);
        expect(p.usingFallbackWeapon, isTrue);
        expect(
          p.inventory.any(
            (g) => g.base.slot == GearSlot.weapon && g.base.usable(heroClass),
          ),
          isFalse,
        );
        expect(p.weapon.base.usable(heroClass), isTrue);
        expect(p.weapon.attack, greaterThan(0));
        expect(p.swordDamage, greaterThan(0));
        expect(p.attackInterval.isFinite, isTrue);
        expect(p.smithQuote(p.weapon), isNull);
        final gold = p.gold, count = p.inventory.length;
        expect(p.collect(p.weapon), isFalse);
        expect(p.sell(p.weapon), isFalse);
        expect(p.gold, gold);
        expect(p.inventory.length, count);
        expect(() => p.createGear(p.weapon.base), throwsArgumentError);
        final cp = GameCheckpoint.capture(s)!;
        expect(cp.data['progress']['weaponFallback'], isTrue);
        final restored = GameCheckpoint.decode(cp.encode())!.restore(GameArt())
          ..start(TestGame());
        addTearDown(restored.dispose);
        expect(restored.riding?.def.id, mount.def.id);
        expect(restored.progress.usingFallbackWeapon, isTrue);
        final strikes = restored.hero.strikes;
        restored.hero.slash();
        expect(restored.hero.strikes, greaterThan(strikes));
        restored.hero.update(.05);
        expect(restored.progress.basicDamage.isFinite, isTrue);
        if (heroClass == HeroClass.mage) {
          expect(
            (restored.game! as TestGame).added.whereType<ArcaneBolt>(),
            isNotEmpty,
          );
        }
        expect(GameCheckpoint.capture(restored), isNotNull);
      },
    );
  }

  test(
    'first weapon acquired by loot or shop leaves fallback and remains saveable',
    () {
      for (final fromShop in [false, true]) {
        for (final heroClass in HeroClass.values) {
          final s = Adventure(GameArt(), heroClass: heroClass)
            ..start(TestGame());
          addTearDown(s.dispose);
          final p = s.progress..gold = 10000;
          p.enhanceWeapon(p.smithQuote(p.weapon)!, _Roll(1));
          expect(p.usingFallbackWeapon, isTrue);
          final item = fromShop
              ? s.buyGear(
                  gearById(
                    heroClass == HeroClass.warrior ? 'longsword' : 'oakstaff',
                  ),
                )!
              : p.createGear(
                  gearById(
                    heroClass == HeroClass.warrior ? 'shortsword' : 'wand',
                  ),
                );
          if (!fromShop) expect(p.collect(item), isTrue);
          expect(p.usingFallbackWeapon, isFalse);
          expect(p.weapon, same(item));
          expect(Progress.fromSave(p.toSave())!.weapon.serial, item.serial);
          expect(GameCheckpoint.capture(s), isNotNull);
        }
      }
    },
  );

  test('higher-level common weapons are not discarded as duplicate gold', () {
    final p = Progress();
    final improved = p.createGear(p.weapon.base, weaponLevel: 3);
    final before = p.gold;
    expect(p.collect(improved), isTrue);
    expect(p.gold, before);
    final duplicate = p.createGear(p.weapon.base, weaponLevel: 3);
    expect(p.collect(duplicate), isFalse);
    expect(p.gold, greaterThan(before));
    final after = p.gold;
    expect(p.collect(improved), isFalse);
    expect(p.gold, after, reason: 'a repeated owned serial cannot mint gold');
  });

  test(
    'every drop family respects the player-plus-two cap including rare and unique',
    () {
      final levelsSeen = <int>{};
      for (final heroClass in HeroClass.values) {
        for (final level in [1, 7, 40, 10000]) {
          final p = Progress(heroClass: heroClass)..level = level;
          final random = math.Random(410);
          for (var i = 0; i < 200; i++) {
            for (final family in [
              'normal',
              'chest',
              'elite',
              'boss',
              'unique',
            ]) {
              final item = p.rollLoot(
                random,
                chest: family == 'chest',
                elite: family == 'elite',
                boss: family == 'boss',
                unique: family == 'unique',
              );
              if (item.base.slot == GearSlot.weapon) {
                expect(item.weaponLevel, inInclusiveRange(1, level + 2));
                expect(
                  item.weaponLevel,
                  greaterThanOrEqualTo(math.max(1, level - 2)),
                );
                levelsSeen.add(item.weaponLevel! - level);
              } else {
                expect(item.weaponLevel, isNull);
              }
            }
          }
        }
      }
      expect(levelsSeen, containsAll([-2, -1, 0, 1, 2]));
    },
  );

  test(
    'shop quotations and created weapons share the level and real attack',
    () {
      final p = Progress()..level = 21;
      final offer = ShopGearOffer(
        gearById('longsword'),
        WorldStage.tombs,
        acquiredLevel: p.level,
      );
      final preview = offer.preview;
      p.level = 22;
      final bought = offer.create(p);
      expect(preview.weaponLevel, 21);
      expect(bought.weaponLevel, preview.weaponLevel);
      expect(bought.attack, preview.attack);
      expect(offer.matches(bought), isTrue);
      expect(offer.matches(bought.withWeaponLevel(22)), isFalse);
    },
  );

  test('enhancing legacy-affix gear keeps exactly its old abilities', () {
    for (final rarity in [Rarity.rare, Rarity.unique]) {
      final p = Progress()..gold = 1000;
      final item = Gear(
        90,
        gearById('longsword'),
        rarity: rarity,
        power: 7,
        affixVersion: 0,
      );
      p.addOwnedGear(item);
      p.equip(item);
      final result = p.enhanceWeapon(p.smithQuote(item)!, _Roll(0))!;
      expect(result.weapon!.gifts, item.gifts);
      expect(result.weapon!.affixVersion, 0);
      expect(result.weapon!.power, 7);
      expect(result.weapon!.attack, item.attack + 2);
      expect(Progress.fromSave(p.toSave())!.weapon.gifts, item.gifts);
    }
  });

  test(
    'explicit fallback can save an empty inventory without inventing saleable gear',
    () {
      final p = Progress()..gold = 1000;
      p.enhanceWeapon(p.smithQuote(p.weapon)!, _Roll(1));
      p.inventory.clear();
      p.equipped.clear();
      p.unseenGear.clear();
      final restored = Progress.fromSave(p.toSave())!;
      expect(restored.inventory, isEmpty);
      expect(restored.usingFallbackWeapon, isTrue);
      expect(restored.weapon.attack, greaterThan(0));
      final replacement = restored.createGear(gearById('longsword'));
      expect(restored.collect(replacement), isTrue);
      expect(restored.weapon, same(replacement));
      expect(Progress.fromSave(restored.toSave()), isNotNull);
    },
  );

  test(
    'legacy saves retain numeric gear stats and start weapon levels at one',
    () {
      final p = Progress()..level = 21;
      final old = Gear(
        100,
        gearById('longsword'),
        rarity: Rarity.rare,
        power: 7,
        acquiredLevel: 21,
      );
      p.addOwnedGear(old);
      p.equip(old);
      final oldAttack = p.swordDamage;
      final raw = jsonDecode(jsonEncode(p.toSave())) as Map<String, dynamic>;
      raw.remove('weaponFallback');
      for (final item in raw['inventory'] as List) {
        (item as Map).remove('weaponLevel');
      }
      final restored = Progress.fromSave(raw)!;
      expect(restored.weapon.weaponLevel, 1);
      expect(restored.weapon.attack, old.attack);
      expect(restored.swordDamage, oldAttack);
      expect(restored.weapon.gifts, old.gifts);
      expect(restored.weapon.acquiredLevel, 21);
      expect(
        Progress.fromSave(restored.toSave())!.weapon.toSave(),
        restored.weapon.toSave(),
      );
    },
  );

  test(
    'adopting an externally identified real item keeps future serials unique',
    () {
      final p = Progress();
      final item = Gear(700, gearById('longsword'));
      expect(p.collect(item), isTrue);
      expect(p.createGear(gearById('axe')).serial, greaterThan(item.serial));
      expect(Progress.fromSave(p.toSave()), isNotNull);
    },
  );

  test(
    'weapon level validation rejects invalid or nonweapon levels without weakening legacy saves',
    () {
      final weapon = Progress().weapon.toSave();
      for (final value in [-1, 0, .5, '2', double.infinity]) {
        expect(
          () => Gear.fromSave({...weapon, 'weaponLevel': value}),
          throwsFormatException,
        );
      }
      final armor = Gear(99, gearById('linen')).toSave();
      expect(
        () => Gear.fromSave({...armor, 'weaponLevel': 1}),
        throwsFormatException,
      );
      expect(
        () => Gear(99, gearById('linen'), weaponLevel: 1),
        throwsArgumentError,
      );
      final invalid = Progress().toSave();
      (invalid['equipped'] as Map).remove('weapon');
      expect(
        Progress.fromSave(invalid),
        isNull,
        reason: 'legacy missing-weapon corruption is still invalid',
      );
      invalid['weaponFallback'] = true;
      expect(
        Progress.fromSave(invalid),
        isNull,
        reason: 'a usable owned weapon must be autoequipped',
      );
    },
  );

  test(
    'Adventure refuses enhancement outside a live session and after death',
    () {
      final s = Adventure(GameArt());
      addTearDown(s.dispose);
      s.progress.gold = 1000;
      final quote = s.progress.smithQuote(s.progress.weapon)!;
      expect(s.smithQuote(s.progress.weapon), isNull);
      expect(s.enhanceWeapon(quote), isNull);
      s.start(TestGame());
      final before = s.progress.gold;
      s.defeated = true;
      expect(s.smithQuote(s.progress.weapon), isNull);
      expect(s.enhanceWeapon(quote), isNull);
      expect(s.progress.gold, before);
    },
  );
}

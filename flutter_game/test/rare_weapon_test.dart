import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all parents are required at their exact ranks and failures spend nothing',
    () {
      for (final hero in HeroClass.values) {
        final p = Progress(heroClass: hero)..gainXp(7500);
        for (final child in p.skills.where((s) => s.requires.length > 1)) {
          p.ranks.clear();
          for (final requirement in child.requires.entries) {
            p.ranks[requirement.key] = requirement.value;
          }
          expect(p.prerequisitesMet(child), true);
          for (final requirement in child.requires.entries) {
            p.ranks[requirement.key] = requirement.value - 1;
            final points = p.skillPoints;
            expect(
              p.learn(child),
              false,
              reason: '${child.id}: ${requirement.key}',
            );
            expect(p.skillPoints, points);
            p.ranks[requirement.key] = requirement.value;
          }
          expect(p.learn(child), true);
        }
      }
    },
  );
  test(
    'large enemies guarantee yellow class weapons with saved special abilities',
    () {
      for (final hero in HeroClass.values) {
        final p = Progress(heroClass: hero);
        for (var seed = 0; seed < 60; seed++) {
          for (final boss in [false, true]) {
            final item = p.rollLoot(Random(seed), elite: !boss, boss: boss);
            expect(item.rarity, Rarity.rare);
            expect(item.rarity.color, 0xffffd877);
            expect(item.base.slot, GearSlot.weapon);
            expect(item.base.usable(hero), true);
            expect(item.gift, isNotNull);
            expect(item.stats, contains(item.gift!.description));
            expect(Gear.fromSave(item.toSave()).toSave(), item.toSave());
          }
          expect(
            p.rollLoot(Random(seed)).rarity.index,
            lessThan(Rarity.rare.index),
          );
        }
        final bad = p.rollLoot(Random(1), elite: true).toSave()
          ..['gift'] = 'unknown';
        expect(() => Gear.fromSave(bad), throwsFormatException);
      }
    },
  );
  for (final gift in WeaponGift.values.where((gift) => !gift.isCombo)) {
    test('${gift.name} affects real combat without creating extra victims', () {
      final s = Adventure(GameArt());
      s.start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      final p = s.progress;
      final weapon = Gear(
        999,
        gearById('shortsword'),
        rarity: Rarity.rare,
        gift: gift,
      );
      p.inventory.add(weapon);
      expect(p.equip(weapon), true);
      final victim = s.spawnEnemy('goblin', const Offset(6100, 4200))!;
      final other = s.spawnEnemy('goblin', const Offset(6150, 4200))!;
      final otherLife = other.life.value;
      p.hp = p.maxHp - 30;
      s.syncLife();
      if (gift == WeaponGift.guardian) {
        final hp = p.hp, damage = p.mitigate(20, protection: s.hero.protection);
        s.hurtHero(20);
        expect(p.hp, closeTo(hp - damage * .92, .001));
      } else if (gift == WeaponGift.frost) {
        s.hit(victim, 1, Offset.zero);
        expect(victim.slow, .8);
      } else {
        final hp = p.hp;
        s.hit(victim, 10000, Offset.zero);
        expect(p.hp, hp + 4);
        s.hit(victim, 10000, Offset.zero);
        expect(p.hp, hp + 4);
        s.defeated = true;
        s.hit(other, 10000, Offset.zero);
        expect(p.hp, hp + 4);
      }
      expect(other.life.value, otherLife);
    });
  }
}

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/death_penalty.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/rpg_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'death destroys exactly one owned weapon, including equipped locked gear',
    () {
      final p = Progress()
        ..gold = 1000
        ..hp = 0;
      final weapons = p.inventory
          .where((g) => g.base.slot == GearSlot.weapon)
          .toList();
      expect(weapons.length, 1);
      weapons.single.locked = true;
      final armor = p.inventory
          .where((g) => g.base.slot == GearSlot.armor)
          .single;
      final loss = DeathLoss.apply(p, Random(7));
      expect(loss.weaponSerial, weapons.single.serial);
      expect(p.inventory, contains(armor));
      expect(p.inventory.any((g) => g.base.slot == GearSlot.weapon), false);
      expect(p.usingFallbackWeapon, true);
      expect(p.hp, 0);
      expect(p.gold, 1000 - loss.goldLost);
    },
  );
  test(
    'gold loss is random from zero through thirty percent and never creates gold',
    () {
      final seen = <int>{};
      for (var seed = 0; seed < 500; seed++) {
        final p = Progress()..gold = 1000;
        final loss = DeathLoss.apply(p, Random(seed));
        expect(loss.goldPercent, inInclusiveRange(0, 30));
        expect(loss.goldLost, 1000 * loss.goldPercent ~/ 100);
        seen.add(loss.goldPercent);
      }
      expect(seen, containsAll([0, 30]));
      final empty = Progress();
      empty.inventory.removeWhere((g) => g.base.slot == GearSlot.weapon);
      empty.equipped.remove(GearSlot.weapon);
      final loss = DeathLoss.apply(empty, Random(1));
      expect(loss.weaponSerial, isNull);
      expect(empty.gold, 0);
    },
  );
  test(
    'actual defeat applies once and paid revival survives reload without rerolling',
    () {
      final s = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(s.dispose);
      s.progress.gold = 1000;
      s.hurtHero(1000000, periodic: true);
      expect(s.defeated, true);
      expect(s.deathLoss, isNotNull);
      final gold = s.progress.gold, serial = s.deathLoss!.weaponSerial;
      s.hurtHero(1000000, periodic: true);
      expect(s.progress.gold, gold);
      expect(s.deathLoss!.weaponSerial, serial);
      expect(GameCheckpoint.capture(s), isNull);
      final saved = GameCheckpoint.capture(s, forDefeat: true)!;
      expect(saved.revival, true);
      final reloaded = GameCheckpoint.decode(saved.encode())!;
      expect(reloaded.progress.gold, gold);
      expect(reloaded.progress.inventory.any((g) => g.serial == serial), false);
      final consumed = reloaded.forRevival();
      expect(consumed.revival, true);
      expect(
        GameCheckpoint.decode(consumed.encode())!.revival,
        false,
        reason: 'disk marker consumed before input',
      );
      final revived = consumed.restore(GameArt())..start(TestGame());
      addTearDown(revived.dispose);
      expect(revived.progress.hp, revived.progress.maxHp);
      expect(revived.progress.energy, revived.progress.maxEnergy);
      expect(revived.hero.revivalProtection, CombatBalance.revivalProtection);
      expect(revived.progress.gold, gold);
      final repeated = saved.forRevival().forRevival();
      expect(repeated.progress.gold, gold);
      expect(repeated.progress.inventory.any((g) => g.serial == serial), false);
    },
  );
}

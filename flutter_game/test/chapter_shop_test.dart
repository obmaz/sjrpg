import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/equipment_panel.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stage in WorldStage.values) {
    for (final hero in HeroClass.values) {
      test('$stage $hero quotes and purchases identical chapter gear', () {
        final s = Adventure(GameArt(), stage: stage, heroClass: hero);
        s.start(TestGame());
        addTearDown(s.dispose);
        final p = s.progress
          ..level = 6
          ..gold = 2000;
        final before = p.toSave();
        final tier = stage == WorldStage.forest
            ? 0
            : stage == WorldStage.sands
            ? 1
            : stage == WorldStage.past || stage == WorldStage.future
            ? 2
            : stage == WorldStage.convergence
            ? 4
            : 3;
        for (var i = 0; i < 10; i++) {
          for (final offer in s.shopGearOffers) {
            expect(offer.preview.gift, null);
            expect(
              offer.preview.rarity,
              tier == 0 ? Rarity.common : Rarity.magic,
            );
          }
        }
        expect(
          p.toSave(),
          before,
          reason: 'browsing must not spend serials, gold or inventory',
        );
        for (final id
            in hero == HeroClass.warrior
                ? ['longsword', 'chainmail', 'amber']
                : ['oakstaff', 'silkrobe', 'sapphire']) {
          final def = gearById(id), offer = s.gearOffer(def);
          final snapshot = p.toSave();
          expect(s.buyGear(def, expectedPrice: offer.price + 1), null);
          expect(p.toSave(), snapshot);
          final gold = p.gold;
          final bought = s.buyGear(def, expectedPrice: offer.price)!;
          expect(p.gold, gold - def.value * (1 + tier * 2));
          expect(offer.matches(bought), true);
          expect(
            bought.toSave()..remove('serial'),
            offer.preview.toSave()..remove('serial'),
          );
          expect(bought.gift, null);
          expect(s.equip(bought), true);
          if (def.slot == GearSlot.weapon) {
            expect(bought.weaponLevel, p.level);
            expect(
              bought.attack,
              def.attack + tier * 3 + (p.level - 1) * Gear.weaponAttackPerLevel,
            );
          }
          if (def.slot == GearSlot.armor) {
            expect(bought.health, def.health + tier * 10);
          }
          if (def.slot == GearSlot.charm) {
            expect(bought.health, def.health + tier * 5);
            expect(bought.mana, def.mana + tier * 4);
          }
        }
        final saved = GameCheckpoint.capture(s)!;
        final restored = GameCheckpoint.decode(
          saved.encode(),
        )!.restore(GameArt());
        addTearDown(restored.dispose);
        expect(restored.world.stage, stage);
        expect(restored.progress.toSave(), p.toSave());
        expect(
          restored.shopGearOffers.map((o) => o.price),
          s.shopGearOffers.map((o) => o.price),
        );
        final state = p.toSave();
        expect(s.buyGear(gearById('sentinel')), null);
        expect(
          s.buyGear(
            gearById(hero == HeroClass.warrior ? 'oakstaff' : 'longsword'),
          ),
          null,
        );
        expect(p.toSave(), state);
      });
    }
  }
  for (final stage in [WorldStage.sands, WorldStage.future]) {
    testWidgets(
      '$stage upgrades an owned common base directly at 320x420 and rejects a rapid duplicate',
      (tester) async {
        tester.view.physicalSize = const Size(320, 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = Adventure(GameArt(), stage: stage);
        s.start(TestGame());
        s.pause();
        addTearDown(s.dispose);
        final p = s.progress
          ..level = 6
          ..gold = 1000;
        final old = p.createGear(gearById('longsword'));
        p.inventory.add(old);
        p.equip(old);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: EquipmentPanel(session: s, startInShop: true, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        final price = stage == WorldStage.sands ? 150 : 250;
        final buy = find.bySemanticsLabel('맹공의 기병의 장검 구매 후 장착 · $price 골드');
        await tester.scrollUntilVisible(
          buy,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(buy);
        await tester.tap(buy);
        await tester.pumpAndSettle();
        expect(p.gold, 1000 - price);
        expect(p.weapon.rarity, Rarity.magic);
        expect(p.weapon.power, stage == WorldStage.sands ? 3 : 6);
        expect(p.inventory.where((g) => g.base.id == 'longsword').length, 2);
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), null);
        semantics.dispose();
      },
    );
  }
  for (final hero in HeroClass.values) {
    testWidgets(
      '$hero charm resource comparison matches the usable resource pool',
      (tester) async {
        final s = Adventure(
          GameArt(),
          stage: WorldStage.future,
          heroClass: hero,
        );
        s.start(TestGame());
        s.pause();
        addTearDown(s.dispose);
        s.progress.level = 6;
        s.progress.gold = 1000;
        final before = s.progress.maxEnergy;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: EquipmentPanel(session: s, startInShop: true, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('부적'));
        await tester.pumpAndSettle();
        expect(find.textContaining(hero.resource), findsWidgets);
        expect(
          find.textContaining(hero == HeroClass.warrior ? '마나' : '분노'),
          findsNothing,
        );
        final name = hero == HeroClass.warrior ? '생명의 호박 부적' : '생명의 청금석 부적';
        final price = hero == HeroClass.warrior ? 200 : 225;
        final buy = find.bySemanticsLabel('$name 구매 후 장착 · $price 골드');
        await tester.scrollUntilVisible(
          buy,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(buy);
        await tester.pumpAndSettle();
        expect(
          s.progress.maxEnergy,
          before + (hero == HeroClass.warrior ? 8 : 26),
        );
        expect(s.progress.equipped[GearSlot.charm]!.focus, 8);
        expect(tester.takeException(), null);
        semantics.dispose();
      },
    );
  }
}

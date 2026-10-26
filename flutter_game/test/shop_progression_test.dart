import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/equipment_panel.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final hero in HeroClass.values) {
    test(
      '$hero shop stock grows at level five and locked purchases spend nothing',
      () {
        final s = inCombatField(Adventure(GameArt(), heroClass: hero));
        s.start(TestGame());
        addTearDown(s.dispose);
        final p = s.progress..gold = 500;
        final advanced = gearById(
          hero == HeroClass.warrior ? 'runeblade' : 'crystalorb',
        );
        expect(p.shopGear.contains(advanced), false);
        final before = p.toSave();
        expect(s.buyGear(advanced), null);
        expect(p.toSave(), before);
        for (var i = 0; i < 10; i++) {
          p.shopGear;
        }
        expect(p.toSave(), before);
        p.level = 4;
        expect(p.shopGear.contains(advanced), false);
        p.level = 5;
        expect(p.shopGear.contains(advanced), true);
        expect(p.shopGear.map((g) => g.id).toSet().length, p.shopGear.length);
        expect(p.shopGear.every((g) => g.usable(hero)), true);
        expect(p.shopGear.any((g) => g.id == 'sentinel'), false);
        final item = s.buyGear(advanced)!;
        expect(item.base, advanced);
        expect(item.rarity, Rarity.common);
        expect(p.gold, 500 - advanced.value);
        expect(p.inventory.contains(item), true);
      },
    );
  }
  test(
    'training costs grow, stale prices cannot charge and levels bound repeated upgrades',
    () {
      final s = inCombatField(Adventure(GameArt()));
      s.start(TestGame());
      addTearDown(s.dispose);
      final p = s.progress
        ..level = 6
        ..gold = 500;
      expect(s.buySword(expectedPrice: 45), true);
      expect(p.bonusAttack, 5);
      expect(p.gold, 455);
      expect(s.buySword(expectedPrice: 45), false);
      expect(p.gold, 455);
      expect(s.buySword(expectedPrice: 80), true);
      expect(p.bonusAttack, 10);
      expect(p.gold, 375);
      expect(s.buySword(), false);
      expect(p.gold, 375);
      p.level = 7;
      expect(s.buySword(expectedPrice: 115), true);
      expect(p.gold, 260);
      p.hp = 40;
      final maxHp = p.maxHp;
      expect(s.buyVitality(expectedPrice: 60), true);
      expect(p.maxHp, maxHp + 20);
      expect(p.hp, p.maxHp);
      expect(p.gold, 200);
      expect(s.buyVitality(expectedPrice: 60), false);
      expect(p.gold, 200);
      p.bonusHealth = p.maxTrainingRank * 20.0;
      p.hp = 5;
      expect(s.buyVitality(), false);
      expect(p.hp, 5);
      expect(p.gold, 200);
    },
  );
  test(
    'death and disposal reject every merchant purchase without changing the checkpoint',
    () {
      final s = inCombatField(Adventure(GameArt()));
      s.start(TestGame());
      s.progress.gold = 500;
      for (final dead in [true, false]) {
        s.progress.hp = dead ? 0 : 50;
        if (!dead) s.dispose();
        final before = s.progress.toSave();
        expect(s.buyHeal(), false);
        expect(s.buyEnergy(), false);
        expect(s.buySword(), false);
        expect(s.buyVitality(), false);
        expect(s.buyGear(gearById('longsword')), null);
        expect(s.progress.toSave(), before);
      }
    },
  );
  testWidgets(
    'rapid training taps respect the displayed price and small-screen cap actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = inCombatField(Adventure(GameArt()));
      s.start(TestGame());
      s.pause();
      addTearDown(s.dispose);
      s.progress.level = 6;
      s.progress.gold = 500;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: EquipmentPanel(session: s, startInShop: true, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('축복'));
      await tester.pumpAndSettle();
      final quoted = find.bySemanticsLabel('무기 강화 구매 · 45 골드');
      await tester.tap(quoted);
      await tester.tap(quoted);
      await tester.pumpAndSettle();
      expect(s.progress.gold, 455);
      expect(s.progress.bonusAttack, 5);
      await tester.tap(find.bySemanticsLabel('무기 강화 구매 · 80 골드'));
      await tester.pumpAndSettle();
      expect(s.progress.gold, 375);
      expect(s.progress.bonusAttack, 10);
      expect(
        tester
            .widget<GameAction>(find.widgetWithText(GameAction, '수련 완료').first)
            .onTap,
        null,
      );
      expect(tester.takeException(), null);
      semantics.dispose();
    },
  );
  test(
    'the first boss awards a rare weapon and its unique relic once, and both can travel',
    () {
      final s = inCombatField(Adventure(GameArt()));
      s.start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.cleansedSites.addAll(questSites.map((q) => q.id));
      s.progress.kills = stageKillGoal;
      final boss = s.spawnEnemy('golem', const Offset(6300, 4200), boss: true)!;
      s.hit(boss, 10000000, Offset.zero);
      expect(s.loot.length, 2);
      final rare = s.loot.singleWhere((g) => g.item.rarity == Rarity.rare);
      final relic = s.loot.singleWhere((g) => g.item.rarity == Rarity.unique);
      expect(rare.item.base.slot, GearSlot.weapon);
      expect(rare.item.gift, isNotNull);
      expect(relic.item.base.id, 'sentinel');
      expect(s.stageCleared, true);
      final gold = s.progress.gold;
      s.continueExploring();
      s.hit(boss, 10000000, Offset.zero);
      expect(s.loot.length, 2);
      expect(s.progress.gold, gold);
      final next = GameCheckpoint.advance(s)!;
      expect((next.data['loot'] as List).length, 2);
    },
  );
  for (final size in const [Size(320, 420), Size(390, 844)]) {
    testWidgets(
      'armor and charms equip directly from stock categories at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = inCombatField(Adventure(GameArt()));
        s.start(TestGame());
        s.pause();
        addTearDown(s.dispose);
        s.progress.gainXp(1000);
        s.progress.gold = 500;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: EquipmentPanel(session: s, startInShop: true, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        for (final (tab, name, price, slot, base) in [
          ('방어구', '사슬 갑옷', 70, GearSlot.armor, 'chainmail'),
          ('부적', '호박 부적', 40, GearSlot.charm, 'amber'),
        ]) {
          await tester.tap(find.bySemanticsLabel(tab));
          await tester.pumpAndSettle();
          final buy = find.bySemanticsLabel('$name 구매 후 장착 · $price 골드');
          await tester.scrollUntilVisible(
            buy,
            100,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(buy);
          await tester.pumpAndSettle();
          expect(s.progress.equipped[slot]!.base.id, base);
          expect(find.byType(Dialog), findsNothing);
        }
        expect(s.progress.gold, 390);
        expect(tester.takeException(), null);
        semantics.dispose();
      },
    );
  }
}

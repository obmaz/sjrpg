import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/equipment_panel.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/rpg_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  setUp(() {
    s = Adventure(GameArt());
    s.start(TestGame());
    s.pause();
  });
  tearDown(() => s.dispose());

  test(
    'gear purchases preserve money and capacity on failure and reject another class',
    () {
      s.progress.gold = 49;
      expect(s.buyGear(gearById('longsword')), null);
      expect(s.progress.gold, 49);
      s.progress.gold = 200;
      expect(s.buyGear(gearById('oakstaff')), null);
      final gear = s.buyGear(gearById('longsword'))!;
      expect(s.progress.inventory.contains(gear), true);
      expect(s.progress.gold, 150);
      expect(s.progress.isEquipped(gear), false);
      while (s.progress.inventory.length < Progress.capacity) {
        s.progress.inventory.add(s.progress.createGear(gearById('amber')));
      }
      expect(s.buyGear(gearById('axe')), null);
      expect(s.progress.gold, 150);
      expect(s.progress.inventory.length, Progress.capacity);
    },
  );

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      150,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [
    Size(320, 420),
    Size(320, 640),
    Size(390, 844),
    Size(844, 390),
  ]) {
    testWidgets(
      'one-screen equipment actions stay reachable without opening a modal at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        Gear? first;
        for (var i = 0; i < 20; i++) {
          final item = s.progress.createGear(
            gearById('longsword'),
            rarity: Rarity.rare,
            power: i + 1,
          );
          s.progress.inventory.add(item);
          first ??= item;
        }
        final gear = first!;
        await tester.pumpWidget(
          MaterialApp(
            home: EquipmentPanel(session: s, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        final footer = find.bySemanticsLabel('모험 계속하기');
        final rect = tester.getRect(footer);
        final equip = find.byKey(ValueKey('equip-${gear.serial}'));
        await reveal(tester, equip);
        expect(tester.getRect(footer), rect);
        await tester.tap(equip);
        await tester.pumpAndSettle();
        expect(s.progress.isEquipped(gear), true);
        expect(find.byType(Dialog), findsNothing);
        expect(find.byTooltip('옵션 접기'), findsNothing);
        expect(tester.getRect(footer), rect);
        final info = find.bySemanticsLabel('보관 장비 · ${gear.name} · 장착 중');
        await reveal(tester, info);
        await tester.tap(info);
        await tester.pumpAndSettle();
        final collapse = find.byTooltip('옵션 접기');
        await reveal(tester, collapse);
        expect(find.byType(Dialog), findsNothing);
        expect(tester.getRect(footer), rect);
        await tester.tap(collapse);
        await tester.pumpAndSettle();
        expect(find.byTooltip('옵션 접기'), findsNothing);
        expect(tester.takeException(), null);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'merchant equips with one purchase tap, blocks repeated quick purchase and updates potions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      s.progress.gold = 200;
      await tester.pumpWidget(
        MaterialApp(
          home: EquipmentPanel(session: s, startInShop: true, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final buy = find.byKey(const ValueKey('buy-equip-longsword'));
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(s.progress.gold, 150);
      expect(s.progress.inventory.length, 3);
      expect(s.progress.weapon.base.id, 'longsword');
      expect(find.byType(Dialog), findsNothing);
      expect(find.byTooltip('옵션 접기'), findsNothing);
      expect(tester.widget<GameAction>(buy).onTap, null);
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(s.progress.gold, 150);
      expect(s.progress.inventory.length, 3);
      await tester.tap(find.bySemanticsLabel('기병의 장검 · 50 골드'));
      await tester.pumpAndSettle();
      final keep = find.bySemanticsLabel('기병의 장검 구매 후 보관 · 50 골드');
      await reveal(tester, keep);
      final equipped = s.progress.weapon;
      await tester.tap(keep);
      await tester.pumpAndSettle();
      expect(s.progress.gold, 100);
      expect(s.progress.inventory.length, 4);
      expect(s.progress.weapon, equipped);
      expect(s.progress.unseenGear, isEmpty);
      await tester.tap(find.bySemanticsLabel('물약'));
      await tester.pumpAndSettle();
      final potions = s.progress.healingPotions;
      final healing = find.bySemanticsLabel('치유 물약 ×2 구매 · 80 골드');
      await reveal(tester, healing);
      await tester.tap(healing);
      await tester.pumpAndSettle();
      expect(s.progress.healingPotions, potions + 2);
      expect(s.progress.gold, 20);
      expect(find.text('생명 55,000 회복 · 보유 ${potions + 2}개'), findsOneWidget);
      expect(tester.takeException(), null);
      semantics.dispose();
    },
  );

  testWidgets(
    'full bags block quick purchase and keep purchase without charging gold',
    (tester) async {
      s.progress.gold = 500;
      while (s.progress.inventory.length < Progress.capacity) {
        s.progress.inventory.add(s.progress.createGear(gearById('amber')));
      }
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: EquipmentPanel(session: s, startInShop: true, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GameAction>(
              find.byKey(const ValueKey('buy-equip-longsword')),
            )
            .onTap,
        null,
      );
      await tester.tap(find.bySemanticsLabel('기병의 장검 · 50 골드'));
      await tester.pumpAndSettle();
      final keep = find.bySemanticsLabel('기병의 장검 구매 후 보관 · 50 골드');
      await reveal(tester, keep);
      expect(
        tester
            .widget<GameAction>(find.widgetWithText(GameAction, '구매 후 가방에 보관'))
            .onTap,
        null,
      );
      expect(s.progress.gold, 500);
      expect(s.progress.inventory.length, Progress.capacity);
      expect(tester.takeException(), null);
      semantics.dispose();
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/equipment_panel.dart';
import 'package:guardian_new/game_art.dart';
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

  for (final size in const [
    Size(320, 420),
    Size(320, 640),
    Size(390, 844),
    Size(844, 390),
  ]) {
    testWidgets(
      'bag details keep actions reachable and preserve grid scroll at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        for (var i = 0; i < 20; i++) {
          s.progress.inventory.add(
            s.progress.createGear(
              gearById(i % 2 == 0 ? 'longsword' : 'chainmail'),
              rarity: Rarity.rare,
              power: i + 1,
            ),
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            home: EquipmentPanel(session: s, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        final footer = find.bySemanticsLabel('모험 계속하기');
        final rect = tester.getRect(footer);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.getRect(footer), rect);
        final gridState = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final offset = gridState.position.pixels;
        final cells = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label ?? '').startsWith('보관 장비 · 맹공의 기병의 장검'),
        );
        final cell = cells.evaluate().firstWhere((e) {
          final r = tester.getRect(find.byWidget(e.widget));
          return r.center.dy > 150 && r.center.dy < rect.top;
        });
        await tester.tap(find.byWidget(cell.widget));
        await tester.pumpAndSettle();
        final equip = find.bySemanticsLabel('장착');
        expect(tester.getRect(equip).bottom, lessThanOrEqualTo(size.height));
        await tester.tap(equip);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('장착 중'), findsOneWidget);
        await tester.tap(find.byTooltip('상세 닫기'));
        await tester.pumpAndSettle();
        expect(gridState.position.pixels, closeTo(offset, .1));
        expect(tester.takeException(), null);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'merchant purchase can equip immediately and potion totals stay current',
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
      await tester.tap(find.bySemanticsLabel('기병의 장검 · 50 골드'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('50 G · 구매'));
      await tester.pumpAndSettle();
      expect(s.progress.gold, 150);
      expect(s.progress.inventory.length, 3);
      await tester.tap(find.bySemanticsLabel('장착'));
      await tester.pumpAndSettle();
      expect(s.progress.weapon.base.id, 'longsword');
      await tester.tap(find.byTooltip('상세 닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('가방'));
      await tester.pumpAndSettle();
      expect(find.text('장비 가방'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('상점'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('물약'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('치유 물약 ×2 · 20 골드'));
      await tester.pumpAndSettle();
      final potions = s.progress.healingPotions;
      await tester.tap(find.bySemanticsLabel('20 G · 구매'));
      await tester.pumpAndSettle();
      expect(s.progress.healingPotions, potions + 2);
      expect(s.progress.gold, 130);
      expect(find.text('생명 55 회복 · 보유 ${potions + 2}개'), findsOneWidget);
      expect(tester.takeException(), null);
      semantics.dispose();
    },
  );
}

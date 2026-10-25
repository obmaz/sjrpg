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
  test('locked equipment can swap but cannot sell until unlocked', () {
    final p = Progress();
    final old = p.weapon;
    final gear = p.createGear(
      gearById('longsword'),
      rarity: Rarity.rare,
      power: 3,
    );
    p.inventory.add(gear);
    final gold = p.gold;
    expect(p.setGearLocked(gear, true), true);
    expect(p.sell(gear), false);
    expect(p.gold, gold);
    expect(p.equip(gear), true);
    expect(p.equip(old), true);
    expect(p.sell(gear), false);
    expect(p.setGearLocked(gear, false), true);
    expect(p.sell(gear), true);
    expect(p.gold, gold + gear.saleValue);
    expect(p.inventory.contains(gear), false);
  });
  test(
    'locks belong to owned instances and survive saves with old-save defaults',
    () {
      final p = Progress();
      final original = p.weapon;
      final clone = Gear.fromSave(original.toSave());
      expect(p.setGearLocked(clone, true), false);
      expect(original.locked, false);
      expect(p.setGearLocked(original, true), true);
      expect(clone.locked, false);
      final restored = Progress.fromSave(p.toSave())!;
      expect(restored.weapon.locked, true);
      expect(restored.toSave(), p.toSave());
      final old = original.toSave()..remove('locked');
      expect(Gear.fromSave(old).locked, false);
      expect(
        () => Gear.fromSave({...old, 'locked': 'yes'}),
        throwsFormatException,
      );
    },
  );
  for (final size in [const Size(320, 420), const Size(390, 844)]) {
    testWidgets(
      'lock controls block sale and filter without overflow at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        final s = Adventure(GameArt());
        s.start(TestGame());
        s.pause();
        addTearDown(s.dispose);
        final p = s.progress;
        final gear = p.createGear(
          gearById('longsword'),
          rarity: Rarity.rare,
          power: 3,
        );
        p.inventory.add(gear);
        await tester.pumpWidget(
          MaterialApp(
            home: EquipmentPanel(session: s, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('보관 장비 · 맹공의 기병의 장검'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('장비 잠금'));
        await tester.pumpAndSettle();
        expect(gear.locked, true);
        expect(
          tester
              .widget<GameAction>(find.widgetWithText(GameAction, '잠긴 장비'))
              .onTap,
          null,
        );
        await tester.tap(find.byTooltip('상세 닫기'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('잠금'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('보관 장비 · 맹공의 기병의 장검 · 잠금'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('장비 잠금 해제'));
        await tester.pumpAndSettle();
        final gold = p.gold;
        await tester.tap(find.bySemanticsLabel('판매 +${gear.saleValue} G'));
        await tester.pumpAndSettle();
        expect(p.gold, gold + gear.saleValue);
        expect(find.text('잠근 장비가 없습니다'), findsOneWidget);
        expect(tester.takeException(), null);
        semantics.dispose();
      },
    );
  }
}

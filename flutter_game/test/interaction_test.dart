import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/equipment_panel.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('nearby actions prioritize chests and choose one closest villager', () {
    final s = Adventure(GameArt());
    s.start(TestGame());
    addTearDown(s.dispose);
    s.hero.position.setValues(3790 * worldScale, 2965 * worldScale);
    expect(s.nearbyAction, NearbyAction.talk);
    s.hero.position.setValues(3950 * worldScale, 2984 * worldScale);
    expect(s.nearbyAction, NearbyAction.shop);
    s.hero.position.setValues(
      stageChests.first.dx - 12,
      stageChests.first.dy - 11,
    );
    expect(s.nearbyAction, NearbyAction.chest);
    s.openChest();
    expect(s.nearbyAction, isNot(NearbyAction.chest));
    s.hero.position.setValues(4638, 349);
    expect(s.nearbyAction, null);
    s.hero.position.setValues(6000, 4200);
    expect(s.nearbyAction, null);
  });
  test('new equipment markers survive saves and never mark duplicate gold', () {
    final p = Progress();
    final gear = p.createGear(
      gearById('longsword'),
      rarity: Rarity.rare,
      power: 5,
    );
    expect(p.collect(gear), true);
    expect(p.unseenGear, {gear.serial});
    final duplicate = p.createGear(gearById('longsword'));
    expect(p.collect(duplicate), false);
    expect(p.unseenGear, {gear.serial});
    final restored = Progress.fromSave(p.toSave())!;
    expect(restored.unseenGear, {gear.serial});
    restored.equip(
      restored.inventory.firstWhere((g) => g.serial == gear.serial),
    );
    expect(restored.unseenGear, isEmpty);
    expect(p.sell(gear), true);
    expect(p.unseenGear, isEmpty);
    final legacy = p.toSave()..remove('unseenGear');
    expect(Progress.fromSave(legacy)!.unseenGear, isEmpty);
    expect(
      Progress.fromSave({
        ...p.toSave(),
        'unseenGear': [999999],
      }),
      null,
    );
  });
  testWidgets('new gear tab marks only inspected equipment as read', (
    tester,
  ) async {
    final s = Adventure(GameArt());
    s.start(TestGame());
    s.pause();
    addTearDown(s.dispose);
    final gear = s.progress.createGear(
      gearById('longsword'),
      rarity: Rarity.rare,
      power: 4,
    );
    s.progress.collect(gear);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentPanel(session: s, onClose: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('신규'));
    await tester.pumpAndSettle();
    final cell = find.bySemanticsLabel('보관 장비 · ${gear.name} · 신규');
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(s.progress.unseenGear, isEmpty);
    await tester.tap(find.bySemanticsLabel('전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('신규'));
    await tester.pumpAndSettle();
    expect(find.text('확인하지 않은 새 장비가 없습니다'), findsOneWidget);
    expect(tester.takeException(), null);
    semantics.dispose();
  });
}

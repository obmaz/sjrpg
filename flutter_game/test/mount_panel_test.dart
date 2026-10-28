import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/mount_panel.dart';
import 'package:guardian_new/panel_controls.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session() {
    final s = Adventure(GameArt())..start(TestGame());
    final at = s.mountMerchantAt;
    s.hero.position.setValues(at.dx - 14, at.dy - 12);
    s.progress.gold = 10000;
    s.pause();
    addTearDown(s.dispose);
    return s;
  }

  Future<void> panel(
    WidgetTester t,
    Adventure s, {
    double scale = 1,
    VoidCallback? save,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!,
        ),
        home: Scaffold(
          body: MountPanel(session: s, onClose: () {}, onCheckpoint: save),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
  }

  testWidgets('purchase saves once and never boards automatically', (t) async {
    final s = session();
    var saves = 0;
    await panel(t, s, save: () => saves++);
    final semantics = t.ensureSemantics();
    expect(s.mounts, isEmpty);
    await t.tap(find.bySemanticsLabel('말 구매 · 90 골드'));
    await t.pump();
    expect(s.progress.gold, 9910);
    expect(s.progress.mountProgress.owns('horse'), true);
    expect(s.mounts.length, 1);
    expect(s.riding, isNull);
    expect(saves, 1);
    expect(find.bySemanticsLabel('말 구매 · 90 골드'), findsNothing);
    expect(find.bySemanticsLabel('말 부르기'), findsOneWidget);
    expect(t.takeException(), null);
    semantics.dispose();
  });
  testWidgets('fallen horse repair and motorcycle upgrades expose real costs', (
    t,
  ) async {
    final s = session();
    expect(s.buyMount('horse'), true);
    expect(s.buyMount('motor'), true);
    final horse = s.progress.mountProgress.stateFor('horse')
      ..durability = 0
      ..hits = 3
      ..fallen = true;
    var saves = 0;
    await panel(t, s, save: () => saves++);
    final semantics = t.ensureSemantics();
    await t.tap(find.bySemanticsLabel('말 보수 · 40 골드'));
    await t.pump();
    expect(horse.fallen, false);
    expect(horse.hits, 0);
    expect(horse.durability, 100);
    expect(saves, 1);
    final upgrade = find.bySemanticsLabel('오토바이 기관포 강화 · 180 골드');
    await t.scrollUntilVisible(
      upgrade,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(upgrade);
    await t.pumpAndSettle();
    await t.tap(upgrade);
    await t.pump();
    expect(s.progress.mountProgress.motorLevel, 1);
    expect(saves, 2);
    expect(find.bySemanticsLabel('오토바이 기관포 강화 · 320 골드'), findsOneWidget);
    s.progress.mountProgress.motorAmmo = 0;
    s.refresh();
    await t.pump();
    final ammo = find.bySemanticsLabel('오토바이 탄약 보충');
    await t.scrollUntilVisible(
      ammo,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(ammo);
    await t.pumpAndSettle();
    await t.tap(ammo);
    await t.pump();
    expect(s.progress.mountProgress.motorAmmo, 12);
    expect(saves, 3);
    expect(t.takeException(), null);
    semantics.dispose();
  });
  for (final size in [
    const Size(320, 420),
    const Size(390, 844),
    const Size(844, 390),
    const Size(667, 375),
  ]) {
    testWidgets('merchant cards and footer fit $size at large fonts', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = session();
      await panel(t, s, scale: 1.3);
      final semantics = t.ensureSemantics();
      final footer = find.widgetWithText(GameAction, '모험 계속하기');
      final r = t.getRect(footer);
      expect(r.top, greaterThan(0));
      expect(r.bottom, lessThanOrEqualTo(size.height));
      for (final label in [
        '말 구매 · 90 골드',
        '자전거 구매 · 110 골드',
        '오토바이 구매 · 420 골드',
        '배 구매 · 180 골드',
      ]) {
        final a = find.bySemanticsLabel(label);
        await t.scrollUntilVisible(
          a,
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await t.pump();
        expect(a.hitTestable(), findsOneWidget, reason: label);
        final b = t.getRect(a);
        expect(b.left, greaterThanOrEqualTo(10));
        expect(b.right, lessThanOrEqualTo(size.width - 10));
        expect(b.bottom, lessThanOrEqualTo(r.top));
        expect(t.takeException(), null);
      }
      semantics.dispose();
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/equipment_panel.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/interface_art.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var fontLoaded = false;

  Future<void> showBag(
    WidgetTester tester,
    Adventure session,
    Size size,
    double scale, {
    bool shopping = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (!fontLoaded) {
      await tester.runAsync(() async {
        await (FontLoader(
              'Guardian',
            )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf')))
            .load();
        await prepareInterfaceArtwork();
      });
      fontLoaded = true;
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Guardian'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: EquipmentPanel(
            session: session,
            onClose: () {},
            startInShop: shopping,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Adventure session() {
    final s = Adventure(GameArt())
      ..start(TestGame())
      ..pause();
    addTearDown(s.dispose);
    return s;
  }

  for (final (size, scale) in [
    (const Size(320, 420), 1.0),
    (const Size(320, 420), 1.3),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 1.3),
  ]) {
    testWidgets('bag comparisons and equip fit Guardian at $size / $scale', (
      tester,
    ) async {
      final s = session();
      s.progress.gold = 100000;
      for (var i = 0; i < 5; i++) {
        s.progress.inventory.add(s.progress.createGear(gearById('longsword')));
      }
      final gear = s.progress.createGear(gearById('longsword'));
      s.progress.inventory.add(gear);
      await showBag(tester, s, size, scale);
      final list = find.byKey(const PageStorageKey('equipment-list'));
      final viewport = tester.getRect(list);
      final footer = find.bySemanticsLabel('모험 계속하기');
      final close = find.byTooltip('닫기');
      final footerRect = tester.getRect(footer);
      final closeRect = tester.getRect(close);
      final summary = find.byKey(const ValueKey('equipment-overview'));
      final summaryTop = tester.getTopLeft(summary).dy;
      for (final slot in GearSlot.values) {
        expect(
          tester.getSize(find.byKey(ValueKey('equipped-slot-${slot.name}'))),
          const Size(44, 44),
        );
      }
      expect(find.byTooltip('부적 · 비어 있음'), findsOneWidget);
      expect(find.bySemanticsLabel('빈 부적 장비 칸'), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(find.bySemanticsLabel('빈 부적 장비 칸'))
            .properties
            .button,
        false,
      );
      expect(tester.widget<GameTabs>(find.byType(GameTabs)).flat, true);
      expect(footerRect.height, greaterThanOrEqualTo(44));
      final equip = find.byKey(ValueKey('equip-${gear.serial}'));
      // Move less than one card height; the overview uses the same scroll.
      tester.widget<CustomScrollView>(list).controller!.jumpTo(70);
      await tester.pumpAndSettle();
      if (summary.evaluate().isNotEmpty) {
        expect(tester.getTopLeft(summary).dy, lessThan(summaryTop));
      }
      expect(tester.widget<CustomScrollView>(list).controller!.offset, 70);
      final row = find.byKey(ValueKey('gear-row-${gear.serial}'));
      final comparisons = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && widget.textSpan != null,
        ),
      );
      expect(comparisons, findsNWidgets(2));
      final comparisonText = tester
          .widgetList<Text>(comparisons)
          .map((widget) => widget.textSpan!.toPlainText())
          .toList();
      expect(comparisonText.first, startsWith('공격 ${gear.attack.round()}'));
      expect(
        comparisonText.last,
        startsWith(
          '초당 ${s.progress.previewBasicAttack(gear)!.dps.toStringAsFixed(1)}',
        ),
      );
      for (final target in [
        equip,
        ...comparisons.evaluate().map((e) => find.byWidget(e.widget)),
      ]) {
        final rect = tester.getRect(target);
        expect(rect.top, greaterThanOrEqualTo(viewport.top));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
      }
      await tester.tap(equip);
      await tester.pumpAndSettle();
      expect(s.progress.isEquipped(gear), true);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.getRect(footer), footerRect);
      expect(tester.getRect(close), closeRect);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'short merchant footer keeps both actions at the same touch height',
    (tester) async {
      final s = session();
      s.progress.gold = 100000;
      await showBag(tester, s, const Size(320, 420), 1.3, shopping: true);
      final toggle = tester.getRect(find.bySemanticsLabel('가방'));
      final resume = tester.getRect(find.bySemanticsLabel('모험 계속하기'));
      expect(toggle.height, greaterThanOrEqualTo(44));
      expect(toggle.height, resume.height);
      expect(toggle.top, resume.top);
      await tester.tap(find.bySemanticsLabel('가방'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.bySemanticsLabel('상점')), toggle);
      expect(tester.getRect(find.bySemanticsLabel('모험 계속하기')), resume);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large values wrap overview and equipped icon pins its item', (
    tester,
  ) async {
    final s = session();
    s.progress.gold = 999999999;
    s.progress.bonusAttack = 12345678;
    s.progress.bonusHealth = 12345678;
    for (var i = 0; i < 5; i++) {
      s.progress.inventory.add(s.progress.createGear(gearById('longsword')));
    }
    await showBag(tester, s, const Size(320, 420), 1.3);
    final summary = find.byKey(const ValueKey('equipment-overview'));
    final stats = find.descendant(of: summary, matching: find.byType(Text));
    for (final element in stats.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(
        paragraph.getMaxIntrinsicHeight(paragraph.size.width),
        lessThanOrEqualTo(paragraph.size.height + .01),
      );
    }
    expect(find.text('999999999'), findsOneWidget);
    final equipped = s.progress.weapon;
    await tester.tap(find.byKey(const ValueKey('equipped-slot-weapon')));
    await tester.pumpAndSettle();
    final list = tester.widget<CustomScrollView>(
      find.byKey(const PageStorageKey('equipment-list')),
    );
    expect(list.controller!.offset, 0);
    expect(find.byTooltip('옵션 접기'), findsOneWidget);
    final rows = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('gear-row-'),
    );
    expect(
      tester.widget(rows.first).key,
      ValueKey('gear-row-${equipped.serial}'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('new loot omits overview and keeps direct equip after reading', (
    tester,
  ) async {
    final s = session();
    final gear = s.progress.createGear(gearById('longsword'));
    s.progress.collect(gear);
    await showBag(tester, s, const Size(320, 420), 1.3);
    final tabs = tester.widget<GameTabs>(find.byType(GameTabs));
    expect(tabs.selected, tabs.labels.indexOf('신규'));
    expect(find.byKey(const ValueKey('equipment-overview')), findsNothing);
    final equip = find.byKey(ValueKey('equip-${gear.serial}'));
    final rect = tester.getRect(equip);
    final viewport = tester.getRect(
      find.byKey(const PageStorageKey('equipment-list')),
    );
    expect(rect.top, greaterThanOrEqualTo(viewport.top));
    expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
    await tester.tap(equip);
    await tester.pumpAndSettle();
    expect(s.progress.isEquipped(gear), true);
    expect(s.progress.unseenGear.contains(gear.serial), false);
    expect(equip, findsOneWidget);
    expect(find.byKey(const ValueKey('equipment-overview')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

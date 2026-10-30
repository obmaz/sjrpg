import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/skills_panel.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  for (final hero in HeroClass.values) {
    for (final size in [const Size(320, 420), const Size(844, 390)]) {
      testWidgets('$hero primary can unequip and re-equip its basic at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final art = GameArt();
        final session = Adventure(art, heroClass: hero)..start(TestGame());
        addTearDown(session.dispose);
        addTearDown(art.dispose);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: SkillsPanel(session: session, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        final name = session.progress.basicSkill.name;
        await tester.tap(find.bySemanticsLabel('주 슬롯 · $name'));
        await tester.pumpAndSettle();
        final surface = find.byKey(const ValueKey('skill-detail-surface'));
        final bounds = tester.getRect(surface);
        expect(bounds.center.dy, closeTo(size.height / 2, 1));
        expect(bounds.center.dx, closeTo(size.width / 2, 1));
        final material = tester.widget<Material>(surface);
        expect(material.clipBehavior, Clip.antiAlias);
        expect(find.byTooltip('현재: $name'), findsWidgets);
        final remove = find.bySemanticsLabel('$name · 주 슬롯 해제');
        expect(
          remove,
          findsOneWidget,
          reason: tester
              .widgetList<Semantics>(find.byType(Semantics))
              .map((w) => w.properties.label)
              .where((s) => s != null && s.contains('슬롯'))
              .join(' | '),
        );
        await tester.ensureVisible(remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(session.progress.primarySkill, isNull);
        final equip = find.bySemanticsLabel('$name · 주 슬롯에 장착');
        await tester.ensureVisible(equip);
        await tester.tap(equip);
        await tester.pumpAndSettle();
        expect(session.progress.primarySkill!.name, name);
        final slot = hero == HeroClass.warrior ? 1 : 0;
        final auxiliary = find.bySemanticsLabel(
          '$name · 슬롯 ${slot + 1} 지정${slot == 0 ? ' · 사용 중' : ''}',
        );
        await tester.ensureVisible(auxiliary);
        await tester.tap(auxiliary);
        await tester.pumpAndSettle();
        expect(session.progress.skillAt(slot)!.name, name);
        expect(
          Progress.fromSave(session.progress.toSave())!.skillAt(slot)!.name,
          name,
        );

        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
}

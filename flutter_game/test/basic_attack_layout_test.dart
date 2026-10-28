import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/basic_attack_strip.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree.dart';
import 'package:guardian_new/skills_panel.dart';

import 'basic_selection_test.dart' show train;
import 'support/test_game.dart';

void main() {
  for (final heroClass in HeroClass.values) {
    for (final size in [
      const Size(300, 450),
      const Size(320, 420),
      const Size(844, 390),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '$heroClass basic strip and selection fit $size text $scale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final s = Adventure(GameArt(), heroClass: heroClass)
              ..start(TestGame());
            s.pause();
            s.progress.gainXp(50000);
            addTearDown(s.dispose);
            final p = s.progress;
            for (final basic in p.basicSkills) {
              train(p, basic.id);
            }
            p.selectBasic(p.defaultBasicId);
            final slots = p.skillSlots.toList(), points = p.skillPoints;
            final semantics = tester.ensureSemantics();
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: SkillsPanel(session: s, onClose: () {}),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(BasicAttackStrip), findsOneWidget);
            if (heroClass == HeroClass.warrior) {
              expect(p.basicSkills.map((skill) => skill.id), ['cleave']);
              expect(find.bySemanticsLabel('기본 공격 일반 공격 선택'), findsNothing);
              final target = find.byKey(const ValueKey('skill-node-bash'));
              await Scrollable.ensureVisible(
                tester.element(target),
                alignment: .5,
              );
              await tester.pumpAndSettle();
              final visible = tester
                  .getRect(target)
                  .intersect(tester.getRect(find.byType(SkillTree)));
              expect(visible.width, greaterThanOrEqualTo(44));
              expect(visible.height, greaterThanOrEqualTo(44));
              await tester.tap(target);
              await tester.pumpAndSettle();
              expect(p.selectedBasic, 'cleave');
              expect(p.skillPoints, points);
              expect(p.skillSlots, slots);
              expect(tester.takeException(), null);
              semantics.dispose();
              return;
            }
            final bounds = <Rect>[];
            for (final basic in p.basicSkills) {
              final target = find.bySemanticsLabel('기본 공격 ${basic.name} 선택'),
                  rect = tester.getRect(target);
              expect(rect.height, greaterThanOrEqualTo(44));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(size.width));
              expect(rect.bottom, lessThan(size.height));
              for (final previous in bounds) {
                expect(previous.overlaps(rect), false);
              }
              bounds.add(rect);
              await tester.tap(target);
              await tester.pumpAndSettle();
              expect(p.selectedBasic, basic.id);
              expect(p.skillPoints, points);
              expect(p.skillSlots, slots);
              expect(tester.takeException(), null);
            }
            await tester.tap(find.byTooltip('스킬 설명과 배치'));
            await tester.pumpAndSettle();
            final chosen = p.basicSkill;
            expect(
              find.bySemanticsLabel('${chosen.name} 기본 공격으로 사용'),
              findsOneWidget,
            );
            expect(find.text('전투 슬롯'), findsNothing);
            expect(tester.takeException(), null);
            await tester.tap(find.byTooltip('스킬 상세 닫기'));
            await tester.pumpAndSettle();
            expect(p.skillSlots, slots);
            expect(tester.takeException(), null);
            semantics.dispose();
          },
        );
      }
    }
  }
  testWidgets(
    'an unlearned basic is inspected, then learned and selected in one investment',
    (tester) async {
      tester.view.physicalSize = const Size(320, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = Adventure(GameArt(), heroClass: HeroClass.mage)
        ..start(TestGame());
      s.pause();
      s.progress.gainXp(1000);
      addTearDown(s.dispose);
      final p = s.progress,
          slots = p.skillSlots.toList(),
          points = p.skillPoints;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: SkillsPanel(session: s, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('기본 공격 서리 창 살펴보기'));
      await tester.pumpAndSettle();
      expect(p.selectedBasic, p.defaultBasicId);
      expect(p.skillPoints, points);
      await tester.tap(find.bySemanticsLabel('서리 창 습득 · 1P'));
      await tester.pumpAndSettle();
      expect(p.selectedBasic, 'iceShard');
      expect(p.rank('iceShard'), 1);
      expect(p.skillPoints, points - 1);
      expect(p.skillSlots, slots);
      expect(find.bySemanticsLabel('기본 공격 서리 창 선택'), findsOneWidget);
      expect(tester.takeException(), null);
      semantics.dispose();
    },
  );
}

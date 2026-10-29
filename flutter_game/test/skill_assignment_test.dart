import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/back_actions.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree_layout.dart';
import 'package:guardian_new/skills_panel.dart';

import 'support/test_game.dart';

void main() {
  for (final hero in HeroClass.values) {
    test(
      '$hero assignments preserve a nonempty primary and unique saved slots',
      () {
        final p = Progress(heroClass: hero);
        final primary = p.selectedSkill, before = p.toSave();
        expect(p.canSelectSkill(primary), true);
        for (var slot = 1; slot < 4; slot++) {
          expect(p.canSelectSkill(primary, slot: slot), false);
          expect(p.selectSkill(primary, slot: slot), false);
          expect(p.toSave(), before);
        }
        expect(
          p.canSelectSkill(
            hero == HeroClass.warrior ? 'cleave' : 'sorceressAttack',
          ),
          hero == HeroClass.warrior,
        );
        expect(p.canSelectSkill('missing'), false);
        expect(p.canSelectSkill(primary, slot: -1), false);
        expect(p.canSelectSkill(primary, slot: 4), false);

        p.gainXp(4000);
        p.skillPoints = 10;
        final extraId = hero == HeroClass.warrior ? 'bash' : 'frozenArmor';
        expect(p.learn(p.skills.firstWhere((s) => s.id == extraId)), true);
        expect(p.skillAt(1)?.id, extraId);
        expect(p.canSelectSkill(primary, slot: 1), true);
        expect(p.selectSkill(primary, slot: 1), true);
        expect(p.selectedSkill, extraId);
        expect(p.skillAt(1)?.id, primary);
        expect(p.canSelectSkill(primary, slot: 3), true);
        expect(p.selectSkill(primary, slot: 3), true);
        expect(p.skillAt(1), null);
        expect(p.skillAt(3)?.id, primary);
        final restored = Progress.fromSave(p.toSave())!;
        expect(restored.skillSlots, p.skillSlots);
        expect(restored.skillSlots.whereType<String>().toSet(), {
          primary,
          extraId,
        });
      },
    );

    testWidgets(
      '$hero explains its mandatory auxiliary slot without restricting the main slot',
      (tester) async {
        tester.view.physicalSize = const Size(320, 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = Adventure(GameArt(), heroClass: hero)..start(TestGame());
        addTearDown(s.dispose);
        s.pause();
        final skill = s.progress.skillAt(0)!;
        final backActions = BackActions();
        var closed = 0;
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: SkillsPanel(
                session: s,
                backActions: backActions,
                onClose: () => closed++,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final primary = find.bySemanticsLabel('전투 슬롯 1 · ${skill.name}');
          if (primary.evaluate().isNotEmpty) {
            await tester.tap(primary);
          } else {
            // Short portrait layouts collapse the duplicate loadout row. The
            // actual school/node/info route still exposes every assignment.
            await tester.tap(
              find.byKey(
                ValueKey(
                  'skill-school-tab-${skillTreeSchoolIndex(s.progress, skill.id)}',
                ),
              ),
            );
            await tester.pumpAndSettle();
            final node = find.byKey(ValueKey('skill-node-${skill.id}'));
            await Scrollable.ensureVisible(tester.element(node), alignment: .5);
            await tester.pumpAndSettle();
            await tester.tap(node);
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('스킬 설명과 배치'));
          }
          await tester.pumpAndSettle();
          for (var slot = 2; slot <= 4; slot++) {
            final action = find.widgetWithText(GameAction, '$slot');
            expect(tester.widget<GameAction>(action).onTap, null);
            expect(tester.getRect(action).bottom, lessThan(420));
          }
          expect(find.text('보조 1번 슬롯은 다른 기술과 교체할 수 있습니다.'), findsOneWidget);
          expect(s.progress.selectedSkill, skill.id);
          expect(s.progress.skillSlots.skip(1), everyElement(isNull));
          backActions.dispatch();
          await tester.pumpAndSettle();
          expect(find.byTooltip('스킬 상세 닫기'), findsNothing);
          expect(find.text('스킬 트리'), findsOneWidget);
          expect(closed, 0);
          expect(s.progress.selectedSkill, skill.id);
          backActions.dispatch();
          expect(closed, 1);
          expect(tester.takeException(), null);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

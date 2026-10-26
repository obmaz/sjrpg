import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/rpg_model.dart';
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
        expect(p.canSelectSkill(p.skills.first.id), false);
        expect(p.canSelectSkill('missing'), false);
        expect(p.canSelectSkill(primary, slot: -1), false);
        expect(p.canSelectSkill(primary, slot: 4), false);

        p.gainXp(4000);
        p.skillPoints = 10;
        final extraId = hero == HeroClass.warrior ? 'whirlwind' : 'iceArmor';
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
      '$hero explains why its only primary cannot move to an empty slot',
      (tester) async {
        tester.view.physicalSize = const Size(320, 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = Adventure(GameArt(), heroClass: hero)..start(TestGame());
        addTearDown(s.dispose);
        s.pause();
        final skill = s.progress.skillAt(0)!;
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
              home: SkillsPanel(session: s, onClose: () {}),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('전투 슬롯 1 · ${skill.name}'));
          await tester.pumpAndSettle();
          for (var slot = 2; slot <= 4; slot++) {
            final action = find.widgetWithText(GameAction, '$slot');
            expect(tester.widget<GameAction>(action).onTap, null);
            expect(tester.getRect(action).bottom, lessThan(420));
          }
          expect(
            find.text('1번 슬롯은 비울 수 없습니다. 다른 기술과 자리를 바꿀 수 있어요.'),
            findsOneWidget,
          );
          expect(s.progress.selectedSkill, skill.id);
          expect(s.progress.skillSlots.skip(1), everyElement(isNull));
          expect(tester.takeException(), null);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

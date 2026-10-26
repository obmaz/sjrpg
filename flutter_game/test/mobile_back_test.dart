import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/back_actions.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/skills_panel.dart';

import 'support/test_game.dart';

void main() {
  testWidgets(
    'back closes skill detail, then the tree, and cancels reset safely',
    (tester) async {
      final actions = BackActions(),
          s = Adventure(GameArt())..start(TestGame());
      s.pause();
      addTearDown(s.dispose);
      s.progress.gainXp(4000);
      s.progress.learn(s.progress.skills.firstWhere((d) => d.id == 'mastery'));
      var closed = 0, fallback = 0;
      actions.register(() => fallback++);
      await tester.pumpWidget(
        MaterialApp(
          home: PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) actions.dispatch();
            },
            child: SkillsPanel(
              session: s,
              onClose: () => closed++,
              backActions: actions,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ranks = Map.of(s.progress.ranks), gold = s.progress.gold;
      await tester.tap(find.byTooltip('스킬 설명과 배치'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('스킬 상세 닫기'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byTooltip('스킬 상세 닫기'), findsNothing);
      expect(closed, 0);
      await tester.tap(find.byTooltip('스킬 초기화'));
      await tester.pumpAndSettle();
      expect(find.text('스킬 초기화'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('스킬 초기화'), findsNothing);
      expect(s.progress.ranks, ranks);
      expect(s.progress.gold, gold);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(closed, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      actions.dispatch();
      expect(fallback, 1);
      expect(closed, 1);
      expect(tester.takeException(), null);
    },
  );
}

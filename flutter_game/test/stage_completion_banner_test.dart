import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_panels.dart';
import 'package:guardian_new/stage_completion_banner.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt art;
  setUpAll(() async {
    art = await GameArt.load();
  });
  tearDownAll(() {
    for (final shader in art.materials) {
      shader.dispose();
    }
    for (final image in art.images.values) {
      image.dispose();
    }
  });
  for (final stage in WorldStage.values) {
    for (final size in const [Size(320, 420), Size(844, 390)]) {
      testWidgets(
        '$stage completion crest and real objectives preserve the next action at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final s = Adventure(art, stage: stage)..start(TestGame());
          addTearDown(s.dispose);
          if (stage == WorldStage.sands) s.timePath = TimePath.past;
          if (stage.requiresContract) {
            s.hero.position.setValues(
              s.world.elderAt.dx - 14,
              s.world.elderAt.dy - 12,
            );
            expect(s.acceptChapterContract(), true);
          }
          s.cleansedSites.addAll(s.visibleSites.map((q) => q.id));
          s.progress.kills = stage.killGoal;
          s.progress.bossDefeated = true;
          s.completeStageIfReady();
          var advanced = false, closed = false;
          await tester.pumpWidget(
            MaterialApp(
              home: AdventurePanel(
                session: s,
                name: 'victory',
                onClose: () => closed = true,
                onRestart: () {},
                onAdvance: () => advanced = true,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(art.images['victory-crest']!.width, 512);
          expect(find.byType(StageCompletionBanner), findsOneWidget);
          expect(
            find.bySemanticsLabel(
              stage == WorldStage.sands ? '필수 의뢰 · 4/4' : '필수 의뢰 · 3/3',
            ),
            findsOneWidget,
          );
          expect(find.bySemanticsLabel('보스 토벌 · 완료'), findsOneWidget);
          final action = find.bySemanticsLabel(
            stage.hasNextStage ? stage.advanceLabel(s.timePath) : '계속 탐험하기',
          );
          final rect = tester.getRect(action);
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(rect.height, greaterThanOrEqualTo(48));
          await tester.tap(action);
          await tester.pump();
          expect(stage.hasNextStage ? advanced : closed, true);
          if (!stage.hasNextStage) expect(s.won, false);
          expect(tester.takeException(), null);
        },
      );
    }
  }
}

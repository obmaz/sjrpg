import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_panels.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in const [Size(320, 420), Size(390, 844), Size(844, 390)]) {
    for (final (stage, path) in [
      (WorldStage.forest, null),
      (WorldStage.sands, TimePath.past),
      (WorldStage.sands, TimePath.future),
      (WorldStage.past, TimePath.past),
      (WorldStage.future, TimePath.future),
      (WorldStage.tombs, TimePath.past),
      (WorldStage.foundry, TimePath.future),
      (WorldStage.convergence, TimePath.past),
      (WorldStage.convergence, TimePath.future),
    ]) {
      testWidgets(
        'resumed cleared ${stage.name} $path keeps the correct footer pinned at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final canAdvance = stage.hasNextStage;
          final completed = Adventure(GameArt(), stage: stage)
            ..start(TestGame());
          addTearDown(completed.dispose);
          completed.timePath = path;
          if (stage.requiresContract) {
            completed.hero.position.setValues(
              completed.world.elderAt.dx - 14,
              completed.world.elderAt.dy - 12,
            );
            expect(completed.acceptChapterContract(), true);
          }
          completed.cleansedSites.addAll(
            stage == WorldStage.sands
                ? timeCommissions.where((q) => q.path == path).map((q) => q.id)
                : completed.world.sites.map((site) => site.id),
          );
          completed.progress.bossDefeated = true;
          completed.progress.kills = stage.killGoal;
          final saved = GameCheckpoint.decode(
            GameCheckpoint.capture(completed)!.encode(),
          );
          expect(saved, isNotNull);
          final session = saved!.restore(GameArt())..start(TestGame());
          addTearDown(session.dispose);
          session.pause();
          expect(session.stageCleared, true);
          expect(
            session.won,
            false,
            reason:
                'reload allows exploration without replaying the victory modal',
          );
          var closed = 0, advanced = 0;
          GameCheckpoint? next;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AdventurePanel(
                  session: session,
                  name: 'journal',
                  onClose: () => closed++,
                  onRestart: () {},
                  onAdvance: () {
                    advanced++;
                    next = GameCheckpoint.advance(session);
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final target = find.text(
            canAdvance ? stage.advanceLabel(path) : '모험 계속하기',
          );
          expect(
            target,
            findsOneWidget,
            reason: 'the next chapter has one primary action',
          );
          final initial = tester.getRect(target);
          expect(initial.bottom, lessThan(size.height - 12));
          expect(initial.top, greaterThan(0));
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(target), initial);
          await tester.tap(find.byTooltip('닫기'));
          expect(closed, 1);
          expect(
            next,
            null,
            reason: 'closing the journal still continues exploration',
          );
          await tester.tap(target);
          await tester.pumpAndSettle();
          if (canAdvance) {
            expect(next!.data['stage'], stage.nextStage(path)!.name);
            expect(advanced, 1);
            expect(closed, 1);
          } else {
            expect(next, null);
            expect(advanced, 0);
            expect(closed, 2);
          }
          expect(tester.takeException(), null);
        },
      );
    }
  }
}

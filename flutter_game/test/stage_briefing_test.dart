import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/main.dart';
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
  for (final stage in [WorldStage.past, WorldStage.future]) {
    for (final brief in [true, false]) {
      testWidgets(
        '$stage briefs only a fresh transition, not ordinary resume: $brief',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final source = Adventure(art, stage: stage)..start(TestGame());
          source.pause();
          final checkpoint = GameCheckpoint.capture(source)!;
          source.dispose();
          await tester.pumpWidget(
            MaterialApp(
              home: GamePage(
                art: art,
                checkpoint: checkpoint,
                showStageBriefing: brief,
                onRestart: () {},
              ),
            ),
          );
          for (var i = 0; i < 160; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 1)),
            );
          }
          final game = tester.widget<BonfireWidget>(find.byType(BonfireWidget));
          final session = (game.player! as Guardian).session;
          expect(session.ready, true);
          expect(session.world.stage, stage);
          expect(find.text(stage.title), brief ? findsOneWidget : findsNothing);
          expect(session.active, !brief);
          if (brief) {
            final elapsed = session.elapsed, hp = session.progress.hp;
            await tester.pump(const Duration(seconds: 2));
            expect(session.elapsed, elapsed);
            expect(session.progress.hp, hp);
            expect(find.text(stage.commission), findsOneWidget);
            await tester.tap(find.text('모험 계속하기'));
            await tester.pump(const Duration(milliseconds: 16));
            await tester.pump(const Duration(milliseconds: 16));
            expect(find.text(stage.title), findsNothing);
            expect(session.active, true);
            await tester.pump(const Duration(milliseconds: 100));
            expect(find.text(stage.title), findsNothing);
          }
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }
  }
}

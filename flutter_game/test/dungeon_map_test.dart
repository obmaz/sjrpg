import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/dungeon.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stage in WorldStage.values) {
    test(
      '${stage.name} instance map paints without outdoor service lookups',
      () async {
        final art = GameArt();
        addTearDown(art.dispose);
        final session = Adventure(
          art,
          stage: stage,
          dungeon: DungeonRun(stage, 8),
        )..start(TestGame());
        addTearDown(session.dispose);
        for (final round in [true, false]) {
          final recorder = ui.PictureRecorder();
          MapPainter(
            session,
            round: round,
          ).paint(ui.Canvas(recorder), const ui.Size(512, 384));
          final picture = recorder.endRecording();
          final image = await picture.toImage(512, 384);
          expect(image.width, 512);
          image.dispose();
          picture.dispose();
        }
      },
    );
  }
}

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'round minimap uses one flat plan while expanded map retains scene art',
    () async {
      final art = GameArt();
      final worldSession = Adventure(art)..start(TestGame());
      addTearDown(worldSession.dispose);
      addTearDown(art.dispose);
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawColor(const ui.Color(0xffff00ff), ui.BlendMode.src);
      final picture = recorder.endRecording(),
          photo = await picture.toImage(16, 16);
      picture.dispose();
      final key = worldSession.world.authoredSettlement.imageKey;
      Future<Uint8List> pixels(bool round) async {
        final recorder = ui.PictureRecorder();
        MapPainter(worldSession, round: round).paint(
          ui.Canvas(recorder),
          round ? const ui.Size(85, 85) : const ui.Size(600, 450),
        );
        final picture = recorder.endRecording(),
            image = await picture.toImage(round ? 85 : 600, round ? 85 : 450);
        picture.dispose();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        image.dispose();
        return data;
      }

      final roundWithout = await pixels(true),
          expandedWithout = await pixels(false);
      art.images[key] = photo;
      expect(
        listEquals(await pixels(true), roundWithout),
        true,
        reason:
            'perspective photographs cannot overlap the tiny vector minimap',
      );
      expect(
        listEquals(await pixels(false), expandedWithout),
        false,
        reason: 'expanded map keeps its optional detailed settlement scene',
      );
    },
  );
}

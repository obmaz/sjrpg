import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/world_model.dart';

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
  test(
    'nearby enemies and facing use their real positions on the compact map',
    () async {
      final session = Adventure(GameArt())..start(TestGame());
      addTearDown(session.dispose);
      session.mobs.clear();
      session.hero.position.setValues(6000, 4200);
      final enemy = session.spawnEnemy(
        'goblin',
        session.hero.body.center + const ui.Offset(300, 0),
      )!;
      enemy.combatReady = true;
      Future<Uint8List> paint(double bearing) async {
        session.hero.bearing = bearing;
        final recorder = ui.PictureRecorder();
        MapPainter(session).paint(ui.Canvas(recorder), const ui.Size(200, 200));
        final picture = recorder.endRecording();
        final image = await picture.toImage(200, 200);
        picture.dispose();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        image.dispose();
        return data;
      }

      final east = await paint(0);
      final north = await paint(-math.pi / 2);
      final view = localMapBounds(session.hero.body.center);
      final x = ((enemy.body.center.dx - view.left) / view.width * 200).round();
      final y = ((enemy.body.center.dy - view.top) / view.height * 200).round();
      final at = (y * 200 + x) * 4;
      expect(east[at], greaterThan(200));
      expect(east[at + 1], lessThan(100));
      expect(east[at + 2], lessThan(70));
      expect(
        listEquals(east, north),
        false,
        reason: 'the player arrow follows the actual facing',
      );
    },
  );
}

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stage in WorldStage.values) {
    test(
      '${stage.name} maps real water and the landmark at their world coordinates',
      () async {
        final world = AdventureWorld(stage: stage), art = GameArt();
        final terrain = TerrainArt(world, art);
        addTearDown(terrain.dispose);
        addTearDown(art.dispose);
        final lake = world.lakes.firstWhere(
          (lake) => world.isWater(lake.bounds.center),
        );
        Future<List<int>> at(ui.Offset point) async {
          final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
          final view = ui.Rect.fromCenter(
            center: point,
            width: 3000,
            height: 3000,
          );
          canvas.scale(256 / 3000);
          canvas.translate(-view.left, -view.top);
          terrain.mapPlan.paint(canvas, view, unitsPerPixel: 3000 / 256);
          final picture = recorder.endRecording(),
              image = await picture.toImage(256, 256);
          final bytes = (await image.toByteData())!.buffer.asUint8List();
          final result = bytes.sublist(
            (128 * 256 + 128) * 4,
            (128 * 256 + 128) * 4 + 4,
          );
          image.dispose();
          picture.dispose();
          return result;
        }

        expect(await at(lake.bounds.center), [0x42, 0x6b, 0x75, 0xff]);
        final organic =
            stage == WorldStage.forest || stage == WorldStage.convergence;
        expect(
          await at(world.landmarks.first.center),
          organic ? [0x35, 0x4e, 0x3b, 0xff] : [0x64, 0x62, 0x58, 0xff],
        );
      },
    );
  }
}

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cached ground covers fractional-camera clip rounding without gaps',
    () async {
      final world = AdventureWorld(stage: WorldStage.sands);
      final art = GameArt();
      for (var i = 0; i < 12; i++) {
        art.materials.add(
          ui.Gradient.linear(ui.Offset.zero, const ui.Offset(512, 512), const [
            ui.Color(0xffa89776),
            ui.Color(0xffb9aa8c),
          ]),
        );
      }
      final terrain = TerrainArt(world, art);
      addTearDown(() {
        terrain.dispose();
        art.dispose();
      });
      // Fractional projection must find complete neighbor ground on all sides.
      // A cell whose clip stops exactly at512 can expose the older biome under
      // field material and roads in Skwasm, even with antialiasing disabled.
      const col = 20, row = 20;
      for (final fraction in [0.0, .25, .5, .75]) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder)
          ..translate(4 + fraction - col * 512, 4 + fraction - row * 512);
        canvas.drawPicture(terrain.sector(col, row));
        final picture = recorder.endRecording();
        final image = await picture.toImage(522, 522);
        picture.dispose();
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          int alpha(int x, int y) => data.getUint8((y * 522 + x) * 4 + 3);
          for (final point in const [
            (3, 200),
            (516, 200),
            (200, 3),
            (200, 516),
          ]) {
            expect(
              alpha(point.$1, point.$2),
              255,
              reason: 'opaque shared-cell guard at fraction $fraction, $point',
            );
          }
          expect(
            alpha(0, 200),
            0,
            reason: 'bounded recording, not an entire map',
          );
          expect(alpha(520, 200), 0);
        } finally {
          image.dispose();
        }
      }
      expect(terrain.cache.length, 1);
    },
  );
}

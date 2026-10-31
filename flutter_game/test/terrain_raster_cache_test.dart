import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

Future<Uint8List> pixels(
  void Function(ui.Canvas) draw,
  int width,
  int height,
) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return Uint8List.fromList(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt art;
  late TerrainArt terrain;
  setUp(() {
    art = GameArt();
    for (var i = 0; i < 12; i++) {
      art.materials.add(
        ui.Gradient.linear(ui.Offset.zero, const ui.Offset(512, 512), const [
          ui.Color(0xff597b58),
          ui.Color(0xffb8a78d),
        ]),
      );
    }
    terrain = TerrainArt(AdventureWorld(stage: WorldStage.sands), art);
  });
  tearDown(() {
    terrain.dispose();
    art.dispose();
  });

  test(
    'fractional camera movement reuses a finished tile, not its command stream',
    () async {
      final density =
          ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;
      final image = terrain.rasterSector(20, 20, density: density);
      for (final fraction in [.1, .4, .75]) {
        await pixels(
          (canvas) {
            canvas.translate(fraction - 20 * 512, fraction - 20 * 512);
            terrain.render(
              canvas,
              const ui.Rect.fromLTWH(20 * 512 + 1, 20 * 512 + 1, 500, 500),
            );
          },
          512,
          512,
        );
        expect(
          identical(terrain.rasterSector(20, 20, density: density), image),
          true,
        );
        expect(terrain.rasterTileCount, 1);
      }
      final alternateDensity = density.clamp(1, 3) == 2 ? 1.0 : 2.0;
      final dense = terrain.rasterSector(20, 20, density: alternateDensity);
      expect(dense.width, (516 * alternateDensity).round());
      expect(identical(dense, image), false);
      expect(
        identical(
          terrain.rasterSector(20, 20, density: alternateDensity),
          dense,
        ),
        true,
      );
    },
  );

  test(
    'raster pixels preserve the opaque ground and two-pixel guard',
    () async {
      const col = 20, row = 20;
      for (final density in [1.0, 2.0]) {
        final size = (516 * density).round();
        final expected = await pixels(
          (canvas) {
            canvas.scale(density);
            canvas.translate(2 - col * 512, 2 - row * 512);
            canvas.drawPicture(terrain.sector(col, row));
          },
          size,
          size,
        );
        final tile = terrain.rasterSector(col, row, density: density);
        final actual = (await tile.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        expect(
          actual.buffer.asUint8List(actual.offsetInBytes, actual.lengthInBytes),
          expected,
          reason: 'density $density is rasterized at native output resolution',
        );
      }
    },
  );

  test(
    'high-density travel evicts images within both memory and tile budgets',
    () {
      final first = terrain.rasterSector(20, 20, density: 3);
      for (var col = 21; col < 48; col++) {
        terrain.rasterSector(col, 20, density: 3);
        expect(terrain.rasterTileCount, lessThanOrEqualTo(24));
        expect(
          terrain.rasterBytes,
          lessThanOrEqualTo(TerrainArt.maxRasterBytes),
        );
      }
      expect(first.debugDisposed, true);
      final last = terrain.rasterSector(47, 20, density: 3);
      terrain.dispose();
      expect(last.debugDisposed, true);
      expect(terrain.rasterTileCount, 0);
      expect(terrain.rasterBytes, 0);
      final recorder = ui.PictureRecorder();
      terrain.render(
        ui.Canvas(recorder),
        const ui.Rect.fromLTWH(0, 0, 512, 512),
      );
      recorder.endRecording().dispose();
      expect(
        terrain.rasterTileCount,
        0,
        reason: 'late frames cannot recreate disposed images',
      );
      expect(() => terrain.rasterSector(47, 20), throwsStateError);
    },
  );
}

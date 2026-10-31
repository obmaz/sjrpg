import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/field_landscape.dart';
import 'package:guardian_new/meadow_tiles.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'seeded grass cells cover all four variants without changing on repaint',
    () {
      final cells = [
        for (var y = 0; y < 24; y++)
          for (var x = 0; x < 24; x++) MeadowTiles.variant(7829, x, y),
      ];
      expect(cells.toSet(), MeadowTile.values.toSet());
      expect(cells, [
        for (var y = 0; y < 24; y++)
          for (var x = 0; x < 24; x++) MeadowTiles.variant(7829, x, y),
      ]);
      expect(
        cells,
        isNot([
          for (var y = 0; y < 24; y++)
            for (var x = 0; x < 24; x++) MeadowTiles.variant(7830, x, y),
        ]),
      );
    },
  );
  test('four grass tile faces remain visibly distinct and grounded', () async {
    final source = await rootBundle.load(
      'assets/images/field-grass-variants.webp',
    );
    final codec = await instantiateImageCodec(source.buffer.asUint8List());
    final texture = (await codec.getNextFrame()).image;
    codec.dispose();
    expect(texture.width, 1024);
    expect(texture.height, 256);
    final shader = ImageShader(
      texture,
      TileMode.clamp,
      TileMode.clamp,
      Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
    );
    final hashes = <int>{};
    for (final variant in MeadowTile.values) {
      final r = PictureRecorder(), c = Canvas(r);
      c.drawColor(const Color(0xff6a744b), BlendMode.src);
      MeadowTiles.paint(c, Offset.zero, variant, shader);
      final p = r.endRecording(), im = await p.toImage(144, 144);
      p.dispose();
      hashes.add(Object.hashAll((await im.toByteData())!.buffer.asUint8List()));
      im.dispose();
    }
    expect(hashes, hasLength(4));
    shader.dispose();
    texture.dispose();
  });
  test(
    'road shoulders fade continuously into grass, including their endpoints',
    () async {
      final world = AdventureWorld();
      final landscape = FieldLandscape(world);
      final r = PictureRecorder();
      Canvas(r).drawColor(const Color(0xffa58c5f), BlendMode.src);
      final p = r.endRecording(), texture = await p.toImage(2, 2);
      p.dispose();
      final shader = ImageShader(
        texture,
        TileMode.repeated,
        TileMode.repeated,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      );
      final recorder = PictureRecorder();
      landscape.paintRoadTransition(
        Canvas(recorder),
        Trail([const Offset(100, 100), const Offset(300, 100)], 100),
        shader,
      );
      final pic = recorder.endRecording(), im = await pic.toImage(400, 220);
      pic.dispose();
      final bytes = (await im.toByteData())!.buffer.asUint8List();
      int alpha(int x, int y) => bytes[(y * 400 + x) * 4 + 3];
      expect(alpha(200, 130), greaterThan(alpha(200, 150)));
      expect(alpha(200, 150), greaterThan(alpha(200, 168)));
      expect(alpha(200, 178), 0);
      expect(alpha(50, 100), greaterThan(0));
      expect(alpha(20, 100), 0);
      im.dispose();
      shader.dispose();
      texture.dispose();
    },
  );
}

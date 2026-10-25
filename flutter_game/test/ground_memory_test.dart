import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all twelve ground shaders still paint after the large source atlases are released',
    () async {
      final art = await GameArt.load();
      addTearDown(() {
        for (final shader in art.materials) {
          shader.dispose();
        }
        for (final image in art.images.values) {
          image.dispose();
        }
      });
      expect(art.images.containsKey('terrain-materials'), false);
      expect(art.images.containsKey('stage-materials'), false);
      expect(art.images.containsKey('village-scene'), true);
      expect(art.materials.length, 12);
      final textures = <int>{};
      for (final shader in art.materials) {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawRect(
          const ui.Rect.fromLTWH(0, 0, 192, 192),
          ui.Paint()
            ..shader = shader
            ..filterQuality = ui.FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(192, 192);
        picture.dispose();
        final raw = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final bytes = raw.buffer.asUint8List();
        var covered = 0;
        for (var i = 3; i < bytes.length; i += 4) {
          if (bytes[i] > 200) covered++;
        }
        expect(
          covered,
          greaterThan(192 * 192 * .95),
          reason: 'a released source must not blank a retained ground shader',
        );
        textures.add(Object.hashAll(bytes));
        image.dispose();
      }
      expect(
        textures.length,
        12,
        reason:
            'forest, water, sand, ruins, city and their roads retain distinct textures',
      );
    },
  );
}

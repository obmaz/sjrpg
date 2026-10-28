import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/village_scene_blend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'organic join preserves the market and central path without a rectangular translucent strip',
    () async {
      final sourceRecorder = ui.PictureRecorder();
      ui.Canvas(
        sourceRecorder,
      ).drawColor(const ui.Color(0xffcead74), ui.BlendMode.src);
      final sourcePicture = sourceRecorder.endRecording(),
          source = await sourcePicture.toImage(640, 960);
      sourcePicture.dispose();
      final recorder = ui.PictureRecorder();
      paintVillageSceneBlend(
        ui.Canvas(recorder),
        source,
        const ui.Rect.fromLTWH(0, 0, 640, 960),
      );
      final picture = recorder.endRecording(),
          image = await picture.toImage(640, 960);
      picture.dispose();
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        int alpha(int x, int y) => bytes[(y * 640 + x) * 4 + 3];
        expect(alpha(320, 480), 255);
        expect(
          alpha(605, 280),
          greaterThan(235),
          reason: 'market posts must not ghost against larger courtyard stones',
        );
        expect(
          alpha(620, 280),
          greaterThan(alpha(620, 750) + 10),
          reason:
              'the edge follows the scene rather than one vertical opacity ramp',
        );
        expect(
          alpha(320, 945),
          lessThan(5),
          reason: 'southern lane blends broadly into its real approach',
        );
        for (final y in [10, 150, 400, 700, 940]) {
          expect(alpha(0, y), lessThanOrEqualTo(1));
          expect(alpha(639, y), lessThanOrEqualTo(5));
        }
      } finally {
        image.dispose();
        source.dispose();
      }
    },
  );
}

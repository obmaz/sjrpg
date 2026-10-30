import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'generated framed buttons are distinct, centered and fully visible',
    () async {
      final bytes = await rootBundle.load(
        'assets/images/reference-battle-buttons.webp',
      );
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final source = (await codec.getNextFrame()).image;
      codec.dispose();
      final art = GameArt()..images['reference-battle-buttons'] = source;
      addTearDown(art.dispose);
      final fingerprints = <int>{};
      for (var index = 0; index < 4; index++) {
        final recorder = ui.PictureRecorder();
        ReferenceBattleButtonPainter(
          art,
          index,
        ).paint(ui.Canvas(recorder), const ui.Size(80, 80));
        final picture = recorder.endRecording();
        final image = await picture.toImage(80, 80);
        picture.dispose();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var left = 80, right = 0, top = 80, bottom = 0;
        for (var y = 0; y < 80; y++) {
          for (var x = 0; x < 80; x++) {
            if (data[(y * 80 + x) * 4 + 3] > 128) {
              left = math.min(left, x);
              right = math.max(right, x);
              top = math.min(top, y);
              bottom = math.max(bottom, y);
            }
          }
        }
        expect(right - left, greaterThanOrEqualTo(75));
        expect(bottom - top, greaterThanOrEqualTo(75));
        expect((left + right) / 2, closeTo(39.5, 1));
        expect((top + bottom) / 2, closeTo(39.5, 1));
        fingerprints.add(Object.hashAll(data));
        image.dispose();
      }
      expect(fingerprints, hasLength(4));
    },
  );
}

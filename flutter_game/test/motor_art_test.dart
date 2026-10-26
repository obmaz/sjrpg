import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'motorcycle has 16 complete, distinct renders without cropped wheel edges',
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
      final source = art.images['actors-motor']!;
      final sourceData = (await source.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final frames = art.actors['motor']['frames'] as List;
      expect(frames.length, 16);
      final unique = <int>{};
      for (var direction = 0; direction < 8; direction++) {
        for (var phase = 0; phase < 2; phase++) {
          final frame = (frames[direction * 2 + phase] as List).cast<num>();
          final x = frame[0].toInt(),
              y = frame[1].toInt(),
              width = frame[2].toInt(),
              height = frame[3].toInt();
          int alpha(int px, int py) =>
              sourceData.getUint8((py * source.width + px) * 4 + 3);
          for (var px = x; px < x + width; px++) {
            expect(alpha(px, y), lessThanOrEqualTo(40));
            expect(alpha(px, y + height - 1), lessThanOrEqualTo(40));
          }
          for (var py = y; py < y + height; py++) {
            expect(alpha(x, py), lessThanOrEqualTo(40));
            expect(alpha(x + width - 1, py), lessThanOrEqualTo(40));
          }
          final recorder = ui.PictureRecorder();
          art.actor(
            ui.Canvas(recorder),
            'motor',
            const ui.Offset(100, 140),
            math.pi / 2 + direction * math.pi / 4,
            phase,
            88,
          );
          final picture = recorder.endRecording(),
              image = await picture.toImage(200, 160);
          picture.dispose();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          unique.add(Object.hashAll(bytes));
          expect(
            [
              for (var i = 3; i < bytes.length; i += 4)
                if (bytes[i] > 40) i,
            ].length,
            greaterThan(1000),
          );
          image.dispose();
        }
      }
      expect(unique.length, 16);
    },
  );
}

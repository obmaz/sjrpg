import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'both future guards render eight unique bearings and eight gait frames without neighboring-cell leakage',
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
      for (final kind in ['cyber', 'gunner']) {
        final frames = art.actors['walk-$kind']['frames'] as List;
        expect(frames.length, 128);
        final unique = <int>{};
        for (var direction = 0; direction < 8; direction++) {
          for (var phase = 0; phase < 8; phase++) {
            final index = direction * 8 + phase, f = frames[index] as List;
            final sheet = art.images['actors-walk-$kind']!;
            expect(f[0], greaterThanOrEqualTo(4));
            expect(f[1], greaterThanOrEqualTo(4));
            expect(
              (f[0] as num) + (f[2] as num),
              lessThanOrEqualTo(sheet.width - 4),
            );
            expect(
              (f[1] as num) + (f[3] as num),
              lessThanOrEqualTo(sheet.height - 4),
            );
            final recorder = ui.PictureRecorder();
            art.actor(
              ui.Canvas(recorder),
              kind,
              const ui.Offset(64, 110),
              math.pi / 2 + direction * math.pi / 4,
              phase,
              88,
            );
            final picture = recorder.endRecording();
            final image = await picture.toImage(128, 128);
            picture.dispose();
            final raw = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final bytes = raw.buffer.asUint8List();
            var opaque = 0;
            for (var i = 3; i < bytes.length; i += 4) {
              if (bytes[i] > 20) opaque++;
            }
            expect(opaque, greaterThan(500));
            unique.add(Object.hashAll(bytes));
            image.dispose();
          }
        }
        expect(
          unique.length,
          64,
          reason: 'all bearings and gait phases must select their own image',
        );
      }
    },
  );
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'repaired hero swings and complete bicycle wheels render every direction and phase',
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
      for (final key in ['hero', 'hero-attack', 'bicycle']) {
        final count = key == 'bicycle' ? 8 : 16;
        final data = art.actors[key];
        expect(data['frames'].length, count * 2);
        expect(data['feet'].length, count * 2);
        final hashes = <int>{};
        for (var direction = 0; direction < count; direction++) {
          for (var phase = 0; phase < 2; phase++) {
            final rec = ui.PictureRecorder();
            art.actor(
              ui.Canvas(rec),
              key == 'hero-attack' ? 'hero' : key,
              const ui.Offset(100, 150),
              math.pi / 2 + direction * math.pi * 2 / count,
              phase,
              100,
              attack: key == 'hero-attack',
            );
            final picture = rec.endRecording();
            final image = await picture.toImage(200, 180);
            picture.dispose();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            var opaque = 0;
            for (var y = 0; y < 180; y++) {
              for (var x = 0; x < 200; x++) {
                final alpha = bytes[(y * 200 + x) * 4 + 3];
                if (alpha > 20) {
                  opaque++;
                  expect(x, inInclusiveRange(2, 197));
                  expect(y, inInclusiveRange(2, 177));
                }
              }
            }
            expect(opaque, greaterThan(1000));
            hashes.add(Object.hashAll(bytes));
            image.dispose();
          }
        }
        expect(hashes.length, count * 2);
      }
    },
  );
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'hero idle, eight run poses, swings and complete bicycle wheels render every direction',
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
      for (final key in [
        'hero',
        'hero-attack',
        'hero-backhand',
        'hero-cleave',
        'mage-cast',
        'bicycle',
      ]) {
        final count = key == 'bicycle' ? 8 : 16;
        final movement = key == 'hero';
        final action = !movement && key != 'bicycle';
        final phases = movement
            ? 9
            : action
            ? 8
            : 2;
        final data = art.actors[key];
        expect(data['frames'].length, count * phases);
        expect(data['feet'].length, count * phases);
        if (movement) {
          expect(data['motion']['runFrames'], 8);
          expect(data['motion']['idleOffset'], 0);
          expect(data['motion']['runOffset'], 16);
        }
        if (action) {
          expect(data['action']['frames'], 8);
          expect(data['action']['directions'], 16);
        }
        final hashes = <int>{};
        // Leave room for the larger native bodies and their extended sword poses.
        const width = 512, height = 480;
        for (var direction = 0; direction < count; direction++) {
          for (var phase = 0; phase < phases; phase++) {
            final rec = ui.PictureRecorder();
            art.actor(
              ui.Canvas(rec),
              key.startsWith('hero-')
                  ? 'hero'
                  : key == 'mage-cast'
                  ? 'mage'
                  : key,
              const ui.Offset(256, 380),
              math.pi / 2 + direction * math.pi * 2 / count,
              movement ? math.max(0, phase - 1) : phase,
              100,
              moving: movement && phase > 0,
              attack: action,
              actionProgress: action ? phase / (phases - 1) : null,
              comboPose: key == 'hero-backhand'
                  ? 1
                  : key == 'hero-cleave'
                  ? 2
                  : 0,
            );
            final picture = rec.endRecording();
            final image = await picture.toImage(width, height);
            picture.dispose();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            var opaque = 0;
            for (var y = 0; y < height; y++) {
              for (var x = 0; x < width; x++) {
                final alpha = bytes[(y * width + x) * 4 + 3];
                if (alpha > 20) {
                  opaque++;
                  expect(x, inInclusiveRange(2, width - 3));
                  expect(y, inInclusiveRange(2, height - 3));
                }
              }
            }
            expect(opaque, greaterThan(1000));
            hashes.add(Object.hashAll(bytes));
            image.dispose();
          }
        }
        expect(hashes.length, count * phases);
      }
    },
  );
}

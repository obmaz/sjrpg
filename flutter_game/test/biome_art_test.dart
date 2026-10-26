import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'four biome creatures render eight complete bearings and two distinct gait frames',
    () async {
      final art = await GameArt.load();
      addTearDown(() {
        for (final shader in art.materials) {
          shader.dispose();
        }
        for (final im in art.images.values) {
          im.dispose();
        }
      });
      for (final kind in ['boar', 'basilisk', 'wraith', 'drone']) {
        expect(art.actors[kind]['frames'].length, 16);
        final hashes = <int>{};
        for (var d = 0; d < 8; d++) {
          for (var phase = 0; phase < 2; phase++) {
            final rec = ui.PictureRecorder();
            art.actor(
              ui.Canvas(rec),
              kind,
              const ui.Offset(125, 160),
              math.pi / 2 + d * math.pi / 4,
              phase,
              80,
            );
            final picture = rec.endRecording(),
                im = await picture.toImage(250, 180);
            picture.dispose();
            final bytes = (await im.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            var visible = 0;
            for (var y = 0; y < 180; y++) {
              for (var x = 0; x < 250; x++) {
                if (bytes[(y * 250 + x) * 4 + 3] > 20) {
                  visible++;
                  expect(x, inInclusiveRange(2, 247));
                  expect(y, inInclusiveRange(2, 177));
                }
              }
            }
            expect(visible, greaterThan(700));
            hashes.add(Object.hashAll(bytes));
            im.dispose();
          }
        }
        expect(hashes.length, 16);
      }
    },
  );
}

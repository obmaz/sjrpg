import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt art;
  late ui.Image source;
  setUp(() async {
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(4, 2, 4, 10),
      ui.Paint()..color = const ui.Color(0xffff0000),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(8, 2, 4, 10),
      ui.Paint()..color = const ui.Color(0xff0000ff),
    );
    final picture = recorder.endRecording();
    source = await picture.toImage(32, 16);
    picture.dispose();
    art = GameArt()
      ..actors = {
        'hero': {
          'frames': List.filled(32, [2, 1, 14, 14]),
          'sizes': [
            [14, 14],
          ],
          'feet': List.filled(32, [7, 11]),
          'mirrors': List.generate(32, (index) => index == 1),
        },
        'roll': {
          'frames': List.filled(64, [2, 1, 14, 14]),
          'sizes': [
            [14, 14],
            [14, 14],
          ],
        },
      };
    art.images['actors-hero'] = source;
    art.images['actors-roll'] = source;
  });
  tearDown(() => source.dispose());

  Future<Uint8List> raster(void Function(ui.Canvas) paint) async {
    final recorder = ui.PictureRecorder();
    paint(ui.Canvas(recorder));
    final picture = recorder.endRecording(),
        image = await picture.toImage(256, 64);
    picture.dispose();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    image.dispose();
    return bytes;
  }

  List<int> pixel(Uint8List bytes, int x, int y) =>
      bytes.sublist((y * 256 + x) * 4, (y * 256 + x) * 4 + 4);

  test(
    'cropped feet stay anchored and mirroring flips about those feet',
    () async {
      final bytes = await raster((canvas) {
        art.actor(canvas, 'hero', const ui.Offset(40, 40), math.pi / 2, 0, 28);
        art.actor(
          canvas,
          'hero',
          const ui.Offset(100, 40),
          math.pi / 2 + math.pi / 8,
          0,
          28,
        );
      });
      expect(pixel(bytes, 36, 28), [255, 0, 0, 255]);
      expect(pixel(bytes, 46, 28), [0, 0, 255, 255]);
      expect(pixel(bytes, 94, 28), [0, 0, 255, 255]);
      expect(pixel(bytes, 104, 28), [255, 0, 0, 255]);
      expect(pixel(bytes, 28, 28).last, 0);
      expect(pixel(bytes, 58, 28).last, 0);
    },
  );

  test(
    'slimmer warrior preserves the larger height and ground anchor',
    () async {
      Future<Uint8List> body({bool originalWidth = false}) => raster((canvas) {
        if (originalWidth) {
          canvas.translate(40, 0);
          canvas.scale(1.36 / GameArt.warriorWidthScale, 1);
          canvas.translate(-40, 0);
        }
        art.actor(canvas, 'hero', const ui.Offset(40, 40), math.pi / 2, 0, 28);
      });
      final current = await body(), previous = await body(originalWidth: true);
      double mass(Uint8List bytes) {
        var alpha = 0.0;
        for (var i = 3; i < bytes.length; i += 4) {
          alpha += bytes[i] / 255;
        }
        return alpha;
      }

      expect(mass(current) / mass(previous), inInclusiveRange(.75, .84));
      final rows = <int>{};
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 80; x++) {
          if (pixel(current, x, y).last >= 128) rows.add(y);
        }
      }
      expect(
        rows.length,
        23,
        reason: '18% taller presentation keeps the same ground anchor',
      );
      expect(
        pixel(current, 40, 40),
        pixel(previous, 40, 40),
        reason: 'feet keep the same ground anchor',
      );
    },
  );

  test('fading and hit flash never leak into the next actor', () async {
    final bytes = await raster((canvas) {
      art.actor(
        canvas,
        'hero',
        const ui.Offset(40, 40),
        math.pi / 2,
        0,
        28,
        opacity: .25,
        flash: 1,
      );
      art.actor(canvas, 'hero', const ui.Offset(100, 40), math.pi / 2, 0, 28);
      art.actor(
        canvas,
        'hero',
        const ui.Offset(160, 40),
        math.pi / 2,
        0,
        28,
        opacity: 0,
      );
      art.actor(canvas, 'hero', const ui.Offset(220, 40), math.pi / 2, 0, 28);
    });
    expect(pixel(bytes, 36, 28).last, closeTo(64, 1));
    expect(pixel(bytes, 36, 28)[2], greaterThan(40));
    expect(pixel(bytes, 94, 28), [255, 0, 0, 255]);
    expect(pixel(bytes, 106, 28), [0, 0, 255, 255]);
    expect(pixel(bytes, 156, 28).last, 0);
    expect(pixel(bytes, 216, 28), [255, 0, 0, 255]);
  });

  test(
    'rolling stays opaque after a flashed actor and preserves later actors',
    () async {
      final bytes = await raster((canvas) {
        art.actor(
          canvas,
          'hero',
          const ui.Offset(40, 40),
          math.pi / 2,
          0,
          28,
          opacity: .4,
          flash: .9,
        );
        art.roll(canvas, const ui.Offset(100, 50), math.pi / 2, 0, mage: false);
        art.actor(canvas, 'hero', const ui.Offset(160, 40), math.pi / 2, 0, 28);
      });
      expect(pixel(bytes, 90, 25), [255, 0, 0, 255]);
      expect(pixel(bytes, 103, 25), [0, 0, 255, 255]);
      expect(pixel(bytes, 156, 28), [255, 0, 0, 255]);
      expect(pixel(bytes, 166, 28), [0, 0, 255, 255]);
    },
  );
}

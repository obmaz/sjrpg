import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/ground_texture.dart';

Future<ui.Image> recordImage(
  int width,
  int height,
  void Function(ui.Canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'paving keeps interior stone detail while blending only opposite borders',
    () async {
      final source = await recordImage(256, 256, (c) {
        c.drawRect(
          const ui.Rect.fromLTWH(0, 0, 256, 256),
          ui.Paint()
            ..shader = ui.Gradient.linear(
              ui.Offset.zero,
              const ui.Offset(256, 256),
              [const ui.Color(0xffff2000), const ui.Color(0xff0020ff)],
            ),
        );
        c.drawRect(
          const ui.Rect.fromLTWH(100, 110, 28, 30),
          ui.Paint()..color = const ui.Color(0xffffdd33),
        );
      });
      addTearDown(source.dispose);
      final tile = await recordImage(
        256,
        256,
        (c) => paintSeamlessGround(
          c,
          source,
          const ui.Rect.fromLTWH(0, 0, 256, 256),
          256,
          preserveCenter: true,
        ),
      );
      addTearDown(tile.dispose);
      final before = (await source.toByteData())!,
          after = (await tile.toByteData())!;
      for (var y = 32; y < 224; y += 9) {
        for (var x = 32; x < 224; x += 9) {
          for (var c = 0; c < 4; c++) {
            final at = (y * 256 + x) * 4 + c;
            expect(after.getUint8(at), before.getUint8(at));
          }
        }
      }
      for (var c = 0; c < 3; c++) {
        int at(int x, int y) => after.getUint8((y * 256 + x) * 4 + c);
        expect((at(0, 128) - at(255, 128)).abs(), lessThan(15));
        expect((at(128, 0) - at(128, 255)).abs(), lessThan(15));
      }
    },
  );
  test(
    'natural material blending removes an abrupt opposite-edge lighting seam in both axes',
    () async {
      final source = await recordImage(
        64,
        64,
        (c) => c.drawRect(
          const ui.Rect.fromLTWH(0, 0, 64, 64),
          ui.Paint()
            ..shader = ui.Gradient.linear(
              ui.Offset.zero,
              const ui.Offset(64, 64),
              [const ui.Color(0xffff2000), const ui.Color(0xff0020ff)],
            ),
        ),
      );
      addTearDown(source.dispose);
      final tile = await recordImage(
        64,
        64,
        (c) => paintSeamlessGround(
          c,
          source,
          const ui.Rect.fromLTWH(0, 0, 64, 64),
          64,
        ),
      );
      addTearDown(tile.dispose);
      final raw = (await tile.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int value(int x, int y, int channel) =>
          raw.getUint8((y * 64 + x) * 4 + channel);
      for (var i = 0; i < 64; i++) {
        for (var channel = 0; channel < 3; channel++) {
          expect(
            (value(0, i, channel) - value(63, i, channel)).abs(),
            lessThanOrEqualTo(6),
          );
          expect(
            (value(i, 0, channel) - value(i, 63, channel)).abs(),
            lessThanOrEqualTo(6),
          );
        }
      }
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          expect(value(x, y, 3), greaterThanOrEqualTo(252));
        }
      }
    },
  );
  test(
    'seam blending samples only the chosen atlas material and keeps it opaque',
    () async {
      final source = await recordImage(128, 64, (c) {
        c.drawPaint(ui.Paint()..color = const ui.Color(0xffee00ff));
        c.drawRect(
          const ui.Rect.fromLTWH(0, 0, 64, 64),
          ui.Paint()..color = const ui.Color(0xff2f8c40),
        );
      });
      addTearDown(source.dispose);
      final tile = await recordImage(
        64,
        64,
        (c) => paintSeamlessGround(
          c,
          source,
          const ui.Rect.fromLTWH(4, 4, 56, 56),
          64,
        ),
      );
      addTearDown(tile.dispose);
      final raw = (await tile.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      for (var i = 0; i < 64 * 64; i++) {
        expect(raw.getUint8(i * 4), lessThan(90));
        expect(raw.getUint8(i * 4 + 1), greaterThan(110));
        expect(raw.getUint8(i * 4 + 2), lessThan(100));
        expect(raw.getUint8(i * 4 + 3), greaterThanOrEqualTo(252));
      }
    },
  );
}

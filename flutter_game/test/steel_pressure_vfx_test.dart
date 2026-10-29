import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/steel_pressure_vfx.dart';

const _side = 320;
const _center = ui.Offset(160, 180);

Future<Uint8List> _frame(void Function(ui.Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(_side, _side);
  picture.dispose();
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return Uint8List.fromList(data.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all physical planes stay bounded and leave the torso readable',
    () async {
      final art = SteelPressureArt();
      final bounds = art.bounds(_center, 92);
      for (var mode = 0; mode < 3; mode++) {
        for (final progress in [0.0, .2, .55, .9]) {
          for (final bearing in [0.0, 1.57, 3.14, -1.57]) {
            final bytes = await _frame((canvas) {
              switch (mode) {
                case 0:
                  art.paintWhirlwind(
                    canvas,
                    center: _center,
                    radius: 92,
                    progress: progress,
                    bearing: bearing,
                    rank: 20,
                  );
                case 1:
                  art.paintStrike(
                    canvas,
                    center: _center,
                    radius: 92,
                    progress: progress,
                    bearing: bearing,
                    rank: 20,
                    heavy: true,
                    fierce: true,
                    dual: true,
                  );
                case 2:
                  art.paintWave(
                    canvas,
                    center: _center,
                    radius: 92,
                    progress: progress,
                    bearing: bearing,
                    rank: 20,
                  );
              }
            });
            var visible = 0;
            for (var y = 0; y < _side; y++) {
              for (var x = 0; x < _side; x++) {
                if (bytes[(y * _side + x) * 4 + 3] == 0) continue;
                visible++;
                expect(
                  bounds.contains(ui.Offset(x + .5, y + .5)),
                  isTrue,
                  reason: 'mode $mode phase $progress bounds at $x,$y',
                );
                expect(
                  x >= 151 && x < 169 && y >= 132 && y < 164,
                  isFalse,
                  reason: 'mode $mode phase $progress obscures torso',
                );
              }
            }
            expect(visible, lessThan(8500), reason: 'open ribbons, not fog');
          }
        }
      }
    },
  );

  test(
    'warm broad steel moves over time and skill rank remains capped',
    () async {
      final art = SteelPressureArt();
      Future<Uint8List> whirlwind(double t, int rank) => _frame(
        (c) => art.paintWhirlwind(
          c,
          center: _center,
          radius: 92,
          progress: t,
          rank: rank,
        ),
      );
      final early = await whirlwind(.12, 5);
      final middle = await whirlwind(.43, 5);
      expect(early, isNot(orderedEquals(middle)));
      var warm = 0, visible = 0;
      for (var i = 0; i < early.length; i += 4) {
        if (early[i + 3] > 50) visible++;
        if (early[i] > 150 &&
            early[i + 1] > 80 &&
            early[i + 2] < 170 &&
            early[i + 3] > 70) {
          warm++;
        }
      }
      expect(visible, greaterThan(1000), reason: 'substantial blade ribbons');
      expect(warm, greaterThan(200), reason: 'readable warm metal light');
      expect(await whirlwind(.2, 20), orderedEquals(await whirlwind(.2, 999)));
    },
  );

  test(
    'heated sweep keeps a red edge and a clear open center as its tip moves',
    () async {
      final art = SteelPressureArt();
      final early = await _frame(
        (c) => art.paintWhirlwind(
          c,
          center: _center,
          radius: 116,
          progress: .18,
          rank: 12,
        ),
      );
      final late = await _frame(
        (c) => art.paintWhirlwind(
          c,
          center: _center,
          radius: 116,
          progress: .47,
          rank: 12,
        ),
      );
      var hotEdge = 0, nearCore = 0;
      for (var y = 0; y < _side; y++) {
        for (var x = 0; x < _side; x++) {
          final i = (y * _side + x) * 4;
          if (early[i + 3] > 50 &&
              early[i] > 170 &&
              early[i] > early[i + 1] * 1.5 &&
              early[i + 2] < 100) {
            hotEdge++;
          }
          if (x >= 142 && x < 178 && y >= 106 && y < 171 && early[i + 3] > 0) {
            nearCore++;
          }
        }
      }
      expect(
        hotEdge,
        greaterThan(100),
        reason: 'the edge is ember-red instead of uniformly pale',
      );
      expect(
        nearCore,
        0,
        reason: 'head and torso stay visible inside the broad sweep',
      );
      expect(
        early,
        isNot(orderedEquals(late)),
        reason: 'the blade and its torn edge advance with simulation time',
      );
    },
  );

  test(
    'behind-actor sweep stays continuous through the former rectangular mask',
    () async {
      final art = SteelPressureArt();
      Future<Uint8List> draw(bool protect) => _frame(
        (c) => art.paintWhirlwind(
          c,
          center: _center,
          radius: 116,
          progress: .47,
          rank: 12,
          protectBody: protect,
        ),
      );
      final standalone = await draw(true), behindActor = await draw(false);
      var protectedPixels = 0, continuousPixels = 0;
      for (var y = 109; y < 130; y++) {
        for (var x = 147; x < 173; x++) {
          final i = (y * _side + x) * 4 + 3;
          if (standalone[i] > 0) protectedPixels++;
          if (behindActor[i] > 0) continuousPixels++;
        }
      }
      expect(
        protectedPixels,
        0,
        reason: 'standalone effects still protect a foreground actor',
      );
      expect(
        continuousPixels,
        greaterThan(30),
        reason: 'the layer behind an actor has no rectangular gap',
      );
    },
  );

  test(
    'expired frames paint nothing and canvas transform/clip is restored',
    () async {
      final art = SteelPressureArt();
      for (final t in [-.1, 1.0, double.nan]) {
        final empty = await _frame((c) => art.paintWhirlwind(c, progress: t));
        expect(empty.every((b) => b == 0), isTrue);
      }
      final frame = await _frame((c) {
        art.paintStrike(c, center: _center, progress: .3, heavy: true);
        c.drawRect(
          const ui.Rect.fromLTWH(2, 2, 4, 4),
          ui.Paint()..color = const ui.Color(0xff00ff00),
        );
      });
      expect(frame[(_side * 3 + 3) * 4 + 1], 255);
      expect(frame[(_side * 3 + 3) * 4 + 3], 255);
    },
  );

  test('representative physical effects preview', () async {
    final art = SteelPressureArt();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xff1b2525), ui.BlendMode.src);
    const centers = [
      ui.Offset(170, 180),
      ui.Offset(490, 180),
      ui.Offset(810, 180),
    ];
    for (final center in centers) {
      canvas.drawOval(
        ui.Rect.fromCenter(center: center, width: 44, height: 18),
        ui.Paint()..color = const ui.Color(0xff101818),
      );
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(center.dx - 14, center.dy - 54, 28, 44),
          const ui.Radius.circular(8),
        ),
        ui.Paint()..color = const ui.Color(0xff52726c),
      );
    }
    art.paintWhirlwind(
      canvas,
      center: centers[0],
      radius: 120,
      progress: .2,
      rank: 12,
      protectBody: false,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(centers[0].dx - 14, centers[0].dy - 54, 28, 44),
        const ui.Radius.circular(8),
      ),
      ui.Paint()..color = const ui.Color(0xff52726c),
    );
    art.paintStrike(
      canvas,
      center: centers[1],
      radius: 120,
      progress: .38,
      rank: 12,
      heavy: true,
      dual: true,
    );
    art.paintWave(
      canvas,
      center: centers[2],
      radius: 120,
      progress: .3,
      rank: 12,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(980, 320);
    picture.dispose();
    final output = await Directory.systemTemp.createTemp('steel-pressure-vfx-');
    try {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File('${output.path}/preview.png');
      await file.writeAsBytes(png.buffer.asUint8List());
      final proof = Platform.environment['SJRPG_STEEL_PROOF_DIR'];
      if (proof != null) {
        await Directory(proof).create(recursive: true);
        await File(
          '$proof/physical-effects.png',
        ).writeAsBytes(png.buffer.asUint8List());
      }
      expect(await file.length(), greaterThan(1000));
    } finally {
      await output.delete(recursive: true);
      image.dispose();
    }
  });
}

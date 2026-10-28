import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/barbarian_vfx.dart';

const _side = 320;
const _center = ui.Offset(160, 180);

Future<({ui.Image image, Uint8List bytes})> _raster(
  void Function(ui.Canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(_side, _side);
  picture.dispose();
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return (
    image: image,
    bytes: Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every moving skill stays inside cull bounds and leaves the torso clear',
    () async {
      for (final kind in BarbarianVfxKind.values) {
        final art = BarbarianVfxArt(kind);
        var maximumVisible = 0;
        for (final t in [0.0, .15, .35, .6, .85, .98]) {
          for (final bearing in [0.0, 1.57, 3.14, -1.57]) {
            final frame = await _raster(
              (c) => art.paint(
                c,
                progress: t,
                center: _center,
                radius: 92,
                bearing: bearing,
                rank: 20,
              ),
            );
            try {
              var visible = 0;
              final bounds = art.bounds(_center, 92);
              for (var y = 0; y < _side; y++) {
                for (var x = 0; x < _side; x++) {
                  final alpha = frame.bytes[(y * _side + x) * 4 + 3];
                  if (alpha == 0) continue;
                  visible++;
                  expect(
                    bounds.contains(ui.Offset(x + .5, y + .5)),
                    isTrue,
                    reason: '${kind.name} t=$t bearing=$bearing pixel($x,$y)',
                  );
                  if (x >= 151 && x < 169 && y >= 132 && y < 164) {
                    fail('${kind.name} obscures the central torso at $x,$y');
                  }
                }
              }
              if (visible > maximumVisible) maximumVisible = visible;
              expect(
                visible,
                lessThan(6000),
                reason: '${kind.name} remains a sparse edge effect',
              );
            } finally {
              frame.image.dispose();
            }
          }
        }
        expect(
          maximumVisible,
          greaterThan(20),
          reason: '${kind.name} is readable',
        );
      }
    },
  );

  test('shout tones and physical combat silhouettes remain distinct', () async {
    final images = <ui.Image>[];
    final hashes = <BarbarianVfxKind, int>{};
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xff243429), ui.BlendMode.src);
    try {
      for (var i = 0; i < BarbarianVfxKind.values.length; i++) {
        final kind = BarbarianVfxKind.values[i];
        final frame = await _raster(
          (c) => BarbarianVfxArt(kind).paint(
            c,
            progress:
                kind == BarbarianVfxKind.leap ||
                    kind == BarbarianVfxKind.leapAttack
                ? .84
                : .25,
            center: _center,
            radius: 92,
            rank: 5,
          ),
        );
        images.add(frame.image);
        var hash = 0;
        for (final b in frame.bytes) {
          hash = ((hash * 31) + b) & 0x3fffffff;
        }
        hashes[kind] = hash;
        canvas.save();
        canvas.translate((i % 5) * 160.0, (i ~/ 5) * 160.0);
        canvas.scale(.5);
        canvas.drawImage(frame.image, ui.Offset.zero, ui.Paint());
        canvas.restore();
      }
      expect(
        hashes.values.toSet().length,
        BarbarianVfxKind.values.length,
        reason: 'shouts use distinct colors/waves and attacks distinct edges',
      );
      final picture = recorder.endRecording();
      try {
        final export = Platform.environment['BARBARIAN_VFX_EXPORT'];
        if (export != null) {
          final image = await picture.toImage(800, 640);
          try {
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(export).writeAsBytes(png.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        }
      } finally {
        picture.dispose();
      }
    } finally {
      for (final image in images) {
        image.dispose();
      }
    }
  });

  test('leaps raise only the art and keep a shrinking ground shadow', () async {
    for (final kind in [BarbarianVfxKind.leap, BarbarianVfxKind.leapAttack]) {
      final art = BarbarianVfxArt(kind);
      expect(barbarianAirborneHeight(kind, 0), 0);
      expect(barbarianAirborneHeight(kind, 1), 0);
      expect(barbarianAirborneHeight(kind, .5), greaterThan(40));
      expect(
        barbarianAirborneHeight(kind, .2),
        closeTo(barbarianAirborneHeight(kind, .8), .00001),
      );
      final frames = <Uint8List>[];
      for (final t in [0.0, .5, 1.0]) {
        final frame = await _raster(
          (c) => art.paintAirborneShadow(c, _center, t),
        );
        frames.add(frame.bytes);
        frame.image.dispose();
      }
      int alpha(Uint8List bytes) {
        var total = 0;
        for (var i = 3; i < bytes.length; i += 4) {
          total += bytes[i];
        }
        return total;
      }

      expect(frames.first, orderedEquals(frames.last));
      expect(alpha(frames[1]), lessThan(alpha(frames.first) * .65));
    }
    expect(barbarianAirborneHeight(BarbarianVfxKind.whirlwind, .5), 0);
  });

  test('finished effects disappear and canvas state never leaks', () async {
    for (final kind in BarbarianVfxKind.values) {
      final art = BarbarianVfxArt(kind);
      final empty = await _raster((c) {
        art.paint(c, progress: 1, center: _center);
        art.paint(c, progress: double.nan, center: _center);
      });
      expect(empty.bytes.every((b) => b == 0), isTrue);
      empty.image.dispose();
      final recorder = ui.PictureRecorder();
      final c = ui.Canvas(recorder);
      final count = c.getSaveCount(), clip = c.getLocalClipBounds();
      art.paint(c, progress: .25, center: _center, bearing: .7);
      expect(c.getSaveCount(), count);
      expect(c.getLocalClipBounds(), clip);
      recorder.endRecording().dispose();
    }
  });

  test(
    'axe spin stays at its projectile and contact fragments travel outward',
    () async {
      final art = BarbarianVfxArt(BarbarianVfxKind.doubleThrow);
      for (final t in [0.0, .25, .5, .75]) {
        final frame = await _raster(
          (c) => art.paintThrownAxe(c, _center, 0, t),
        );
        try {
          var visible = 0;
          for (var y = 0; y < _side; y++) {
            for (var x = 0; x < _side; x++) {
              if (frame.bytes[(y * _side + x) * 4 + 3] == 0) continue;
              visible++;
              expect(
                (ui.Offset(x + .5, y + .5) - _center).distance,
                lessThan(18),
                reason: 'spin must not move the projectile',
              );
            }
          }
          expect(visible, greaterThan(40));
        } finally {
          frame.image.dispose();
        }
      }
      final centers = <double>[];
      for (final t in [0.0, .5, 1.0]) {
        final frame = await _raster(
          (c) => art.paintAxeImpact(c, _center, 0, t),
        );
        try {
          var weight = 0.0, xSum = 0.0;
          for (var y = 0; y < _side; y++) {
            for (var x = 0; x < _side; x++) {
              final alpha = frame.bytes[(y * _side + x) * 4 + 3];
              weight += alpha;
              xSum += x * alpha;
            }
          }
          if (t == 1) {
            expect(weight, 0);
          } else {
            expect(weight, greaterThan(0));
            centers.add(xSum / weight);
          }
        } finally {
          frame.image.dispose();
        }
      }
      expect(centers[1], greaterThan(centers[0] + 4));
    },
  );

  test(
    'confirmed landing paints dust on contact and finishes at its footprint',
    () async {
      final art = BarbarianVfxArt(BarbarianVfxKind.leapAttack);
      for (final t in [0.0, .4, 1.0]) {
        final frame = await _raster(
          (c) => art.paintLanding(
            c,
            progress: t,
            center: _center,
            radius: 92,
            heavy: true,
          ),
        );
        try {
          var visible = 0;
          for (var y = 0; y < _side; y++) {
            for (var x = 0; x < _side; x++) {
              if (frame.bytes[(y * _side + x) * 4 + 3] == 0) continue;
              visible++;
              expect(
                art.bounds(_center, 92).contains(ui.Offset(x + .5, y + .5)),
                isTrue,
              );
            }
          }
          expect(
            visible,
            t == 1 ? 0 : greaterThan(30),
            reason: 'landing starts on the hit, without replaying takeoff',
          );
        } finally {
          frame.image.dispose();
        }
      }
    },
  );
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/mount_merchant.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt art;
  setUpAll(() async {
    art = await GameArt.load();
  });
  tearDownAll(() {
    for (final shader in art.materials) {
      shader.dispose();
    }
    for (final image in art.images.values) {
      image.dispose();
    }
  });
  testWidgets('each mount skill uses a centered complete illustrated button', (
    tester,
  ) async {
    final fingerprints = <int>{};
    for (final kind in ['motor', 'horse', 'bicycle', 'boat']) {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: MountSkillBadge(art: art, kind: kind, size: 80, ammo: 27),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage());
      final raw = (await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final bytes = raw.buffer.asUint8List();
      var left = 80, right = 0, top = 80, bottom = 0;
      for (var y = 0; y < 80; y++) {
        for (var x = 0; x < 80; x++) {
          if (bytes[(y * 80 + x) * 4 + 3] > 128) {
            left = math.min(left, x);
            right = math.max(right, x);
            top = math.min(top, y);
            bottom = math.max(bottom, y);
          }
        }
      }
      expect(
        right - left,
        greaterThanOrEqualTo(70),
        reason: '$kind full frame width',
      );
      expect(
        bottom - top,
        greaterThanOrEqualTo(70),
        reason: '$kind full frame height',
      );
      expect((left + right) / 2, closeTo(39.5, 2));
      expect((top + bottom) / 2, closeTo(39.5, 2));
      fingerprints.add(Object.hashAll(bytes));
      image!.dispose();
    }
    expect(fingerprints.length, 4);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final kind in ['motor', 'horse', 'boat']) {
    test(
      '$kind has 16 complete, distinct renders with safe crop edges',
      () async {
        final source = art.images['actors-$kind']!;
        final sourceData = (await source.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final frames = art.actors[kind]['frames'] as List;
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
              kind,
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
}

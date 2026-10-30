import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';

import 'support/test_game.dart';

class _CountingArt extends GameArt {
  final counts = <String>[];
  @override
  void text(
    ui.Canvas canvas,
    String value,
    ui.Offset at, {
    double size = 16,
    ui.Color color = const ui.Color(0xffffedbb),
    bool centered = false,
  }) {
    if (centered) counts.add(value);
    super.text(canvas, value, at, size: size, color: color, centered: centered);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final round in [false, true]) {
    test(
      'small map groups icons as counts without painting beyond its boundary: round=$round',
      () async {
        final art = _CountingArt();
        final session = Adventure(art)..start(TestGame());
        addTearDown(session.dispose);
        addTearDown(art.dispose);
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        final size = round ? const ui.Size(85, 85) : const ui.Size(1200, 900);
        final scale = round ? 1.0 : .2;
        canvas.translate(20, 20);
        canvas.scale(scale);
        MapPainter(
          session,
          round: round,
          markerScale: round ? 1 : 5,
        ).paint(canvas, size);
        final width = (size.width * scale).round(),
            height = (size.height * scale).round();
        final picture = recorder.endRecording(),
            image = await picture.toImage(width + 40, height + 40);
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        for (var y = 0; y < height + 40; y++) {
          for (var x = 0; x < width + 40; x++) {
            if (x >= 20 && x < width + 20 && y >= 20 && y < height + 20) {
              continue;
            }
            expect(
              bytes[((y * (width + 40) + x) * 4) + 3],
              0,
              reason: 'an icon or label escaped the map at $x,$y',
            );
          }
        }
        expect(art.counts, isNotEmpty);
        if (!round) {
          final grouped = art.counts
              .map(int.tryParse)
              .whereType<int>()
              .toList();
          expect(grouped, everyElement(greaterThan(1)));
          expect(
            grouped.fold<int>(0, (sum, count) => sum + count),
            4,
            reason:
                'all four services remain counted around the clear hero marker',
          );
          expect(art.counts, contains('내 위치'));
        }
        image.dispose();
        picture.dispose();
      },
    );
  }
}

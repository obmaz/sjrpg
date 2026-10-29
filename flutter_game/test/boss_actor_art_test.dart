import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/stage_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'each region selects its own boss actor without changing enemy kinds',
    () {
      expect(
        WorldStage.values.map((stage) => stage.bossActor).toSet().length,
        4,
      );
      expect(WorldStage.forest.bossActor, 'golem');
      expect(WorldStage.sands.bossActor, 'sand-warden');
      expect(WorldStage.past.bossActor, 'ancient-king');
      expect(WorldStage.future.bossActor, 'cyber-core');
    },
  );
  test(
    'each themed boss renders eight unique bearings and two gaits without neighboring-cell leakage',
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
      for (final kind in ['sand-warden', 'ancient-king', 'cyber-core']) {
        final frames = art.actors[kind]['frames'] as List;
        expect(frames.length, 16);
        final unique = <int>{};
        for (var direction = 0; direction < 8; direction++) {
          for (var phase = 0; phase < 2; phase++) {
            final index = direction * 2 + phase, f = frames[index] as List;
            final sheet = art.images['actors-cinematic-$kind']!;
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
          16,
          reason: 'all bearings and gait phases must select their own image',
        );
      }
    },
  );
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/mount_sprite_mesh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'mount cadence follows distance and simulation pause, settling on stop',
    () {
      final a = MountMotion(), b = MountMotion();
      a.advance(60, 1);
      for (var i = 0; i < 30; i++) {
        b.advance(2, 1 / 30);
      }
      expect(a.cycle, closeTo(b.cycle, 1e-8));
      expect(a.weight, closeTo(b.weight, 1e-8));
      final cycle = a.cycle, weight = a.weight;
      a.advance(100, 0);
      expect(a.cycle, cycle);
      expect(a.weight, weight);
      a.advance(0, .5);
      expect(a.cycle, cycle);
      expect(a.weight, lessThan(.01));
      a.advance(0, .5, waterOnly: true);
      expect(a.cycle, isNot(cycle));
    },
  );
  test(
    'all four mounts have continuous distinct complete poses in every direction',
    () async {
      final art = await GameArt.load();
      try {
        for (final kind in ['horse', 'motor', 'bicycle', 'boat']) {
          for (var direction = 0; direction < 8; direction++) {
            final hashes = <int>{};
            for (var phase = 0; phase < 8; phase++) {
              final recorder = ui.PictureRecorder();
              art.actor(
                ui.Canvas(recorder),
                kind,
                const ui.Offset(130, 165),
                direction * math.pi / 4,
                0,
                90,
                mountPose: MountVisualPose(
                  kind: kind,
                  stride: phase / 8,
                  weight: 1,
                ),
              );
              final picture = recorder.endRecording(),
                  image = await picture.toImage(260, 180);
              picture.dispose();
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
              hashes.add(Object.hashAll(bytes));
              for (var x = 0; x < 260; x++) {
                expect(bytes[(179 * 260 + x) * 4 + 3], 0);
              }
              image.dispose();
            }
            expect(
              hashes.length,
              greaterThanOrEqualTo(6),
              reason:
                  '$kind direction$direction must articulate, not repeat two stills',
            );
          }
        }
      } finally {
        art.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

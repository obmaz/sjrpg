import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/prop_grounding.dart';
import 'package:guardian_new/world_model.dart';

Future<Uint8List> pixels(void Function(ui.Canvas) draw, int side) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording(),
      image = await picture.toImage(side, side);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return Uint8List.fromList(bytes.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'tree contact is shallow, directed down-right and bounded independently of collision',
    () {
      const tree = WorldProp(
        ui.Rect.fromLTWH(80, 80, 24, 28),
        'tree',
        ui.Size(100, 150),
      );
      final shadow = PropGroundShadow(tree);
      expect(shadow.bounds.center.dx, greaterThan(tree.body.bottomCenter.dx));
      expect(shadow.bounds.center.dy, greaterThan(tree.body.bottom - 3));
      expect(shadow.bounds.height, lessThan(30));
      expect(shadow.color.a, lessThan(.16));
      expect(tree.collisionBodies.single, tree.body);
    },
  );
  test(
    'an open arch keeps the center unshaded between its two real supports',
    () async {
      const arch = WorldProp(
        ui.Rect.fromLTWH(30, 30, 160, 70),
        'ruin-4',
        ui.Size(200, 200),
      );
      final shadow = PropGroundShadow(arch);
      final bytes = await pixels(
        (c) => c.drawPath(shadow.path, ui.Paint()..color = shadow.color),
        256,
      );
      int alpha(int x, int y) => bytes[(y * 256 + x) * 4 + 3];
      expect(alpha(110, 100), 0);
      expect(alpha(45, 100), greaterThan(0));
      expect(alpha(185, 100), greaterThan(0));
      expect(alpha(110, 30), 0);
    },
  );
  test(
    'sector index includes a shadow crossing an edge and excludes distant props',
    () async {
      const near = WorldProp(
        ui.Rect.fromLTWH(495, 470, 24, 30),
        'tree',
        ui.Size(110, 170),
      );
      final all = [
        near,
        const WorldProp(
          ui.Rect.fromLTWH(9000, 9000, 40, 40),
          'rock',
          ui.Size(60, 60),
        ),
      ];
      final grounding = PropGrounding({
        '1:1': [near],
        '35:35': [all.last],
      });
      expect(grounding.candidates(0, 0), 1);
      expect(grounding.candidates(1, 0), 1);
      expect(grounding.candidates(4, 4), 0);
      final direct = await pixels((c) {
        for (final prop in all) {
          final shadow = PropGroundShadow(prop);
          c.drawPath(shadow.path, ui.Paint()..color = shadow.color);
        }
      }, 1024);
      final sectors = await pixels((c) {
        for (var row = 0; row < 2; row++) {
          for (var col = 0; col < 2; col++) {
            c.save();
            c.clipRect(
              ui.Rect.fromLTWH(col * 512, row * 512, 512, 512),
              doAntiAlias: false,
            );
            grounding.paintSector(c, col, row);
            c.restore();
          }
        }
      }, 1024);
      var alphaDifference = 0;
      for (var i = 3; i < direct.length; i += 4) {
        alphaDifference += (sectors[i] - direct[i]).abs();
      }
      // Native ellipse tessellation varies slightly under separate clips.
      // Compare total visible coverage and assert both sides are actually drawn.
      expect(alphaDifference / (1024 * 1024), lessThan(.005));
      expect(sectors[(506 * 1024 + 505) * 4 + 3], greaterThan(0));
      expect(sectors[(506 * 1024 + 525) * 4 + 3], greaterThan(0));
    },
  );
  test(
    'all chapter scenery reuses the existing index and does not alter passability',
    () {
      for (final stage in WorldStage.values) {
        final world = AdventureWorld(stage: stage);
        final probe = ui.Rect.fromCenter(
          center: world.sites.first.at,
          width: 28,
          height: 24,
        );
        final before = world.blocked(probe);
        final watch = Stopwatch()..start();
        final grounding = PropGrounding(world.propBuckets);
        watch.stop();
        final center = world.sites.first.at;
        final candidates = grounding.candidates(
          (center.dx / 512).floor(),
          (center.dy / 512).floor(),
        );
        expect(candidates, lessThan(world.props.length));
        expect(world.blocked(probe), before);
        // Local setup measurement, not a claim of device frame rate.
        // ignore: avoid_print
        print(
          '${stage.name}: ${world.props.length + world.campProps.length} props; shadow setup ${watch.elapsedMicroseconds}us; objective sector $candidates candidates',
        );
      }
    },
  );
}

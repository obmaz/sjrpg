import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final world = AdventureWorld();
  for (final size in [const Size(28, 24), const Size(44, 32)]) {
    for (final entry in world.authoredSettlement.gatePaths.asMap().entries) {
      final name = 'gate-${entry.key}';
      final half = Offset(size.width / 2, size.height / 2);
      final route = world.trails.firstWhere(
        (t) => (t.points.first - entry.value.first).distance < .1,
      );
      test('$name village gate admits a complete $size body', () {
        for (var i = 1; i < route.points.length; i++) {
          final start = route.points[i - 1] - half,
              end = route.points[i] - half;
          expect(world.clearLine(start, end, size), true);
          expect(
            (world.move(start, end - start, size) - end).distance,
            lessThan(.01),
          );
          expect(world.clearLine(end, start, size), true);
        }
      });
    }
  }
  test('fountain and building silhouettes stay solid beside open gates', () {
    for (final polygon in world.settlementCollision.take(5)) {
      expect(
        world.blocked(
          Rect.fromCenter(center: polygon.bounds.center, width: 12, height: 12),
        ),
        true,
      );
    }
  });
}

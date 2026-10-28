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
      final start = entry.value.first - half, end = entry.value.last - half;
      test('$name village gate admits a complete $size body', () {
        expect(world.clearLine(start, end, size), true);
        var current = start;
        final step = (end - start) / 100;
        for (var i = 0; i < 100; i++) {
          current = world.move(current, step, size);
          expect(world.blocked(current & size), false);
        }
        expect((current - end).distance, lessThan(.01));
        expect(world.clearLine(end, start, size), true);
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

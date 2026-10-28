import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  test('the painted west house and market walls stop whole bodies', () {
    final w = AdventureWorld();
    for (final (u, v) in [(0.28, 0.54), (0.73, 0.28)]) {
      final point = Offset(
        town.left + town.width * u,
        town.top + town.height * v,
      );
      expect(
        w.blocked(Rect.fromCenter(center: point, width: 12, height: 12)),
        true,
      );
    }
  });
  test(
    'generated cottages and taller forge have solid walls and free approaches',
    () {
      final w = AdventureWorld();
      final buildings = w.campProps
          .where(
            (p) => p.kind == 'village-cottage' || p.kind == 'blacksmith-forge',
          )
          .toList();
      expect(buildings, hasLength(3));
      for (final building in buildings) {
        expect(w.blocked(building.body.deflate(5)), true);
        const size = Size(40, 32);
        for (final solid in building.collisionBodies) {
          final approach = w.spawnNear(
            solid.bottomCenter + const Offset(-20, 55),
            size,
          );
          expect(approach, isNotNull);
          final goal = solid.center - const Offset(20, 16);
          final end = w.move(approach!, goal - approach, size);
          expect((end & size).overlaps(solid), false);
          expect(w.blocked(end & size), false);
        }
      }
    },
  );
}

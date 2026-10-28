import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  test(
    'complete village buildings have solid silhouettes and free services',
    () {
      final world = AdventureWorld();
      for (final building in world.settlementCollision.take(4)) {
        expect(
          world.blocked(
            Rect.fromCenter(
              center: building.bounds.center,
              width: 12,
              height: 12,
            ),
          ),
          true,
        );
      }
      for (final at in [
        world.merchantAt,
        world.blacksmithAt,
        world.mountMerchantAt,
        world.elderAt,
      ]) {
        final approach = world.spawnNear(
          at - const Offset(20, 16),
          const Size(40, 32),
        );
        expect(approach, isNotNull);
        expect(world.blocked(approach! & const Size(40, 32)), false);
      }
      expect(
        world.campProps.where((p) => world.settlement.overlaps(p.body)),
        isEmpty,
      );
    },
  );
}

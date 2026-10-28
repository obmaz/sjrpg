import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/travel_journal.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  test('revisited arrival hubs retain navigable service anchors', () {
    for (final stage in WorldStage.values) {
      final world = AdventureWorld(stage: stage, hubOrigin: stage.arrival);
      for (final at in [
        world.spawn,
        world.merchantAt,
        world.blacksmithAt,
        world.mountMerchantAt,
      ]) {
        expect(
          world.blocked(Rect.fromCenter(center: at, width: 28, height: 24)),
          false,
          reason: '$stage $at',
        );
        expect(
          world.sanctuary.protects(
            Rect.fromCenter(center: at, width: 28, height: 24),
          ),
          true,
          reason: '$stage revisited service $at must remain protected',
        );
      }
    }
  });
  for (final stage in WorldStage.values) {
    test(
      '${stage.name} scene, services and cardinal gates agree with collision',
      () {
        final world = AdventureWorld(stage: stage);
        expect(world.authoredSettlement.imageKey, 'settlement-${stage.name}');
        // The safety line follows ground-level walls rather than the square
        // illustration or projecting roofs. Full bodies touching its real wall
        // vertices stay protected, and those walls remain solid terrain.
        for (final point in world.authoredSettlement.safeBoundary) {
          final body = Rect.fromCenter(center: point, width: 28, height: 24);
          expect(world.sanctuary.protects(body), true);
          expect(world.blocked(body), true);
        }
        for (final corner in [
          world.settlement.topLeft,
          world.settlement.topRight,
          world.settlement.bottomLeft,
          world.settlement.bottomRight,
        ]) {
          expect(
            world.sanctuary.protects(
              Rect.fromCenter(center: corner, width: 28, height: 24),
            ),
            false,
            reason:
                'outside ground at the image corner is not part of the town',
          );
        }

        final hub = wellSitesForStage(stage, hubOrigin: world.spawn).first;
        expect(hub.at, world.healAt);
        expect(world.wellApproach(hub), world.authoredSettlement.wellApproach);
        expect(world.settlement.size, const Size(1560, 1560));
        final anchors = [
          world.spawn,
          world.merchantAt,
          world.blacksmithAt,
          world.mountMerchantAt,
          world.elderAt,
          world.authoredSettlement.wellApproach,
          for (final path in TimePath.values) world.questGiverAt(path),
        ];
        for (final at in anchors) {
          expect(
            world.sanctuary.protects(
              Rect.fromCenter(center: at, width: 28, height: 24),
            ),
            true,
            reason: '$stage service anchor $at must be inside the painted wall',
          );
          expect(
            world.settlement.contains(at),
            isTrue,
            reason: '$stage anchor $at',
          );
          expect(
            world.blocked(Rect.fromCenter(center: at, width: 28, height: 24)),
            isFalse,
            reason: '$stage anchor $at',
          );
        }
        for (final line in world.authoredSettlement.gatePaths) {
          expect(
            world.sanctuary.protects(
              Rect.fromCenter(center: line.first, width: 30, height: 30),
            ),
            true,
          );
          expect(
            world.sanctuary.protects(
              Rect.fromCenter(center: line.last, width: 30, height: 30),
            ),
            false,
          );
          final steps = ((line.last - line.first).distance / 10).ceil();
          for (var i = 0; i <= steps; i++) {
            final at = Offset.lerp(line.first, line.last, i / steps)!;
            expect(
              world.blocked(Rect.fromCenter(center: at, width: 30, height: 30)),
              isFalse,
              reason: '$stage gate $at',
            );
          }
        }
        for (final polygon in world.settlementCollision.take(4)) {
          expect(
            world.blocked(
              Rect.fromCenter(
                center: polygon.bounds.center,
                width: 10,
                height: 10,
              ),
            ),
            isTrue,
          );
        }
        expect(
          world.campProps.where((p) => world.settlement.overlaps(p.body)),
          isEmpty,
        );
      },
    );
  }
}

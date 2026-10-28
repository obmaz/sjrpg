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
      }
    }
  });
  for (final stage in WorldStage.values) {
    test(
      '${stage.name} scene, services and cardinal gates agree with collision',
      () {
        final world = AdventureWorld(stage: stage);
        expect(world.authoredSettlement.imageKey, 'settlement-${stage.name}');
        // Every painted wall and fence corner belongs to the protected town;
        // otherwise an exposed hero can stand in a pocket enemies cannot enter.
        for (final point in world.settlementCollision.expand(
          (shape) => shape.points,
        )) {
          expect(
            (point - world.sanctuary.center).distance,
            lessThan(world.sanctuary.radius - 24),
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
            world.settlement.contains(at),
            isTrue,
            reason: '$stage anchor $at',
          );
          expect(
            world.blocked(Rect.fromCenter(center: at, width: 24, height: 24)),
            isFalse,
            reason: '$stage anchor $at',
          );
        }
        for (final line in world.authoredSettlement.gatePaths) {
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

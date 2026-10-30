import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stage in WorldStage.values) {
    for (final origin in {stage.spawn, stage.arrival}) {
      test('${stage.name} $origin has four reachable, indexed formations', () {
        for (final seed in [7829, 13, 9351]) {
          final world = AdventureWorld(
            stage: stage,
            hubOrigin: origin,
            seed: seed,
          );
          expect(world.landmarks.length, 4);
          expect(world.landmarks.map((l) => l.index).toSet(), {0, 1, 2, 3});
          final other = AdventureWorld(
            stage: stage,
            hubOrigin: origin,
            seed: seed,
          );
          for (final landmark in world.landmarks) {
            final body = landmark.footprint;
            expect(
              world.blocked(
                Rect.fromCenter(center: body.center, width: 24, height: 22),
              ),
              true,
            );
            expect(
              world.clearLine(
                body.centerLeft - const Offset(80, 0),
                body.centerRight + const Offset(80, 0),
                const Size(10, 10),
              ),
              false,
            );
            expect(
              world.trails.any(
                (trail) => trail.near(body.center, body.width / 2 + 80),
              ),
              false,
            );
            expect(
              world.sites.any((site) => site.body.inflate(500).overlaps(body)),
              false,
            );
            expect(
              world.chests.any((chest) => body.inflate(130).contains(chest)),
              false,
            );
            expect(world.isWater(body.center), false);
            final approach = world.spawnNear(
              body.bottomCenter + const Offset(-12, 35),
              const Size(24, 22),
            );
            expect(approach, isNotNull);
            final bucket =
                '${(landmark.drawBounds.center.dx / 256).floor()}:${(landmark.drawBounds.top / 256).floor()}';
            expect(
              world.propBuckets[bucket]!.any(
                (p) => identical(p.landmark, landmark),
              ),
              true,
            );
            expect(other.landmarks[landmark.index].center, landmark.center);
          }
        }
      });
    }
  }
  test('a saved hero inside a new formation resumes safely nearby', () {
    final s = Adventure(GameArt())..start(TestGame());
    addTearDown(s.dispose);
    final landmark = s.world.landmarks.first;
    s.hero.position.setValues(landmark.center.dx, landmark.center.dy);
    final saved = GameCheckpoint.decode(GameCheckpoint.capture(s)!.encode())!;
    final restored = saved.restore(GameArt())..start(TestGame());
    addTearDown(restored.dispose);
    expect(restored.world.blocked(restored.hero.body), false);
    expect(
      (restored.hero.body.center - landmark.center).distance,
      lessThan(230),
    );
  });
}

import 'dart:io';
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
            final solid = landmark.terrace?.solids.first;
            final core = solid == null
                ? body.center
                : landmark.artPoint(
                    solid.reduce((a, b) => a + b) / solid.length.toDouble(),
                  );
            expect(
              world.blocked(
                Rect.fromCenter(center: core, width: 24, height: 22),
              ),
              true,
            );
            expect(
              world.clearLine(
                Offset(body.left - 80, core.dy),
                Offset(body.right + 80, core.dy),
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

  test(
    'forest grass aprons allow eastward walking, raised cores stay solid',
    () {
      final world = AdventureWorld();
      for (final landmark in world.landmarks) {
        const size = Guardian.onFootSize;
        // This strip is painted grass in front of the structure. The old full
        // rectangular footprint stopped the hero on entering it from the left.
        final from = landmark.footprint.bottomLeft + const Offset(-40, -8);
        final to = from + const Offset(160, 0);
        expect(landmark.footprint.overlaps(to & size), true);
        expect(world.blocked(from & size), false);
        expect(world.blocked(to & size), false, reason: landmark.name);
        expect(world.clearLine(from, to, size), true, reason: landmark.name);
        expect(
          (world.move(from, to - from, size) - to).distance,
          lessThan(.000001),
          reason: landmark.name,
        );
        expect(world.clearEnemyLine(from, to, size), true);
        expect(
          (world.moveEnemy(from, to - from, size) - to).distance,
          lessThan(.000001),
        );
        expect(
          world.blocked(
            Rect.fromCenter(
              center: landmark.terrace == null
                  ? landmark.footprint.center
                  : landmark.artPoint(
                      landmark.terrace!.solids.first.reduce((a, b) => a + b) /
                          landmark.terrace!.solids.first.length.toDouble(),
                    ),
              width: size.width,
              height: size.height,
            ),
          ),
          true,
        );
      }
      final roots = world.landmarks.first.footprint;
      final west = roots.centerLeft + const Offset(-40, -12);
      final east = west + const Offset(80, 0);
      expect(roots.overlaps(east & Guardian.onFootSize), true);
      expect(world.clearLine(west, east, Guardian.onFootSize), true);
      expect(world.clearLine(east, roots.center, Guardian.onFootSize), false);
      final output = Platform.environment['SJRPG_LANDMARK_TRAVEL_PROOF'];
      if (output != null) {
        final s = Adventure(GameArt())..start(TestGame());
        addTearDown(s.dispose);
        final at =
            s.world.landmarks.first.footprint.centerLeft +
            const Offset(-40, -12);
        s.hero.position.setValues(at.dx, at.dy);
        File(output).writeAsStringSync(GameCheckpoint.capture(s)!.encode());
      }
    },
  );
}

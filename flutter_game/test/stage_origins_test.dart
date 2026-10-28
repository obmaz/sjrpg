import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/quest_giver.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final stage in WorldStage.values) {
    test('${stage.name} arrival has a complete walkable hub and services', () {
      final s = Adventure(GameArt(), stage: stage, hubOrigin: stage.arrival)
        ..start(TestGame());
      addTearDown(s.dispose);
      final world = s.world;
      expect(world.spawn, stage.arrival);
      expect(s.hero.body.topLeft, stage.arrival);
      expect(world.blocked(s.hero.body), false);
      expect(world.isWater(s.hero.body.center), false);
      expect(world.sanctuary.protects(s.hero.body), true);
      expect(world.settlementCollision, isNotEmpty);
      if (stage != WorldStage.forest) {
        final points = world.authoredSettlement.safeBoundary;
        var protectedBounds = Rect.fromPoints(points.first, points.first);
        for (final point in points.skip(1)) {
          protectedBounds = protectedBounds.expandToInclude(
            Rect.fromPoints(point, point),
          );
        }
        expect(world.sanctuary.center, protectedBounds.center);
        expect(world.settlement.contains(world.chests.first), true);
      }
      const size = Size(28, 24);
      for (final service in [
        world.authoredSettlement.wellApproach,
        world.merchantAt,
        if (stage == WorldStage.sands)
          ...timeQuestGivers.map((giver) => world.questGiverAt(giver.path))
        else
          world.elderAt,
      ]) {
        final approach = world.spawnNear(service, size);
        expect(approach, isNotNull);
        expect((approach! - service).distance, lessThan(160));
        expect(world.blocked(approach & size), false);
        expect(
          world.sanctuary.protects(approach & size),
          true,
          reason: '$stage service $service must remain inside the ward',
        );
        expect(
          world.clearLine(world.spawn, approach, size) ||
              world.route(world.spawn, approach, size).isNotEmpty,
          true,
          reason: 'the relocated hub must retain a full-body service approach',
        );
      }
      final landMounts = withOwnedMounts(
        s,
      ).mounts.where((mount) => !mount.def.waterOnly);
      expect(landMounts.length, 3);
      for (final mount in landMounts) {
        expect(
          world.blocked(
            Rect.fromCenter(
              center: mount.at,
              width: mount.def.bodySize.width,
              height: mount.def.bodySize.height,
            ),
          ),
          false,
        );
      }
    });
  }

  for (final path in TimePath.values) {
    test('${path.name} quest giver follows the new desert hub', () {
      final s = Adventure(
        GameArt(),
        stage: WorldStage.sands,
        hubOrigin: WorldStage.sands.arrival,
      )..start(TestGame());
      addTearDown(s.dispose);
      final giver = timeQuestGivers.firstWhere((giver) => giver.path == path);
      final at = s.world.questGiverAt(giver.path);
      final component = QuestGiver(s, giver);
      expect(
        (Offset(component.position.x, component.position.y) -
                (at - const Offset(14, 12)))
            .distance,
        lessThan(.001),
      );
      s.hero.position.setValues(giver.at.dx - 14, giver.at.dy - 12);
      expect(s.nearbyTimeGiver, null);
      s.hero.position.setValues(at.dx - 14, at.dy - 12);
      expect(s.nearbyTimeGiver, giver);
      final commission = timeCommissions.firstWhere(
        (quest) => quest.path == path,
      );
      expect(s.acceptCommission(commission), true);
      expect(s.timePath, path);
    });
  }

  test('legacy hubs remain supported while unrelated origins are rejected', () {
    for (final stage in WorldStage.values) {
      expect(stage.supportsHubOrigin(stage.spawn), true);
      expect(stage.supportsHubOrigin(stage.arrival), true);
      expect(
        stage.supportsHubOrigin(stage.arrival + const Offset(1, 0)),
        false,
      );
      expect(
        () => AdventureWorld(
          stage: stage,
          hubOrigin: stage.arrival + const Offset(1, 0),
        ),
        throwsArgumentError,
      );
    }
    expect(WorldStage.forest.arrival, WorldStage.forest.spawn);
    expect(WorldStage.past.arrival, WorldStage.past.spawn);
    expect(WorldStage.sands.arrival.dy / worldSize.height, closeTo(.5, .001));
    expect(WorldStage.future.arrival.dx / worldSize.width, greaterThan(.75));
    expect(WorldStage.future.arrival.dy / worldSize.height, lessThan(.25));
  });

  test(
    'explicit old desert hubs retain services, terrain and authored paths',
    () {
      final legacy = AdventureWorld(stage: WorldStage.sands);
      final restored = AdventureWorld(
        stage: WorldStage.sands,
        hubOrigin: WorldStage.sands.spawn,
      );
      expect(restored.spawn, legacy.spawn);
      expect(restored.healAt, legacy.healAt);
      expect(restored.elderAt, legacy.elderAt);
      expect(restored.merchantAt, legacy.merchantAt);
      expect(restored.chests, legacy.chests);
      expect(
        restored.trails.map((trail) => trail.points),
        legacy.trails.map((trail) => trail.points),
      );
      expect(
        restored.props.map((prop) => (prop.kind, prop.body)),
        legacy.props.map((prop) => (prop.kind, prop.body)),
      );
      final moved = AdventureWorld(
        stage: WorldStage.sands,
        hubOrigin: WorldStage.sands.arrival,
      );
      expect(
        moved.lakes.map((lake) => lake.points),
        legacy.lakes.map((lake) => lake.points),
      );
      expect(
        moved.sites.map((site) => site.at),
        legacy.sites.map((site) => site.at),
      );
    },
  );
}

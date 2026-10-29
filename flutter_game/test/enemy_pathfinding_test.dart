import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/world_model.dart';

// Existing route costs across authored chest, ruin, bridge and shore geometry.
// The large body also records narrow passages that must stay impassable.
// Local camp chests now sit inside the complete, enemy-free settlements.
// Remote props and narrow corridors retain their recorded route costs.
const _cases = [
  (
    WorldStage.forest,
    'warded-chest',
    Offset(2760.0, 2549.25),
    Offset(2976.0, 2549.25),
    (0, 0),
  ),
  (
    WorldStage.forest,
    'warded-chest',
    Offset(2242.5, 2425.5),
    Offset(2482.5, 2425.5),
    (0, 0),
  ),
  (
    WorldStage.forest,
    'tree',
    Offset(2157.5317045359043, 89.40359436539049),
    Offset(2357.5317045359043, 89.40359436539049),
    (11, 12),
  ),
  (
    WorldStage.forest,
    'tree',
    Offset(2242.52368050267, 121.90703120674748),
    Offset(2430.52368050267, 101.12242151592095),
    (10, 10),
  ),
  (
    WorldStage.forest,
    'unreachable-boat-target',
    Offset(4262.548647063142, 765.154972233483),
    Offset(4262.548647063142, 925.154972233483),
    (0, 0),
  ),
  (
    WorldStage.forest,
    'bridge-bank',
    Offset(3708.8363811700647, 3250.0),
    Offset(4403.836381170065, 3250.0),
    (34, 34),
  ),
  (
    WorldStage.sands,
    'warded-chest',
    Offset(5094.143200474463, 6803.600103115019),
    Offset(5716.624193128285, 6772.603347569622),
    (0, 0),
  ),
  (
    WorldStage.sands,
    'chest',
    Offset(8977.5, 8283.0),
    Offset(9217.5, 8283.0),
    (11, 0),
  ),
  (
    WorldStage.sands,
    'temple-0',
    Offset(7606.5, 18062.5),
    Offset(7978.5, 18062.5),
    (18, 19),
  ),
  (
    WorldStage.sands,
    'cactus',
    Offset(9249.706984668632, 135.37727129055884),
    Offset(9523.706984668632, 135.37727129055884),
    (15, 15),
  ),
  (
    WorldStage.sands,
    'unreachable-boat-target',
    Offset(12798.348664953846, 3911.1357372909642),
    Offset(12798.348664953846, 4071.1357372909642),
    (0, 0),
  ),
  (
    WorldStage.past,
    'warded-chest',
    Offset(16794.143200474464, 13253.600103115019),
    Offset(17416.624193128286, 13222.603347569622),
    (0, 0),
  ),
  (
    WorldStage.past,
    'chest',
    Offset(6727.5, 6033.0),
    Offset(6967.5, 6033.0),
    (12, 0),
  ),
  (
    WorldStage.past,
    'ruin-4',
    Offset(783.4524389781006, 192.34603372997518),
    Offset(983.4524389781006, 192.34603372997518),
    (11, 12),
  ),
  (
    WorldStage.past,
    'ruin-6',
    Offset(1074.4438291906663, 141.37645011398098),
    Offset(1274.4438291906663, 141.37645011398098),
    (11, 11),
  ),
  (
    WorldStage.past,
    'unreachable-boat-target',
    Offset(3580.257351991554, 14189.506479633095),
    Offset(3740.257351991554, 14189.506479633095),
    (0, 0),
  ),
  (
    WorldStage.future,
    'warded-chest',
    Offset(8994.143200474462, 18503.60010311502),
    Offset(9616.624193128284, 18472.60334756962),
    (0, 0),
  ),
  (
    WorldStage.future,
    'chest',
    Offset(6727.5, 6033.0),
    Offset(6967.5, 6033.0),
    (12, 0),
  ),
  (
    WorldStage.future,
    'city-0',
    Offset(48.282562826415614, 139.2165657195421),
    Offset(248.2825628264156, 139.2165657195421),
    (11, 12),
  ),
  (
    WorldStage.future,
    'city-0',
    Offset(529.1084069099247, 136.25327644378524),
    Offset(729.1084069099247, 136.25327644378524),
    (11, 12),
  ),
  (
    WorldStage.future,
    'unreachable-boat-target',
    Offset(16864.15795579629, 5812.561691622928),
    Offset(17024.15795579629, 5812.561691622928),
    (0, 0),
  ),
  (
    WorldStage.tombs,
    'warded-chest',
    Offset(27444.143200474464, 20603.60010311502),
    Offset(28066.624193128286, 20572.60334756962),
    (0, 0),
  ),
  (
    WorldStage.tombs,
    'chest',
    Offset(4852.5, 4908.0),
    Offset(5092.5, 4908.0),
    (12, 0),
  ),
  (
    WorldStage.tombs,
    'ruin-4',
    Offset(1826.585090135744, 128.3049959859018),
    Offset(2026.585090135744, 128.3049959859018),
    (11, 11),
  ),
  (
    WorldStage.tombs,
    'ruin-5',
    Offset(5262.371540997698, 173.90964077276044),
    Offset(5462.371540997698, 173.90964077276044),
    (12, 12),
  ),
  (
    WorldStage.tombs,
    'unreachable-boat-target',
    Offset(10122.821501449234, 8902.075186394146),
    Offset(10282.821501449234, 8902.075186394146),
    (0, 0),
  ),
  (
    WorldStage.foundry,
    'warded-chest',
    Offset(4944.143200474463, 10853.600103115019),
    Offset(5566.624193128285, 10822.603347569622),
    (0, 0),
  ),
  (
    WorldStage.foundry,
    'chest',
    Offset(12727.5, 3783.0),
    Offset(12967.5, 3783.0),
    (12, 0),
  ),
  (
    WorldStage.foundry,
    'city-2',
    Offset(247.69816127154922, 195.37839820455184),
    Offset(447.6981612715492, 195.37839820455184),
    (12, 12),
  ),
  (
    WorldStage.foundry,
    'city-1',
    Offset(1292.62236248919, 124.08021036371281),
    Offset(1492.62236248919, 124.08021036371281),
    (11, 11),
  ),
  (
    WorldStage.foundry,
    'unreachable-boat-target',
    Offset(11565.0, 11062.5),
    Offset(11725.0, 11062.5),
    (0, 0),
  ),
  (
    WorldStage.convergence,
    'warded-chest',
    Offset(15444.143200474462, 12728.600103115019),
    Offset(16066.624193128284, 12697.603347569622),
    (0, 0),
  ),
  (
    WorldStage.convergence,
    'chest',
    Offset(5977.5, 4533.0),
    Offset(6217.5, 4533.0),
    (13, 0),
  ),
  (
    WorldStage.convergence,
    'ruin-6',
    Offset(3209.905893816921, 137.42615652534366),
    Offset(3409.905893816921, 137.42615652534366),
    (11, 11),
  ),
  (
    WorldStage.convergence,
    'ruin-5',
    Offset(3651.1924125051037, 166.4529361951673),
    Offset(3851.1924125051037, 166.4529361951673),
    (11, 12),
  ),
  (
    WorldStage.convergence,
    'unreachable-boat-target',
    Offset(11973.930354540476, 3073.4955326805093),
    Offset(11973.930354540476, 3233.4955326805093),
    (0, 0),
  ),
];

void main() {
  for (final stage in WorldStage.values) {
    test(
      '${stage.name} retains route costs, reachability and full-body clearance',
      () {
        final world = AdventureWorld(stage: stage);
        for (final sample in _cases.where((sample) => sample.$1 == stage)) {
          for (final (body, length) in [
            (const Size(24, 22), sample.$5.$1),
            (const Size(48, 40), sample.$5.$2),
          ]) {
            final path = world.routeEnemy(sample.$3, sample.$4, body);
            if (stage == WorldStage.sands &&
                (sample.$2 == 'temple-0' || sample.$2 == 'cactus')) {
              final between = Offset.lerp(sample.$3, sample.$4, .5)!;
              expect(
                world.props.any(
                  (prop) =>
                      prop.kind == sample.$2 && prop.body.contains(between),
                ),
                true,
                reason: 'the fixture must cross the actual current obstacle',
              );
              expect(world.blocksEnemy(sample.$3 & body), false);
              expect(world.blocksEnemy(sample.$4 & body), false);
              expect(world.clearEnemyLine(sample.$3, sample.$4, body), false);
              expect(
                path,
                isNotEmpty,
                reason: 'both body sizes can detour around the ruin',
              );
            }
            if (sample.$2 == 'warded-chest') {
              expect(world.sanctuary.protects(sample.$4 & body), true);
            }
            expect(path.length, length, reason: '${sample.$2}, body $body');
            expect(
              world.routeEnemy(sample.$3, sample.$4, body),
              path,
              reason: 'equal-score alternatives must remain deterministic',
            );
            var at = sample.$3;
            for (final next in path) {
              expect(world.clearEnemyLine(at, next, body), true);
              expect(world.blocksEnemy(next & body), false);
              expect(
                (world.moveEnemy(at, next - at, body) - next).distance,
                lessThan(.000001),
                reason: '${sample.$2} traverses a physical obstacle',
              );
              at = next;
            }
            if (path.isNotEmpty) {
              expect((path.last - sample.$4).distance, lessThan(42));
            }
          }
        }
      },
    );
  }

  test('opening and reclosing a chest changes the same physical route', () {
    final world = AdventureWorld();
    const body = Size(24, 22);
    for (var i = 0; i < world.chests.length; i++) {
      final chest = world.chests[i];
      final from = world.spawnNear(
        chest + const Offset(-120, -12),
        body,
        avoidSanctuary: true,
      );
      final to = world.spawnNear(
        chest + const Offset(120, -12),
        body,
        avoidSanctuary: true,
      );
      if (from == null || to == null || world.clearEnemyLine(from, to, body)) {
        continue;
      }
      final before = world.routeEnemy(from, to, body);
      if (before.isEmpty) continue;
      world.openedChests.add(i);
      if (!world.clearEnemyLine(from, to, body)) {
        world.openedChests.remove(i);
        continue;
      }
      final after = world.routeEnemy(from, to, body);
      expect(after.length, lessThan(before.length));
      world.openedChests.remove(i);
      expect(world.routeEnemy(from, to, body), before);
      return;
    }
    fail('authored map needs an accessible solid chest route');
  });
}

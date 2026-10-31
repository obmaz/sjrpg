import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/quest_structure_art.dart';
import 'package:guardian_new/world_model.dart';

Offset interactionAt(AdventureWorld world, QuestSite site) =>
    world.stage == WorldStage.forest
    ? ForestQuestStructureArt.npcPosition(site.id, site.at)
    : site.at;

// Sample authored roads and open approaches, then validate every graph edge with
// the same swept body used by gameplay. The local grids let a route round camp furniture.
Map<String, List<Offset>> questRoutes(AdventureWorld world, Size size) {
  final half = Offset(size.width / 2, size.height / 2);
  final nodes = <Offset>[];
  final buckets = <String, List<int>>{};
  final unique = <String>{};
  void add(Offset p) {
    final key = '${(p.dx / 8).round()}:${(p.dy / 8).round()}';
    if (!unique.add(key) ||
        world.blocked(
          Rect.fromCenter(center: p, width: size.width, height: size.height),
        )) {
      return;
    }
    final id = nodes.length;
    nodes.add(p);
    buckets
        .putIfAbsent(
          '${(p.dx / 128).floor()}:${(p.dy / 128).floor()}',
          () => [],
        )
        .add(id);
  }

  add(world.spawn + half);
  assert(nodes.length == 1);
  var bounds = Rect.fromCircle(center: world.spawn, radius: 1);
  for (final site in world.sites) {
    bounds = bounds.expandToInclude(
      Rect.fromCircle(center: site.at, radius: 1),
    );
  }
  // Authored loop roads may deliberately travel beyond the quest rectangle.
  // Include those real detours instead of silently cutting the graph in half.
  for (final trail in world.trails) {
    bounds = bounds.expandToInclude(trail.bounds);
  }
  bounds = bounds.inflate(500);
  for (final trail in world.trails) {
    for (var i = 1; i < trail.points.length; i++) {
      final a = trail.points[i - 1],
          d = trail.points[i] - a,
          n = (d.distance / 48).ceil();
      final normal = d.distance == 0
          ? Offset.zero
          : Offset(-d.dy, d.dx) / d.distance;
      for (var j = 0; j <= n; j++) {
        final p = a + d * (j / math.max(1, n));
        if (!bounds.contains(p)) continue;
        for (final offset in [-48.0, 0.0, 48.0]) {
          add(p + normal * offset);
        }
      }
    }
  }
  for (final center in [
    world.spawn + half,
    ...world.sites.map((site) => interactionAt(world, site)),
  ]) {
    for (var y = -360; y <= 360; y += 48) {
      for (var x = -360; x <= 360; x += 48) {
        add(center + Offset(x.toDouble(), y.toDouble()));
      }
    }
  }
  // Complete settlement illustrations span more than the old camp patch.
  // Sample the actual open courts and gate approaches; all graph edges below
  // still use full-body sweeps, so this never joins through painted buildings.
  final village = world.authoredSettlement.bounds.inflate(240);
  for (var y = village.top; y <= village.bottom; y += 48) {
    for (var x = village.left; x <= village.right; x += 48) {
      add(Offset(x, y));
    }
  }
  // Breakable chests occupy the road center. Sample their open perimeter at
  // half the road spacing so a mount can take a real, swept-clear sidestep.
  for (final center in world.chests) {
    if (!bounds.contains(center)) continue;
    for (var y = -144; y <= 144; y += 24) {
      for (var x = -144; x <= 144; x += 24) {
        add(center + Offset(x.toDouble(), y.toDouble()));
      }
    }
  }
  final queue = <int>[0], parent = <int, int>{0: -1};
  for (var head = 0; head < queue.length; head++) {
    final id = queue[head],
        p = nodes[id],
        x = (p.dx / 128).floor(),
        y = (p.dy / 128).floor();
    for (var by = y - 1; by <= y + 1; by++) {
      for (var bx = x - 1; bx <= x + 1; bx++) {
        for (final next in buckets['$bx:$by'] ?? const <int>[]) {
          if (parent.containsKey(next) || (nodes[next] - p).distance > 110) {
            continue;
          }
          if (world.clearLine(p - half, nodes[next] - half, size)) {
            parent[next] = id;
            queue.add(next);
          }
        }
      }
    }
  }

  final routes = <String, List<Offset>>{};
  for (final site in world.sites) {
    final candidates =
        queue
            .where(
              (i) =>
                  (nodes[i] - interactionAt(world, site)).distance < 115 &&
                  world.clearLine(
                    nodes[i],
                    interactionAt(world, site),
                    const Size(3, 3),
                  ),
            )
            .toList()
          ..sort(
            (a, b) => (nodes[a] - interactionAt(world, site)).distance
                .compareTo((nodes[b] - interactionAt(world, site)).distance),
          );
    if (candidates.isEmpty) continue;
    var current = candidates.first;
    final path = <Offset>[];
    while (current != -1) {
      path.add(nodes[current]);
      current = parent[current]!;
    }
    routes[site.id] = path.reversed.toList();
  }
  return routes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stage in WorldStage.values) {
    for (final size in [const Size(28, 24), travelMountDefs.first.bodySize]) {
      test(
        '${stage.name} connects every mandatory site to camp for a ${size.width}×${size.height} body',
        () {
          final world = AdventureWorld(stage: stage);
          final routes = questRoutes(world, size);
          expect(routes.keys, containsAll(world.sites.map((site) => site.id)));
          final half = Offset(size.width / 2, size.height / 2);
          for (final site in world.sites) {
            final route = routes[site.id]!;
            var position = world.spawn;
            for (final center in route.skip(1)) {
              final target = center - half;
              final from = position;
              position = world.move(position, target - position, size);
              expect(
                (position - target).distance,
                lessThan(.05),
                reason:
                    '${site.id}: full movement reaches each swept-clear route segment; from/target/actual ${[from.dx, from.dy, target.dx, target.dy, position.dx, position.dy]}',
              );
            }
            expect(
              (position + half - interactionAt(world, site)).distance,
              lessThan(115),
            );
            expect(
              world.clearLine(
                position + half,
                interactionAt(world, site),
                const Size(3, 3),
              ),
              true,
            );
          }
        },
      );
    }
  }
}

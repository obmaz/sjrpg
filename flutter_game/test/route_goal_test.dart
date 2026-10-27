import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/world_model.dart';

class _CountingWorld extends AdventureWorld {
  _CountingWorld() {
    recording = true;
  }
  bool recording = false;
  int lineChecks = 0, bodyChecks = 0;
  @override
  bool blocked(
    Rect body, {
    bool waterOnly = false,
    bool ignoreWater = false,
    bool avoidSanctuary = false,
  }) {
    if (recording) bodyChecks++;
    return super.blocked(
      body,
      waterOnly: waterOnly,
      ignoreWater: ignoreWater,
      avoidSanctuary: avoidSanctuary,
    );
  }

  @override
  bool clearLine(
    Offset from,
    Offset to,
    Size size, {
    bool avoidSanctuary = false,
  }) {
    if (recording) lineChecks++;
    return super.clearLine(from, to, size, avoidSanctuary: avoidSanctuary);
  }

  void resetCounts() => lineChecks = bodyChecks = 0;
}

// One physically available lattice point isolates the exact stopping radius.
// Real authored water/bridge/chest geometry is covered separately below.
class _SinglePointWorld extends AdventureWorld {
  _SinglePointWorld(this.allowed, this.bodySize) {
    recording = true;
  }
  final Offset allowed;
  final Size bodySize;
  bool recording = false;
  int lineChecks = 0;
  @override
  bool blocked(
    Rect body, {
    bool waterOnly = false,
    bool ignoreWater = false,
    bool avoidSanctuary = false,
  }) {
    if (!recording) {
      return super.blocked(
        body,
        waterOnly: waterOnly,
        ignoreWater: ignoreWater,
        avoidSanctuary: avoidSanctuary,
      );
    }
    return body.topLeft != allowed || body.size != bodySize;
  }

  @override
  bool clearLine(
    Offset from,
    Offset to,
    Size size, {
    bool avoidSanctuary = false,
  }) {
    if (!recording) {
      return super.clearLine(from, to, size, avoidSanctuary: avoidSanctuary);
    }
    lineChecks++;
    return !blocked(from & size, avoidSanctuary: avoidSanctuary) &&
        !blocked(to & size, avoidSanctuary: avoidSanctuary);
  }
}

void main() {
  for (final size in [const Size(24, 22), const Size(48, 40)]) {
    test(
      'unreachable deep-water goal skips search for the whole $size body',
      () {
        final world = _CountingWorld();
        const goal = Offset(4262.548647063142, 925.154972233483);
        final from = world.spawnNear(
          const Offset(4262.548647063142, 765.154972233483),
          size,
          avoidSanctuary: true,
        )!;
        expect(world.blocksEnemy(from & size), false);
        expect(world.blocked(goal & size, waterOnly: true), false);
        world.resetCounts();
        expect(world.routeEnemy(from, goal, size), isEmpty);
        expect(
          world.lineChecks,
          0,
          reason: 'no anchor or heap-edge work for a provably absent goal',
        );
        expect(world.bodyChecks, lessThanOrEqualTo(26));
      },
    );

    test(
      'blocked nearshore target retains a reachable shore lattice goal for $size',
      () {
        final world = _CountingWorld();
        for (final lake in world.lakes) {
          final b = lake.bounds;
          for (final dy in [0.0, -24.0, 24.0]) {
            final goal = Offset(b.right - 8, b.center.dy + dy);
            if (!world.isWater(goal)) continue;
            final from = world.spawnNear(
              Offset(b.right + 60, b.center.dy + dy),
              size,
              avoidSanctuary: true,
            );
            if (from == null) continue;
            world.resetCounts();
            final path = world.routeEnemy(from, goal, size);
            if (path.isEmpty) continue;
            expect(world.blocksEnemy(goal & size), true);
            expect(world.lineChecks, greaterThan(0));
            expect((path.last - goal).distance, lessThan(42));
            var at = from;
            for (final point in path) {
              expect(world.blocksEnemy(point & size), false);
              expect(world.clearEnemyLine(at, point, size), true);
              at = point;
            }
            return;
          }
        }
        fail(
          'authored shore needs a blocked water target within42 of a reachable full-body grid point',
        );
      },
    );

    test(
      'exact42px boundary remains strict and subpixel-near goals stay reachable for $size',
      () {
        const from = Offset(
          6000,
          4200,
        ); // Both coordinates lie on the24px lattice.
        final world = _SinglePointWorld(from, size);
        for (final delta in [
          const Offset(42 - 1e-8, 0),
          const Offset(0, 42 - 1e-8),
          const Offset(-42 + 1e-8, 0),
          const Offset(0, -42 + 1e-8),
        ]) {
          world.lineChecks = 0;
          expect(world.routeEnemy(from, from + delta, size), [from]);
          expect(world.lineChecks, greaterThan(0));
        }
        for (final delta in [
          const Offset(42, 0),
          const Offset(0, 42),
          const Offset(-42, 0),
          const Offset(0, -42),
          const Offset(42 + 1e-8, 0),
        ]) {
          world.lineChecks = 0;
          expect(world.routeEnemy(from, from + delta, size), isEmpty);
          expect(world.lineChecks, 0);
        }
      },
    );
  }
}

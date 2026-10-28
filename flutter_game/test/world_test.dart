import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'hero art has sixteen distinct bearings without quantizing movement',
    () {
      expect(
        List.generate(
          16,
          (i) => facingFrame(math.pi / 2 + i * math.pi / 8, 16),
        ).toSet().length,
        16,
      );
      expect(facingFrame(math.pi / 2, 16), 0);
      expect(facingFrame(0, 16), 12);
    },
  );
  test('local minimap keeps the hero centered even at world boundaries', () {
    expect(worldSize, const Size(34560, 25920));
    final view = localMapBounds(const Offset(14000, 12000));
    expect(view.center, const Offset(14000, 12000));
    expect(view.size, const Size(2100, 2100));
    expect(localMapBounds(Offset.zero).center, Offset.zero);
    expect(
      localMapBounds(const Offset(23040, 17280)).center,
      const Offset(23040, 17280),
    );
  });
  test('large biomes include open clearings and distinct sand regions', () {
    final world = AdventureWorld();
    expect(world.sandFields.length, 6);
    expect(world.isSand(const Offset(15500, 5000) * worldScale), true);
    expect(world.areaName(const Offset(15500, 5000) * worldScale), '태양의 사구');
    expect(world.isWooded(const Offset(10500, 7200) * worldScale), false);
    expect(world.areaName(const Offset(10500, 7200) * worldScale), '바람꽃 초원');
    expect(
      world.props
          .where((p) => p.kind == 'tree')
          .any((p) => world.clearings.any((c) => c.contains(p.body.center))),
      false,
    );
  });
  test('cleared opening and major trails admit walkers and ground mounts', () {
    final world = AdventureWorld();
    world.openedChests.addAll(List.generate(world.chests.length, (i) => i));
    for (final size in const [Size(24, 22), Size(40, 32)]) {
      final half = Offset(size.width / 2, size.height / 2);
      expect(
        world.blocked(
          Rect.fromLTWH(arrival.dx, arrival.dy, size.width, size.height),
        ),
        false,
      );
      for (final trail in world.trails) {
        var p = trail.points.first - half;
        expect(
          world.blocked(Rect.fromLTWH(p.dx, p.dy, size.width, size.height)),
          false,
          reason: 'start ${trail.points.first} size $size',
        );
        for (final point in trail.points.skip(1)) {
          final destination = point - half;
          p = world.move(p, destination - p, size);
          expect(
            (p - destination).distance,
            lessThan(2),
            reason: 'trail at $point, body $size',
          );
        }
      }
    }
  });
  test(
    'ground bodies cannot tunnel through a tree or lake even at dash speed',
    () {
      final world = AdventureWorld();
      final prop = world.props.firstWhere((p) => p.kind == 'tree');
      final from = prop.body.topLeft - const Offset(100, 0);
      final end = world.move(from, const Offset(300, 0), const Size(24, 22));
      expect(end.dx + 24, lessThanOrEqualTo(prop.body.left + .001));
      expect(
        world.blocked(
          Rect.fromLTWH(5680 * worldScale, 1700 * worldScale, 24, 22),
        ),
        true,
      );
      expect(
        world.clearLine(
          const Offset(4800, 1700) * worldScale,
          const Offset(6550, 1700) * worldScale,
          const Size(3, 3),
        ),
        false,
      );
    },
  );
  test('the river is blocked and its painted bridge admits the whole body', () {
    final world = AdventureWorld(), center = world.bridge.center;
    expect(
      world.blocked(Rect.fromCenter(center: center, width: 24, height: 22)),
      false,
    );
    expect(
      world.blocked(
        Rect.fromCenter(
          center: center - const Offset(0, 240),
          width: 24,
          height: 22,
        ),
      ),
      true,
    );
    for (final size in [const Size(24, 22), const Size(44, 32)]) {
      final from = Offset(center.dx - 500, center.dy - size.height / 2);
      final to = from + const Offset(1000, 0);
      expect(
        world.clearLine(from, to, size),
        true,
        reason: 'shore-to-shore clearance must agree with the visible bridge',
      );
      expect(world.clearLine(to, from, size), true);
    }
    var p = Offset(center.dx - 500, center.dy - 11);
    p = world.move(p, const Offset(1000, 0), const Size(24, 22));
    expect(p.dx, closeTo(center.dx + 500, .01));
  });
  test('the enlarged village east road crosses a visible full-body bridge', () {
    final world = AdventureWorld();
    final east = world.bridges.last;
    expect(
      east,
      isNot(world.bridge),
      reason: 'the old bridge anchor stays intact',
    );
    expect(east.center.dy, lessThan(world.bridge.center.dy));
    for (final size in [
      const Size(28, 24),
      const Size(44, 32),
      const Size(48, 40),
    ]) {
      final from = Offset(east.left - 100, east.center.dy - size.height / 2);
      final to = Offset(east.right + 100, from.dy);
      expect(world.clearLine(from, to, size), true);
      expect(world.clearLine(to, from, size), true);
      final end = world.move(from, to - from, size);
      expect((end - to).distance, lessThan(.01));
      final back = world.move(to, from - to, size);
      expect((back - from).distance, lessThan(.01));
    }
  });
  test(
    'rewards progress once per caller and upgrades cannot overspend gold',
    () {
      final p = Progress();
      expect(p.buy(20, () => p.maxHp += 20), false);
      expect(p.maxHp, 100);
      for (var i = 0; i < 8; i++) {
        p.reward();
      }
      expect(p.level, 1);
      expect(p.xp, 40);
      expect(p.gold, 64);
      p.gainXp(p.nextLevelXp - p.xp);
      expect(p.level, 2);
      expect(p.xp, 0);
      expect(p.gold, 64, reason: 'experience alone must not create gold');
      expect(p.swordDamage, closeTo(17 * .75 * .85, .00001));
      expect(p.buy(45, () => p.swordDamage += 5), true);
      expect(p.gold, 19);
      expect(p.swordDamage, closeTo(17 * .75 * .85 + 5, .00001));
      p.reward(boss: true);
      expect(p.bossDefeated, true);
      expect(p.gold, 119);
    },
  );
}

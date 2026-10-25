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
  test('opening and every major trail are traversable with a full body', () {
    final world = AdventureWorld();
    const size = Size(24, 22);
    expect(
      world.blocked(
        Rect.fromLTWH(arrival.dx, arrival.dy, size.width, size.height),
      ),
      false,
    );
    for (final trail in world.trails) {
      var p = trail.points.first - const Offset(12, 11);
      expect(world.blocked(Rect.fromLTWH(p.dx, p.dy, 24, 22)), false);
      for (final point in trail.points.skip(1)) {
        final destination = point - const Offset(12, 11);
        p = world.move(p, destination - p, size);
        expect(
          (p - destination).distance,
          lessThan(2),
          reason: 'trail at $point',
        );
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
      expect(world.blocked(Rect.fromLTWH(5680, 1700, 24, 22)), true);
      expect(
        world.clearLine(
          const Offset(4800, 1700),
          const Offset(6550, 1700),
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
    var p = Offset(center.dx - 500, center.dy - 11);
    p = world.move(p, const Offset(1000, 0), const Size(24, 22));
    expect(p.dx, closeTo(center.dx + 500, .01));
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
      expect(p.stage, 2);
      expect(p.gold, 64);
      expect(p.swordDamage, 17);
      expect(p.buy(45, () => p.swordDamage += 5), true);
      expect(p.gold, 19);
      expect(p.swordDamage, 22);
      p.reward(boss: true);
      expect(p.bossDefeated, true);
      expect(p.gold, 119);
    },
  );
}

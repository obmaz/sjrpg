import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_motion.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('running cadence follows the same distance at 30 and 60 updates', () {
    final slow = RunMotion(), fast = RunMotion();
    for (final (motion, frames) in [(slow, 30), (fast, 60)]) {
      for (var i = 0; i < frames; i++) {
        motion.advance(110 / frames);
      }
    }
    expect(slow.cycle, closeTo(fast.cycle, .000001));
    expect(slow.phase, fast.phase);
    final cycle = slow.cycle;
    slow.advance(0);
    slow.advance(double.nan);
    expect(slow.cycle, cycle);
  });
  test('walking into a tree advances only by the resolved body distance', () {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    final size = s.hero.body.size;
    final tree = s.world.props.firstWhere(
      (p) =>
          p.kind == 'tree' &&
          !s.world.blocked(
            Rect.fromLTWH(
              p.body.left - size.width - 1,
              p.body.center.dy - size.height / 2,
              size.width,
              size.height,
            ),
          ),
    );
    s.hero.position.setValues(
      tree.body.left - size.width - 1,
      tree.body.center.dy - size.height / 2,
    );
    final start = s.hero.position.clone();
    for (var i = 0; i < 20; i++) {
      s.hero.moveByAngle(0, speed: 270);
      s.hero.update(.05);
    }
    final distance = (s.hero.position - start).length;
    expect(distance, lessThan(2));
    expect(
      s.hero.runMotion.cycle,
      closeTo(distance / RunMotion.strideLength, .0001),
    );
    expect(s.hero.animationTime, closeTo(distance / 270, .0001));
    final cycle = s.hero.runMotion.cycle;
    s.pause();
    s.hero.update(.5);
    expect(s.hero.runMotion.cycle, cycle);
  });
  test('attack drawing has bounded recovery and never moves its body', () {
    final motion = EnemyAttackMotion()
      ..strike(EnemyAttackPose.melee, math.pi / 2);
    expect(motion.offset, Offset.zero);
    motion.update(.07);
    expect(motion.offset.dx, closeTo(0, .0001));
    expect(motion.offset.dy, closeTo(5, .0001));
    motion.update(.22);
    expect(motion.active, false);
    expect(motion.offset, Offset.zero);
    motion.strike(EnemyAttackPose.bolt, 0);
    motion.update(.07);
    expect(motion.offset.dx, closeTo(-3, .0001));
    motion.cancel();
    expect(motion.active, false);
  });
}

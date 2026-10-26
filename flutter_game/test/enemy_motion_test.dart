import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/enemy_motion.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'gait follows distance and eases to rest instead of walking into a wall',
    () {
      final motion = EnemyMotion();
      for (var i = 0; i < 20; i++) {
        motion.update(.01, distance: 1, bearing: 0);
      }
      expect(motion.weight, greaterThan(.9));
      expect(motion.lift, greaterThan(0));
      final phase = motion.stride;
      for (var i = 0; i < 60; i++) {
        motion.update(.01, distance: 0, bearing: 0);
      }
      expect(motion.stride, phase);
      expect(motion.lift, lessThan(.001));
      expect(motion.scaleX, closeTo(1, .001));
    },
  );
  test('turns follow the short arc and gait is independent of frame rate', () {
    final slow = EnemyMotion(), fast = EnemyMotion();
    for (final (motion, frames) in [(slow, 30), (fast, 60)]) {
      motion.update(.01, distance: 0, bearing: math.pi - .05);
      for (var i = 0; i < frames; i++) {
        motion.update(
          1 / frames,
          distance: 96 / frames,
          bearing: -math.pi + .05,
        );
      }
    }
    expect(slow.facing, greaterThan(math.pi));
    expect(slow.facing, closeTo(fast.facing, .00001));
    expect(slow.stride, closeTo(fast.stride, .00001));
    expect(slow.weight, closeTo(fast.weight, .00001));
  });
  test(
    'enemy pause freezes render motion and recoil cannot alter its body',
    () {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      final mob = s.spawnEnemy('goblin', const Offset(6180, 4200))!;
      mob.update(.05);
      s.hit(mob, 1, const Offset(10, 0));
      final body = mob.body, phase = mob.motion.stride;
      s.pause();
      mob.update(.5);
      expect(mob.motion.reaction, .16);
      expect(mob.motion.stride, phase);
      expect(mob.body, body);
      s.resume();
      mob.update(.05);
      expect(mob.motion.recoil, greaterThan(0));
      expect(
        mob.body,
        body,
        reason: 'hurt reaction is visual while the body rests',
      );
      expect(s.world.blocked(mob.body), false);
    },
  );
  test(
    'a cleave shares one impact; a miss never generates contact feedback',
    () {
      final game = TestGame(), s = Adventure(GameArt());
      s.start(game);
      addTearDown(s.dispose);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      s.hero.bearing = 0;
      s.hero.slash();
      expect(s.impactTime, 0);
      expect(game.added.whereType<ContactSpark>(), isEmpty);
      for (var i = 0; i < 3; i++) {
        s.spawnEnemy('goblin', Offset(6040, 4180 + i * 30))!.life.initial(1000);
      }
      s.progress.ranks['cleave'] = 5;
      s.hero.attackClock = 0;
      final energy = s.progress.energy;
      s.hero.slash();
      expect(s.mobs.where((m) => m.life.value < 1000).length, 3);
      expect(game.added.whereType<ContactSpark>().length, 1);
      expect(
        s.progress.energy - energy,
        s.progress.rageOnHit(protected: false),
      );
      expect(s.hero.impactHold, greaterThan(0));
      expect(s.impactStrength, inInclusiveRange(.95, 2.4));
    },
  );
}

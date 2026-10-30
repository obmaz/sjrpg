import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'nine simultaneous hits apply immediately and rise one by one in one column',
    () {
      final s = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(s.dispose);
      final mob = s.spawnEnemy(
        'goblin',
        s.hero.body.center + const Offset(100, 0),
      )!;
      mob.life.initial(10000);
      for (var i = 0; i < 9; i++) {
        expect(s.hit(mob, 1, Offset.zero, critical: i.isEven), true);
      }
      expect(mob.life.value, 9991);
      expect(s.texts.where((t) => identical(t.target, mob)).length, 1);
      final births = <BattleText>{};
      var peak = 0;
      for (var frame = 0; frame < 180; frame++) {
        // The engine updates existing components before the next tick births.
        for (final text in s.texts.toList()) {
          text.update(1 / 60);
          if (text.remaining <= 0) text.onRemove();
        }
        s.tick(1 / 60);
        final visible = s.texts
            .where((t) => identical(t.target, mob) && t.remaining > 0)
            .toList();
        births.addAll(visible);
        if (visible.length > peak) peak = visible.length;
        expect(visible.length, lessThanOrEqualTo(5));
        for (var i = 0; i < visible.length; i++) {
          expect(visible[i].position.x, mob.body.center.dx);
          for (var j = i + 1; j < visible.length; j++) {
            expect(
              visible[i].combatBounds.overlaps(visible[j].combatBounds),
              false,
            );
            expect(visible[i].position.y, lessThan(visible[j].position.y));
          }
        }
      }
      expect(births.length, 9);
      expect(peak, 5);
      expect(mob.life.value, 9991);
    },
  );
  test(
    'different targets have independent streams and pause stops queued births',
    () {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      final a = Object(), b = Object();
      const color = Color(0xffffdd77);
      for (var i = 0; i < 9; i++) {
        s.bubble('1', const Offset(100, 100), color, target: a);
        s.bubble('2', const Offset(200, 100), color, target: b);
      }
      expect(s.texts.length, 2);
      s.pause();
      s.tick(1);
      expect(s.texts.length, 2);
      s.resume();
      s.tick(.2);
      expect(s.texts.length, 4);
      expect(s.texts.where((t) => identical(t.target, a)).length, 2);
      expect(s.texts.where((t) => identical(t.target, b)).length, 2);
    },
  );
  test(
    'a slow rendering frame cannot expire or jump a just-born damage number',
    () {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      final target = Object();
      s.bubble(
        '1',
        const Offset(100, 200),
        const Color(0xffffdd77),
        target: target,
      );
      final text = s.texts.single;
      s.tick(.05);
      text.update(1);
      expect(text.remaining, closeTo(BattleText.streamLifetime - .05, .001));
      expect(text.position.y, closeTo(182, .001));
      s.pause();
      s.tick(1);
      text.update(1);
      expect(text.remaining, closeTo(BattleText.streamLifetime - .05, .001));
      s.resume();
      s.tick(.05);
      text.update(1);
      expect(text.remaining, closeTo(BattleText.streamLifetime - .1, .001));
    },
  );
}

import 'package:bonfire/bonfire.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stage in WorldStage.values) {
    test(
      '$stage unaware enemies patrol outside the town without attacking',
      () {
        final s = Adventure(GameArt(), stage: stage)..start(TestGame());
        addTearDown(s.dispose);
        expect(s.sheltered, true);
        final ward = s.world.sanctuary;
        final mob = s.spawnEnemy(
          'goblin',
          ward.center + Offset(ward.radius + 180, 0),
        )!;
        final start = mob.position.toOffset();
        final hp = s.progress.hp;
        var travel = 0.0;
        for (var i = 0; i < 300; i++) {
          final before = mob.position.toOffset();
          s.elapsed += 1 / 30;
          mob.update(1 / 30);
          travel += (mob.position.toOffset() - before).distance;
          expect(s.world.blocksEnemy(mob.body), false);
          expect((mob.position.toOffset() - start).distance, lessThan(130));
          expect(mob.windup, 0);
          expect(mob.meleeWindup, 0);
        }
        expect(travel, greaterThan(30));
        expect(s.progress.hp, hp);
        final beforePause = mob.position.toOffset();
        s.pause();
        mob.update(1);
        expect(mob.position.toOffset(), beforePause);
        s.resume();
        mob.stun = 1;
        mob.update(.05);
        expect(mob.position.toOffset(), beforePause);
      },
    );
  }
  for (final boss in [false, true]) {
    test(
      'returning to town cancels ${boss ? 'boss' : 'normal'} attack preparation',
      () {
        final s = Adventure(GameArt())..start(TestGame());
        addTearDown(s.dispose);
        final mob = s.spawnEnemy(
          'goblin',
          const Offset(6100, 4200),
          boss: boss,
        )!;
        mob.windup = .6;
        mob.meleeWindup = .2;
        mob.slamTarget = s.hero.body.center;
        final hp = s.progress.hp;
        mob.update(.05);
        expect(mob.windup, 0);
        expect(mob.meleeWindup, 0);
        expect(mob.slamTarget, isNull);
        expect(mob.bossAttack, isNull);
        expect(s.progress.hp, hp);
      },
    );
  }
  test('patrol immediately gives way to pursuit when the hero leaves town', () {
    final s = Adventure(GameArt())..start(TestGame());
    addTearDown(s.dispose);
    final mob = s.spawnEnemy('goblin', const Offset(6100, 4200))!;
    for (var i = 0; i < 20; i++) {
      s.elapsed += 1 / 30;
      mob.update(1 / 30);
    }
    final field = s.world.spawnNear(
      mob.position.toOffset() + const Offset(-200, 0),
      s.hero.body.size,
      avoidSanctuary: true,
    )!;
    s.hero.position.setValues(field.dx, field.dy);
    expect(s.sheltered, false);
    final distance = (mob.body.center - s.hero.body.center).distance;
    for (var i = 0; i < 60; i++) {
      s.elapsed += 1 / 30;
      mob.update(1 / 30);
    }
    expect(
      (mob.body.center - s.hero.body.center).distance,
      lessThan(distance - 50),
    );
  });
}

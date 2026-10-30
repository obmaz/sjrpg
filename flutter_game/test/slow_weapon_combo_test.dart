import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final slowed in [false, true]) {
    test(
      'held greatsword repeats ordinary strikes without a timed finisher; slow=$slowed',
      () {
        final s = inCombatField(Adventure(GameArt()))..start(TestGame());
        addTearDown(s.dispose);
        s.mobs.clear();
        s.waveTime = 10000;
        final p = s.progress,
            weapon = s.progress.createGear(gearById('greatsword'));
        p.inventory.add(weapon);
        expect(p.equip(weapon), true);
        expect(p.rank('cleave'), 1);
        if (slowed) s.afflictions.apply(PlayerStatus.attackSlow);
        final target = s.spawnEnemy('cultist', const Offset(6050, 4200))!
          ..life.initial(10000);
        s.hero.bearing = 0;
        final poses = <int>[], damage = <double>[];
        var strikes = s.hero.strikes;
        var health = target.life.value;
        s.holdAttack('touch:combo', true);
        for (var i = 0; i < 1000 && poses.length < 3; i++) {
          s.hero.update(.02);
          s.tick(.02);
          if (s.hero.strikes == strikes) continue;
          expect(s.hero.strikes, strikes + 1);
          strikes = s.hero.strikes;
          poses.add(s.hero.strikePose);
          damage.add(health - target.life.value);
          health = target.life.value;
        }
        s.holdAttack('touch:combo', false);
        expect(poses, [1, 2, 0]);
        expect(damage.length, 3);
        final expectedDamage = target.power.mitigate(p.basicDamage);
        expect(damage[0], closeTo(expectedDamage, .000001));
        expect(damage[1], closeTo(expectedDamage, .000001));
        expect(damage[2], closeTo(expectedDamage, .000001));
        // Held input cannot bank a finisher, even for the slower debuffed weapon.
        // Waiting past the interval starts another ordinary opening strike.
        var idle = s.hero.attackClock + 1.2;
        while (idle > 0) {
          final dt = idle > .02 ? .02 : idle;
          s.hero.update(dt);
          s.tick(dt);
          idle -= dt;
        }
        final before = target.life.value;
        s.hero.slash();
        expect(s.hero.strikePose, 1);
        expect(target.life.value, closeTo(before - expectedDamage, .000001));
      },
    );
  }
}

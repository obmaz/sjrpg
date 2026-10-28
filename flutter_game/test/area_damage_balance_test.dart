import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  setUp(() {
    s = Adventure(GameArt())..start(TestGame());
    s.mobs.clear();
    s.hero.position.setValues(6000, 4200);
  });
  tearDown(() => s.dispose());
  HuntEnemy enemy(double x, [double y = 4200]) =>
      s.spawnEnemy('goblin', Offset(x, y))!..life.initial(1000);

  for (final count in [1, 2, 3]) {
    test('area damage uses the $count actually eligible enemies', () {
      final mobs = [for (var i = 0; i < count; i++) enemy(6050 + 35.0 * i)];
      areaStrike(s, s.hero.body.center, 250, 100, maxTargets: 11);
      final expected = [100.0, 80.0, 70.0][count - 1];
      for (final mob in mobs) {
        expect(mob.life.value, closeTo(1000 - expected, .000001));
      }
    });
  }
  test('target cap and excluded or unmounted enemies precede scaling', () {
    final mobs = [for (var i = 0; i < 6; i++) enemy(6050 + 25.0 * i)];
    mobs[0].combatReady = false;
    areaStrike(
      s,
      s.hero.body.center,
      300,
      100,
      maxTargets: 3,
      excluded: {mobs[1]},
    );
    expect(mobs[0].life.value, 1000);
    expect(mobs[1].life.value, 1000);
    expect(mobs[5].life.value, 1000);
    for (final mob in mobs.skip(2).take(3)) {
      expect(mob.life.value, closeTo(930, .000001));
    }
  });
  test('closed chest occlusion excludes an enemy before damage sharing', () {
    final chest = s.stageChestLocations.firstWhere(
      (at) =>
          (at - s.world.sanctuary.center).distance >
          s.world.sanctuary.radius + 300,
    );
    s.hero.position.setValues(chest.dx - 14, chest.dy + 90);
    final blocked = enemy(chest.dx - 14, chest.dy - 70);
    final visible = enemy(chest.dx + 90, chest.dy + 90);
    expect(
      s.world.clearLine(
        s.hero.body.center,
        blocked.body.center,
        const Size(3, 3),
      ),
      false,
    );
    expect(
      s.world.clearLine(
        s.hero.body.center,
        visible.body.center,
        const Size(3, 3),
      ),
      true,
    );
    areaStrike(s, s.hero.body.center, 250, 100, maxTargets: 3);
    expect(blocked.life.value, 1000);
    expect(visible.life.value, 900);
    expect(
      s.openedChests,
      isNotEmpty,
      reason: 'a prop consumes a slot, not an enemy damage share',
    );
  });
  test('basic cleave applies one shared factor to each selected victim', () {
    s.progress.ranks['cleave'] = 5;
    expect(s.progress.basicTargetLimit, 5);
    final mobs = [enemy(6050), enemy(6075), enemy(6055, 4232)];
    final damage = s.progress.basicDamage;
    s.hero.bearing = 0;
    s.hero.slash();
    for (final mob in mobs) {
      expect(mob.life.value, closeTo(1000 - damage * .7, .000001));
    }
  });
  test('explosion shares one factor across direct and splash damage', () {
    final mobs = [enemy(6050), enemy(6080, 4228), enemy(6110)];
    final bolt = ArcaneBolt(
      s,
      s.hero.body.center,
      0,
      100,
      explosive: true,
      targetLimit: 3,
    );
    for (var i = 0; i < 10; i++) {
      bolt.update(.05);
    }
    expect(bolt.resolved, true);
    expect(mobs[0].life.value, closeTo(930, .000001));
    expect(mobs[1].life.value, closeTo(975.5, .000001));
    expect(mobs[2].life.value, closeTo(975.5, .000001));
  });
  test('seismic cast uses its actual capped impact group', () {
    s.progress.gainXp(8000);
    s.progress.ranks['seismicSlam'] = 1;
    s.progress.selectSkill('seismicSlam');
    s.progress.energy = s.progress.maxEnergy;
    final mobs = [enemy(6050), enemy(6090), enemy(6110), enemy(6220)];
    final damage = s.progress.skillDamage(
      s.progress.skills.firstWhere((d) => d.id == 'seismicSlam'),
    );
    s.hero.skill();
    for (final mob in mobs.take(3)) {
      expect(mob.life.value, closeTo(1000 - damage * .7, .000001));
    }
    expect(mobs.last.life.value, 1000);
  });
  test(
    'meteor computes its damage group at impact and freezes while paused',
    () {
      final mobs = [enemy(6050), enemy(6100)];
      final meteor = MeteorFall(
        s,
        s.hero.body.center,
        const Offset(6100, 4212),
        100,
      );
      meteor.update(.05);
      mobs.add(enemy(6150));
      s.pause();
      for (var i = 0; i < 20; i++) {
        meteor.update(.05);
      }
      expect(meteor.struck, false);
      expect(mobs.every((m) => m.life.value == 1000), true);
      s.resume();
      for (var i = 0; i < 15; i++) {
        meteor.update(.05);
      }
      expect(meteor.struck, true);
      for (final mob in mobs) {
        expect(mob.life.value, closeTo(930, .000001));
      }
    },
  );
  test('chain attenuation and simultaneous group scaling each apply once', () {
    final mobs = [enemy(6050), enemy(6100), enemy(6150)];
    chainLightning(s, s.hero.body.center, 100, 7);
    expect(mobs[0].life.value, closeTo(930, .000001));
    expect(mobs[1].life.value, closeTo(937, .000001));
    expect(mobs[2].life.value, closeTo(943.3, .000001));
  });
  test(
    'whirlwind scales each current pulse but retains the shared cast cap',
    () {
      final mobs = [enemy(6050), enemy(6080), enemy(6110)];
      final pulse = WhirlwindPulse(
        s,
        s.hero,
        100,
        targetLimit: 3,
        duration: .5,
      );
      pulse.update(.05);
      for (final mob in mobs) {
        expect(mob.life.value, closeTo(930, .000001));
      }
      mobs[1].position.x += 1000;
      mobs[2].position.x += 1000;
      final newcomer = enemy(6060);
      for (var i = 0; i < 3; i++) {
        pulse.update(.05);
      }
      expect(pulse.pulses, 2);
      expect(mobs[0].life.value, closeTo(830, .000001));
      expect(mobs[1].life.value, closeTo(930, .000001));
      expect(newcomer.life.value, 1000);
    },
  );
  test(
    'charge groups same-step contacts without changing later contact damage',
    () {
      s.progress.gainXp(8000);
      s.progress.ranks['charge'] = 1;
      s.progress.selectSkill('charge');
      s.progress.energy = s.progress.maxEnergy;
      s.hero.bearing = 0;
      final pair = [enemy(6050), enemy(6050, 4232)];
      final later = enemy(6170);
      s.hero.skill();
      final damage = s.hero.chargeDamage;
      s.hero.update(.05);
      for (final mob in pair) {
        expect(mob.life.value, closeTo(1000 - damage * .8, .000001));
      }
      for (var i = 0; i < 9; i++) {
        s.hero.update(.05);
      }
      expect(later.life.value, closeTo(1000 - damage, .000001));
      for (final mob in pair) {
        expect(mob.life.value, closeTo(1000 - damage * .8, .000001));
      }
    },
  );
}

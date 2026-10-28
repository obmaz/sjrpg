import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  setUp(() {
    s = inCombatField(Adventure(GameArt()))..start(TestGame());
    s.mobs.clear();
    s.waveTime = 10000;
    s.hero.position.setValues(6000, 4200);
    s.hero.bearing = 0;
    s.progress.level = 100;
    s.progress.ranks.addAll({
      'bash': 1,
      'doubleSwing': 1,
      'leap': 1,
      'leapAttack': 1,
    });
    s.progress.energy = s.progress.maxEnergy;
  });
  tearDown(() => s.dispose());
  void step(int frames) {
    for (var i = 0; i < frames; i++) {
      s.hero.update(.05);
    }
  }

  test(
    'leap attack pays once, hits one victim on landing and pauses in flight',
    () {
      s.progress.selectSkill('leapAttack');
      final def = s.progress.skillAt(0)!;
      final scheduled = s.progress.skillCooldown(def);
      final targets = [
        for (var i = 0; i < 4; i++)
          s.spawnEnemy('goblin', Offset(6150 + i * 65, 4200))!
            ..life.initial(100000),
      ];
      final energy = s.progress.energy;
      s.hero.skill();
      s.hero.skill();
      expect(s.progress.energy, energy - s.progress.skillCost(def));
      expect(s.hero.barbarianCombat.airborne, true);
      expect(targets.every((m) => m.life.value == 100000), true);
      expect(s.boardNearbyMount(), false);
      s.pause();
      final from = s.hero.body.topLeft;
      step(10);
      expect(s.hero.body.topLeft, from);
      expect(s.hero.cooldowns[def.id], scheduled);
      s.resume();
      step(20);
      expect(s.hero.barbarianCombat.airborne, false);
      expect(s.hero.position.x, greaterThan(6000));
      expect(targets.where((m) => m.life.value < 100000).length, 1);
      expect(
        targets.first.life.value,
        closeTo(100000 - s.progress.skillDamage(def), .001),
      );
      expect(s.world.blocked(s.hero.body), false);
      expect(s.hero.cooldowns[def.id], closeTo(scheduled - 1, .000001));
      expect(
        GameCheckpoint.capture(s)!.data['cooldowns'][def.id],
        closeTo(scheduled - 1, .000001),
      );
    },
  );
  test(
    'leap stops before world boundaries and rejects other motion during flight',
    () {
      s.progress.selectSkill('leap');
      s.hero.skill();
      expect(s.hero.barbarianCombat.airborne, true);
      s.hero.dodge();
      expect(s.hero.dashing, 0);
      final cost = s.progress.energy;
      s.hero.skill(slot: 1);
      expect(s.progress.energy, cost);
      step(20);
      expect(s.hero.barbarianCombat.airborne, false);
      s.hero.position.setValues(0, 4200);
      s.hero.bearing = math.pi;
      s.hero.cooldowns.clear();
      final before = s.hero.body.topLeft, energy = s.progress.energy;
      s.hero.skill();
      step(20);
      expect(s.hero.body.topLeft, before);
      expect(s.progress.energy, energy);
      expect(s.hero.barbarianCombat.airborne, false);
    },
  );
  test(
    'two physical swings retain a single target per strike and distinct poses',
    () {
      s.progress.selectSkill('doubleSwing');
      final def = s.progress.skillAt(0)!;
      final first = s.spawnEnemy('goblin', const Offset(6050, 4200))!
        ..life.initial(100000);
      final second = s.spawnEnemy('goblin', const Offset(6090, 4200))!
        ..life.initial(100000);
      s.hero.skill();
      expect(s.hero.strikePose, 0);
      expect(
        first.life.value,
        closeTo(100000 - s.progress.skillDamage(def), .001),
      );
      step(6);
      expect(s.hero.strikePose, 1);
      expect(
        first.life.value,
        closeTo(100000 - s.progress.skillDamage(def) * 2, .001),
      );
      expect(second.life.value, 100000);
    },
  );
  test(
    'cancelled aimed leap spends no resource and causes no delayed impact',
    () {
      s.progress.selectSkill('leapAttack');
      final before = s.hero.body.topLeft, energy = s.progress.energy;
      s.hero.beginAim(0);
      step(24);
      s.hero.finishAim(true);
      step(20);
      expect(s.progress.energy, energy);
      expect(s.hero.body.topLeft, before);
      expect(s.hero.cooldowns['leapAttack'], isNull);
      expect(s.hero.barbarianCombat.airborne, false);
    },
  );
  test('reset cancels a paid follow-up without refunding its cooldown', () {
    s.progress.selectSkill('doubleSwing');
    final target = s.spawnEnemy('goblin', const Offset(6050, 4200))!
      ..life.initial(100000);
    s.hero.skill();
    final health = target.life.value,
        cooldown = s.hero.cooldowns['doubleSwing'];
    expect(s.hero.barbarianCombat.busy, true);
    s.progress.awardSkillResetTicket(WorldStage.forest);
    expect(s.resetSkills(), true);
    expect(s.hero.barbarianCombat.busy, false);
    expect(s.hero.cooldowns['doubleSwing'], cooldown);
    step(20);
    expect(target.life.value, health);
  });
}

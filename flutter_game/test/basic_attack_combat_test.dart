import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/combat_feedback.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/sorceress_combat.dart';

import 'basic_selection_test.dart' show train;
import 'support/sorceress_fixture.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field(HeroClass heroClass) {
    final s = Adventure(GameArt(), heroClass: heroClass)..start(TestGame());
    inCombatField(s);
    s.mobs.clear();
    s.progress.gainXp(50000);
    s.hero.bearing = 0;
    s.progress.energy = s.progress.maxEnergy;
    addTearDown(s.dispose);
    return s;
  }

  List<HuntEnemy> pack(Adventure s) => [
    for (final at in [
      const Offset(6050, 4200),
      const Offset(6075, 4228),
      const Offset(6055, 4250),
    ])
      s.spawnEnemy('goblin', at)!..life.initial(10000),
  ];
  for (final mode in ['bash', 'stun']) {
    test(
      '$mode hits one victim and pays its own cost while cleave knows five targets',
      () {
        final s = field(HeroClass.warrior), p = s.progress;
        train(p, 'cleave', 5);
        train(p, mode, 5);
        expect(p.selectSkill(mode), true);
        final skill = p.skills.firstWhere((skill) => skill.id == mode);
        final mobs = pack(s),
            power = p.skillDamage(skill),
            slots = p.skillSlots.toList(),
            points = p.skillPoints,
            energy = p.energy;
        s.hero.skill();
        expect(mobs[0].life.value, closeTo(10000 - power, .00001));
        expect(mobs[1].life.value, 10000);
        expect(mobs[2].life.value, 10000);
        expect(p.basicTargetLimit, 5);
        expect(p.selectedBasic, 'cleave');
        expect(p.skillSlots, slots);
        expect(p.skillPoints, points);
        expect(p.energy, closeTo(energy - p.skillCost(skill), .00001));
        expect(s.hero.cooldowns[mode], p.skillCooldown(skill));
        expect(s.hero.queuedCast, isNull);
        if (mode == 'bash') {
          expect(s.hero.strikePose, 2);
        } else {
          expect(mobs[0].stun, greaterThan(0));
        }
      },
    );
  }
  test('double swing alternates poses on one victim and pays only once', () {
    final s = field(HeroClass.warrior), p = s.progress;
    train(p, 'doubleSwing', 5);
    expect(p.selectSkill('doubleSwing'), true);
    final skill = p.skills.firstWhere((skill) => skill.id == 'doubleSwing');
    final mobs = pack(s), damage = p.skillDamage(skill), energy = p.energy;
    s.hero.skill();
    final pose = s.hero.strikePose;
    expect(mobs[0].life.value, closeTo(10000 - damage, .00001));
    for (var frame = 0; frame < 8; frame++) {
      s.hero.update(.05);
    }
    expect(s.hero.strikePose, isNot(pose));
    expect(mobs[0].life.value, closeTo(10000 - damage * 2, .00001));
    expect(mobs[1].life.value, 10000);
    expect(mobs[2].life.value, 10000);
    expect(p.energy, closeTo(energy - p.skillCost(skill), .00001));
    expect(p.selectedBasic, 'cleave');
  });
  test(
    'switching learned mage basics cannot reset an in-progress attack clock',
    () {
      final s = field(HeroClass.mage), p = s.progress;
      trainSkill(p, 'iceBolt');
      trainSkill(p, 'chargedBolt');
      final mob = pack(s).first;
      s.hero.slash();
      final hp = mob.life.value, clock = s.hero.attackClock;
      final bolts = (s.game! as TestGame).added
          .whereType<SorceressProjectile>()
          .length;
      final mana = p.energy;
      expect(p.selectBasic('iceBolt'), true);
      s.hero.slash();
      expect(s.hero.attackClock, clock);
      expect(mob.life.value, hp);
      expect(
        (s.game! as TestGame).added.whereType<SorceressProjectile>(),
        hasLength(bolts),
      );
      expect(p.energy, mana);
    },
  );
  test('canonical cleave keeps actual three-target damage splitting', () {
    final s = field(HeroClass.warrior), p = s.progress;
    train(p, 'cleave', 5);
    expect(p.basicTargetLimit, 5);
    p.selectBasic('cleave');
    final mobs = pack(s), power = p.basicDamage;
    s.hero.slash();
    for (final mob in mobs) {
      expect(mob.life.value, closeTo(10000 - power * .7, .00001));
    }
  });
  for (final mode in ['iceBolt', 'chargedBolt']) {
    test(
      '$mode selected basic pays D2 mana and resolves individual projectile contacts',
      () {
        final s = field(HeroClass.mage), p = s.progress;
        p.level = 100;
        p.skillPoints = 1000;
        trainSkill(p, mode, 3);
        expect(p.selectBasic(mode), true);
        final skill = p.skills.firstWhere((skill) => skill.id == mode),
            spec = p.sorceressSpell(skill);
        final mobs = [
          for (final at in [
            const Offset(6100, 4200),
            const Offset(6135, 4225),
            const Offset(6160, 4210),
          ])
            s.spawnEnemy('goblin', at)!..life.initial(10000),
        ];
        final energy = p.energy, slots = p.skillSlots.toList();
        s.hero.slash();
        final bolts = (s.game! as TestGame).added
            .whereType<SorceressProjectile>()
            .toList();
        expect(bolts, hasLength(spec.projectileCount));
        expect(
          bolts.every((bolt) => bolt.spec.id == mode && bolt.spec.rank == 3),
          true,
        );
        expect(p.energy, closeTo(energy - spec.manaCost, .00001));
        for (var frame = 0; frame < 45; frame++) {
          for (final bolt in bolts) {
            bolt.update(1 / 30);
          }
        }
        expect(p.skillSlots, slots);
        expect(
          bolts.every((bolt) => bolt.struck.length <= 1),
          true,
          reason:
              'each original bolt has a single contact, not a free chain splash',
        );
        final victims = mobs.where((mob) => mob.life.value < 10000).toList();
        expect(victims, isNotEmpty);
        expect(victims.length, lessThanOrEqualTo(spec.projectileCount));
        if (mode == 'iceBolt') {
          expect(victims, hasLength(1));
          expect(victims.single.slow, greaterThan(0));
          expect(mobs.skip(1).every((mob) => mob.life.value == 10000), true);
        }
      },
    );
  }
  for (final mode in ['bash', 'stun']) {
    test(
      '$mode contact VFX uses its own rank independently of the free basic',
      () async {
        final s = field(HeroClass.warrior), p = s.progress;
        train(p, 'cleave', 2);
        train(p, mode, 5);
        expect(p.rank('cleave'), 2);
        expect(p.selectSkill(mode), true);
        pack(s);
        s.hero.skill();
        await Future<void>.delayed(Duration.zero);
        final spark = (s.game! as TestGame).added
            .whereType<ImpactParticles>()
            .single;
        expect(spark.impact.rank, 5);
        expect(spark.impact.kind, ImpactKind.heavy);
      },
    );
  }
  test(
    'shared proxy projectile preparation cancels on freeze while launched bolts remain physical',
    () {
      final s = field(HeroClass.mage),
          mob = s.spawnEnemy('goblin', const Offset(6120, 4200))!
            ..life.initial(10000);
      final preparing = ArcaneBolt(
        s,
        s.hero.body.center,
        0,
        100,
        launchDelay: .13,
        caster: s.hero,
      );
      expect(s.afflictions.apply(PlayerStatus.freeze), true);
      preparing.update(.05);
      expect(preparing.resolved, true);
      expect(mob.life.value, 10000);
      final launched = ArcaneBolt(
        s,
        s.hero.body.center,
        0,
        100,
        caster: s.hero,
      );
      for (var i = 0; i < 20; i++) {
        launched.update(.05);
      }
      expect(launched.resolved, true);
      expect(mob.life.value, 9900);
    },
  );
}

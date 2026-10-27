import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/combat_feedback.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/rpg_model.dart';

import 'basic_selection_test.dart' show train;
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
  for (final mode in ['quickCut', 'heavyStrike']) {
    test(
      '$mode hits only one enemy even when canonical cleave knows five targets',
      () {
        final s = field(HeroClass.warrior), p = s.progress;
        train(p, 'cleave', 5);
        train(p, mode, 5);
        final mobs = pack(s),
            power = p.basicDamage,
            slots = p.skillSlots.toList(),
            points = p.skillPoints;
        s.hero.slash();
        expect(mobs[0].life.value, closeTo(10000 - power, .00001));
        expect(mobs[1].life.value, 10000);
        expect(mobs[2].life.value, 10000);
        expect(p.skillSlots, slots);
        expect(p.skillPoints, points);
        expect(s.hero.cooldowns, isEmpty);
        expect(s.hero.queuedCast, isNull);
        if (mode == 'heavyStrike') {
          expect(s.hero.strikePose, 2);
          expect(mobs[0].stun, greaterThan(0));
        } else {
          final pose = s.hero.strikePose;
          while (s.hero.attackClock > 0) {
            s.hero.update(.05);
          }
          s.hero.slash();
          expect(s.hero.strikePose, isNot(pose));
        }
      },
    );
  }
  test('switching modes cannot reset an in-progress basic attack clock', () {
    final s = field(HeroClass.warrior), p = s.progress;
    train(p, 'quickCut');
    train(p, 'heavyStrike');
    final mob = pack(s).first;
    s.hero.slash();
    final hp = mob.life.value, clock = s.hero.attackClock;
    p.selectBasic('quickCut');
    s.hero.slash();
    expect(s.hero.attackClock, clock);
    expect(mob.life.value, hp);
  });
  test('canonical cleave keeps actual three-target damage splitting', () {
    final s = field(HeroClass.warrior), p = s.progress;
    train(p, 'cleave', 5);
    expect(p.basicTargetLimit, 3);
    p.selectBasic('cleave');
    final mobs = pack(s), power = p.basicDamage;
    s.hero.slash();
    for (final mob in mobs) {
      expect(mob.life.value, closeTo(10000 - power * .7, .00001));
    }
  });
  for (final mode in ['iceShard', 'sparkBolt']) {
    test(
      '$mode fires its selected element with free basic resource and actual capped splash',
      () {
        final s = field(HeroClass.mage), p = s.progress;
        train(p, mode, 3);
        final mobs = [
          for (final at in [
            const Offset(6100, 4200),
            const Offset(6135, 4225),
            const Offset(6160, 4210),
          ])
            s.spawnEnemy('goblin', at)!..life.initial(10000),
        ];
        final energy = p.energy,
            slots = p.skillSlots.toList(),
            damage = p.basicDamage;
        s.hero.slash();
        final bolt = (s.game! as TestGame).added.whereType<ArcaneBolt>().single;
        expect(bolt.element, mode == 'iceShard' ? 'ice' : 'lightning');
        expect(bolt.rank, 3);
        for (var i = 0; i < 30; i++) {
          bolt.update(.05);
        }
        expect(p.energy, energy);
        expect(p.skillSlots, slots);
        expect(s.hero.cooldowns, isEmpty);
        if (mode == 'iceShard') {
          expect(mobs[0].life.value, closeTo(10000 - damage, .00001));
          expect(mobs[0].slow, 1.5);
          expect(mobs[1].life.value, 10000);
          expect(mobs[2].life.value, 10000);
        } else {
          expect(mobs[0].life.value, closeTo(10000 - damage * .8, .00001));
          expect(
            mobs[1].life.value,
            closeTo(10000 - damage * .35 * .8, .00001),
          );
          expect(mobs[2].life.value, 10000);
        }
      },
    );
  }
  for (final mode in ['quickCut', 'heavyStrike']) {
    test(
      '$mode contact VFX use the selected rank instead of canonical cleave rank',
      () async {
        final s = field(HeroClass.warrior), p = s.progress;
        train(p, 'cleave', 2);
        train(p, mode, 5);
        expect(p.rank('cleave'), 2);
        pack(s);
        s.hero.slash();
        await Future<void>.delayed(Duration.zero);
        final spark = (s.game! as TestGame).added
            .whereType<ImpactParticles>()
            .single;
        expect(spark.impact.rank, 5);
        expect(spark.impact.kind == ImpactKind.heavy, mode == 'heavyStrike');
      },
    );
  }
  test('freeze cancels only a still-preparing basic projectile', () {
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
    final launched = ArcaneBolt(s, s.hero.body.center, 0, 100, caster: s.hero);
    for (var i = 0; i < 20; i++) {
      launched.update(.05);
    }
    expect(launched.resolved, true);
    expect(mob.life.value, 9900);
  });
}

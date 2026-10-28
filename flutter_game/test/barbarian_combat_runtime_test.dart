import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/barbarian_combat.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field(String id, {int rank = 1}) {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    s.mobs.clear();
    s.waveTime = 10000;
    s.hero.bearing = 0;
    s.progress.level = 30;
    s.progress.ranks[id] = rank;
    expect(s.progress.selectSkill(id), true);
    s.progress.energy = s.progress.maxEnergy;
    addTearDown(s.dispose);
    return s;
  }

  HuntEnemy enemy(
    Adventure s, {
    double distance = 80,
    String kind = 'goblin',
  }) =>
      s.spawnEnemy(kind, s.hero.body.center + Offset(distance, 0))!
        ..life.initial(100000);
  SkillDef skill(Adventure s) => s.progress.skillAt(0)!;
  void advance(Adventure s, double duration, {bool enemies = false}) {
    while (duration > 1e-8) {
      final dt = math.min(.02, duration);
      s.tick(dt);
      s.hero.update(dt);
      if (enemies) {
        for (final m in List<HuntEnemy>.of(s.mobs)) {
          m.update(dt);
        }
      }
      duration -= dt;
    }
  }

  for (final id in ['bash', 'stun', 'concentrate', 'berserk']) {
    test('$id strikes one enemy exactly once with its authored damage', () {
      final s = field(id), first = enemy(s);
      final second = enemy(s, distance: 115);
      final damage = s.progress.skillDamage(skill(s));
      final energy = s.progress.energy, cost = s.progress.skillCost(skill(s));
      s.hero.skill();
      expect(first.life.value, closeTo(100000 - damage, .01));
      expect(second.life.value, 100000);
      expect(s.progress.energy, closeTo(energy - cost, 1e-9));
      if (id == 'stun') {
        expect(
          first.stun,
          closeTo(s.progress.barbarianEffectDuration(id), 1e-9),
        );
      }
      advance(s, .5);
      expect(first.life.value, closeTo(100000 - damage, .01));
      expect(s.hero.cooldowns[id], greaterThan(0));
    });
  }

  test(
    'bash damage follows the equipped weapon and impacts only the hit target',
    () {
      final s = field('bash'), first = enemy(s);
      final second = enemy(s, distance: 115);
      final p = s.progress, bash = skill(s);
      final before = p.skillDamage(bash);
      p.equipped[GearSlot.weapon] = Gear(9001, p.weapon.base, power: 100);
      final after = p.skillDamage(bash);
      expect(after, greaterThan(before));
      expect(
        after / p.swordDamage,
        closeTo(1.5 * CombatBalance.skillDamageScale, 1e-9),
      );
      s.hero.skill();
      expect(first.life.value, closeTo(100000 - after, .01));
      expect(second.life.value, 100000);
      final effects = (s.game as TestGame).added
          .whereType<BarbarianCombatVisual>();
      final impact = effects.singleWhere((e) => e.contactImpact);
      expect(Offset(impact.position.x, impact.position.y), first.body.center);
      expect(impact.radius, 24);
    },
  );

  test(
    'a missed bash has a weapon motion without a false contact explosion',
    () {
      final s = field('bash');
      s.hero.skill();
      final effects = (s.game as TestGame).added
          .whereType<BarbarianCombatVisual>();
      expect(effects.where((e) => e.contactImpact), isEmpty);
    },
  );

  test('double swing pays once and performs its second physical hit later', () {
    final s = field('doubleSwing'), m = enemy(s);
    final damage = s.progress.skillDamage(skill(s));
    final energy = s.progress.energy, cost = s.progress.skillCost(skill(s));
    s.hero.skill();
    expect(m.life.value, closeTo(100000 - damage, .01));
    expect(s.hero.barbarianCombat.busy, true);
    advance(s, .3);
    expect(m.life.value, closeTo(100000 - damage * 2, .01));
    expect(s.progress.energy, closeTo(energy - cost, 1e-9));
    expect(s.hero.barbarianCombat.busy, false);
    expect(s.hero.strikePose, 1);
  });

  test(
    'double throw creates two real swept axes that may hit the same enemy',
    () {
      final s = field('doubleThrow'), m = enemy(s, distance: 170);
      final game = s.game as TestGame;
      final damage = s.progress.skillDamage(skill(s));
      s.hero.skill();
      expect(game.added.whereType<BarbarianThrownAxe>().length, 1);
      advance(s, .3);
      final axes = game.added.whereType<BarbarianThrownAxe>().toList();
      expect(axes.length, 2);
      for (var frame = 0; frame < 30; frame++) {
        for (final axe in axes) {
          axe.update(1 / 30);
        }
      }
      expect(axes.every((v) => v.resolved), true);
      expect(m.life.value, closeTo(100000 - 2 * damage, .01));
    },
  );

  for (final id in ['leap', 'leapAttack']) {
    test('$id has airborne motion, safe landing and committed impact', () {
      final s = field(id), m = enemy(s, distance: 180);
      final from = s.hero.body.topLeft;
      final damage = s.progress.skillDamage(skill(s));
      s.hero.skill();
      expect(s.hero.barbarianCombat.airborne, true);
      expect(m.life.value, 100000, reason: 'a jump hits only after landing');
      advance(s, .2);
      expect(s.hero.barbarianCombat.airborneHeight, greaterThan(10));
      expect(s.hero.body.topLeft, isNot(from));
      expect(s.world.blocksEnemy(s.hero.body), false);
      advance(s, .7);
      expect(s.hero.barbarianCombat.airborne, false);
      expect(s.world.blocksEnemy(s.hero.body), false);
      expect(m.body.overlaps(s.hero.body), false);
      expect(
        m.life.value,
        id == 'leap' ? 100000 : closeTo(100000 - damage, .01),
      );
    });
  }

  test('concentrate armor expires and berserk genuinely removes armor', () {
    final s = field('concentrate');
    enemy(s);
    final armor = s.progress.armor;
    s.hero.skill();
    expect(s.progress.armor, greaterThan(armor));
    advance(s, .3);
    expect(s.progress.armor, armor);
    s.progress.ranks['berserk'] = 1;
    s.progress.selectSkill('berserk');
    s.hero.skill();
    expect(s.progress.armor, 0);
    advance(s, 1.6);
    expect(s.progress.armor, armor);
  });

  test(
    'a newly occupied leap destination safely returns to grounded origin',
    () {
      final s = field('leap'), blocker = enemy(s, distance: 300);
      final origin = s.hero.body.topLeft;
      final landing = origin + Offset(s.progress.skillRange(skill(s)), 0);
      expect(s.world.blocksEnemy(landing & s.hero.body.size), false);
      s.hero.skill();
      advance(s, .2);
      blocker.position.setValues(landing.dx, landing.dy);
      advance(s, .8);
      expect(s.hero.barbarianCombat.airborne, false);
      expect(s.hero.body.topLeft, origin);
      expect(s.hero.body.overlaps(blocker.body), false);
      expect(s.world.blocksEnemy(s.hero.body), false);
    },
  );

  test('rank nine double swing is a functional free skill at zero rage', () {
    final s = field('doubleSwing', rank: 9), m = enemy(s);
    s.progress.energy = 0;
    expect(s.progress.skillCost(skill(s)), 0);
    s.hero.skill();
    advance(s, .4);
    expect(m.life.value, lessThan(100000));
    expect(s.progress.energy, 0);
    expect(s.hero.cooldowns['doubleSwing'], greaterThan(0));
  });

  test(
    'leap knockback and hit recovery respect the actual rank target cap',
    () {
      final s = field('leap');
      final destination =
          s.hero.body.center + Offset(s.progress.skillRange(skill(s)), 0);
      final targets = [
        for (var i = 0; i < 7; i++)
          s.spawnEnemy(
            'goblin',
            destination +
                Offset(
                      math.cos(i * math.pi * 2 / 7),
                      math.sin(i * math.pi * 2 / 7),
                    ) *
                    55 -
                const Offset(12, 11),
          )!,
      ];
      s.hero.skill();
      advance(s, .9);
      expect(s.hero.barbarianCombat.airborne, false);
      expect(
        targets.where((m) => m.stun > 0).length,
        s.progress.skillTargetLimit(skill(s)),
      );
      expect(targets.every((m) => m.life.value == m.life.max), true);
    },
  );

  test(
    'throwing mastery strengthens actual axe damage and rolls critical hits',
    () {
      final s = field('doubleThrow');
      final game = s.game as TestGame;
      final plain = s.progress.skillDamage(skill(s));
      s.progress.ranks['swordMastery'] = 20;
      expect(
        s.progress.skillDamage(skill(s)),
        closeTo(plain, 1e-9),
        reason: 'physical mastery must not double-apply to throws',
      );
      s.progress.ranks['throwingMastery'] = 20;
      final mastered = s.progress.skillDamage(skill(s));
      expect(mastered, greaterThan(plain));
      for (var cast = 0; cast < 60; cast++) {
        s.hero.cooldowns.clear();
        s.progress.energy = s.progress.maxEnergy;
        s.hero.skill();
        advance(s, .4);
      }
      final damage = game.added
          .whereType<BarbarianThrownAxe>()
          .map((axe) => axe.damage)
          .toList();
      expect(damage.length, 120);
      expect(damage.any((v) => (v - mastered).abs() < 1e-9), true);
      expect(damage.any((v) => (v - mastered * 2).abs() < 1e-9), true);
      expect(
        damage.every(
          (v) => (v - mastered).abs() < 1e-9 || (v - mastered * 2).abs() < 1e-9,
        ),
        true,
      );
    },
  );

  test(
    'ordinary mastery critical hits propagate their exact damage text style',
    () {
      final s = field('bash'), m = enemy(s);
      s.progress.ranks['swordMastery'] = 20;
      var normal = false, critical = false;
      for (var hit = 0; hit < 80; hit++) {
        s.hero.attackClock = s.hero.castLock = 0;
        final hp = m.life.value;
        s.hero.slash();
        final text = s.texts.last;
        expect(
          hp - m.life.value,
          closeTo(s.progress.basicDamage * (text.critical ? 2 : 1), .001),
        );
        normal |= !text.critical;
        critical |= text.critical;
      }
      expect(normal, true);
      expect(critical, true);
    },
  );

  test('three normal frenzy cooldown cycles can earn all six stacks', () {
    final s = field('frenzy'), m = enemy(s);
    final damage = s.progress.skillDamage(skill(s));
    expect(s.progress.barbarianBuffDuration('frenzy'), 6);
    for (var cast = 0; cast < 3; cast++) {
      s.hero.skill();
      advance(s, .3);
      expect(s.progress.frenzyStacks, (cast + 1) * 2);
      if (cast < 2) {
        advance(s, s.hero.cooldowns['frenzy']! + .001);
        expect(s.hero.cooldowns['frenzy'], 0);
      }
    }
    expect(100000 - m.life.value, closeTo(damage * 6, .001));
    expect(s.progress.frenzyAttackTempo, greaterThan(1));
    advance(s, 6.1);
    expect(s.progress.frenzyStacks, 0);
    expect(s.hero.frenzyTime, 0);
    expect(s.progress.frenzyAttackTempo, 1);
  });

  test(
    'frenzy earns stacks only on actual hits and loses its haste on expiry',
    () {
      final s = field('frenzy'), m = enemy(s);
      s.hero.skill();
      expect(s.progress.frenzyStacks, 1);
      advance(s, .3);
      expect(s.progress.frenzyStacks, 2);
      expect(s.progress.frenzyAttackTempo, greaterThan(1));
      expect(s.progress.frenzyMoveSpeed, greaterThan(135));
      m.life.remove(m.life.value);
      advance(s, s.progress.frenzyDuration + .1);
      expect(s.progress.frenzyStacks, 0);
      expect(s.progress.frenzyAttackTempo, 1);
      s.hero.cooldowns.clear();
      s.hero.skill();
      advance(s, .3);
      expect(s.progress.frenzyStacks, 0);
    },
  );

  test('howl changes real AI into terrain-safe retreat', () {
    final s = field('howl'), m = enemy(s, distance: 110);
    final before = (m.body.center - s.hero.body.center).distance;
    s.hero.skill();
    advance(s, .5, enemies: true);
    expect((m.body.center - s.hero.body.center).distance, greaterThan(before));
    expect(s.world.blocksEnemy(m.body), false);
    expect(m.meleeWindup, 0);
  });

  test('taunt turns a ranged attacker into a weakened melee pursuer', () {
    final s = field('taunt'), m = enemy(s, distance: 220, kind: 'gunner');
    final before = (m.body.center - s.hero.body.center).distance;
    final damage = m.outgoingDamage(10);
    expect(m.usesBolt, true);
    s.hero.skill();
    expect(m.usesBolt, false);
    expect(m.outgoingDamage(10), lessThan(damage));
    advance(s, .5, enemies: true);
    expect((m.body.center - s.hero.body.center).distance, lessThan(before));
  });

  test('battle cry weakens real incoming and outgoing enemy attacks', () {
    final s = field('battleCry'), m = enemy(s);
    final damage = m.outgoingDamage(10);
    s.hero.skill();
    expect(m.outgoingDamage(10), lessThan(damage));
    s.hit(m, 10, Offset.zero);
    expect(100000 - m.life.value, greaterThan(10));
  });

  test(
    'war cry deals split damage and stuns without granting old armor buff',
    () {
      final s = field('warcry'), m = enemy(s);
      final armor = s.progress.armor;
      s.hero.skill();
      expect(m.life.value, lessThan(100000));
      expect(m.stun, greaterThan(0));
      expect(s.progress.armor, armor);
      expect(s.hero.armorTime, 0);
    },
  );

  test(
    'battle orders and command synchronize real stats and expire safely',
    () {
      final s = field('battleOrders');
      final baseHp = s.progress.maxHp, baseResource = s.progress.maxEnergy;
      s.hero.skill();
      expect(s.progress.maxHp, greaterThan(baseHp));
      expect(s.progress.maxEnergy, greaterThan(baseResource));
      s.progress.hp = s.progress.maxHp;
      s.progress.energy = s.progress.maxEnergy;
      advance(s, s.progress.barbarianBuffDuration('battleOrders') + .1);
      expect(s.progress.maxHp, baseHp);
      expect(s.progress.hp, lessThanOrEqualTo(baseHp));
      expect(s.progress.maxEnergy, baseResource);
      expect(s.progress.energy, lessThanOrEqualTo(baseResource));
      s.progress.ranks['battleCommand'] = 1;
      s.progress.selectSkill('battleCommand');
      s.hero.castLock = 0;
      s.hero.skill();
      expect(s.progress.activeSkillBonus, 1);
      expect(s.progress.effectiveRank('battleOrders'), 2);
      expect(
        s.progress.effectiveRank('bash'),
        0,
        reason: 'cannot unlock an unlearned skill',
      );
    },
  );

  test(
    'accepted death records one corpse and find-potion consumes it once',
    () {
      final s = field('findPotion'), m = enemy(s);
      s.hit(m, 200000, Offset.zero);
      expect(s.barbarianUtilities.corpseCount, 1);
      s.hit(m, 200000, Offset.zero);
      expect(s.barbarianUtilities.corpseCount, 1);
      s.hero.skill();
      expect(s.barbarianUtilities.corpseCount, 0);
      final energy = s.progress.energy;
      s.hero.cooldowns.clear();
      s.hero.castLock = 0;
      s.hero.skill();
      expect(s.progress.energy, energy, reason: 'no corpse means no paid cast');
      expect(s.hero.cooldowns['findPotion'], isNull);
    },
  );
}

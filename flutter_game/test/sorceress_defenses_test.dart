import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/sorceress_combat.dart';
import 'package:guardian_new/sorceress_defenses.dart';
import 'package:guardian_new/sorceress_rules.dart';

import 'support/sanctuary_fixture.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  late TestGame game;
  SorceressDefenses defense() => s.hero.sorceressCombat.defenses;
  SkillDef skill(String id) => s.progress.skills.firstWhere((v) => v.id == id);
  void train(String id, [int rank = 1]) {
    final def = skill(id);
    for (final parent in def.requires.entries) {
      if (s.progress.rank(parent.key) < parent.value) {
        train(parent.key, parent.value);
      }
    }
    while (s.progress.rank(id) < rank) {
      expect(
        s.progress.learn(def),
        true,
        reason: '$id rank${s.progress.rank(id) + 1}',
      );
    }
  }

  SorceressSpellStats cast(String id, [int rank = 1]) {
    train(id, rank);
    final stats = s.progress.sorceressSpell(skill(id));
    expect(defense().activate(id, stats), true);
    return stats;
  }

  HuntEnemy enemy([Offset? center]) {
    final m = s.spawnEnemy(
      'goblin',
      (center ?? s.hero.body.center + const Offset(70, 0)) -
          const Offset(12, 11),
    )!;
    m.life.initial(10000);
    return m;
  }

  List<SorceressProjectile> shots() =>
      game.added.whereType<SorceressProjectile>().toList();
  Map<String, dynamic> copy(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
  setUp(() {
    game = TestGame();
    s = inCombatField(
      Adventure(GameArt(), heroClass: HeroClass.mage)..start(game),
    );
    s.mobs.clear();
    s.waveTime = 10000;
    s.progress.level = 100;
    s.progress.skillPoints = 1000;
    s.progress.energy = s.progress.maxEnergy;
    s.progress.hp = s.progress.maxHp;
    s.hero.bearing = 0;
    s.world.openedChests.addAll(List.generate(s.world.chests.length, (i) => i));
  });
  tearDown(() {
    s.dispose();
    s.art.dispose();
  });

  test(
    'all three armor casts replace each other and sync only the active armor',
    () {
      final gearArmor = s.progress.armor;
      for (final id in [
        'frozenArmor',
        'shiverArmor',
        'chillingArmor',
        'frozenArmor',
      ]) {
        final stats = cast(id);
        expect(defense().armorId, id);
        expect(defense().armorTime, stats.duration);
        expect(
          s.progress.armor,
          closeTo(gearArmor * stats.armorMultiplier, 1e-9),
        );
        final buffs = defense().captureState()['buffs'] as List;
        expect(buffs.length, 1);
        expect((buffs.single as Map)['id'], id);
      }
      defense().clear();
      expect(s.progress.armor, gearArmor);
      expect(defense().armorId, isNull);
    },
  );

  test('Frozen Armor freezes a melee attacker without dealing any damage', () {
    final stats = cast('frozenArmor');
    final m = enemy();
    expect(stats.freezeDuration, .48);
    final before = m.life.value;
    defense().onHit(m, melee: true);
    expect(m.life.value, before);
    expect(m.stun, greaterThan(0));
    expect(shots(), isEmpty);
    m.stun = 0;
    defense().onHit(m, melee: false);
    expect(m.life.value, before);
    expect(m.stun, 0);
  });

  test(
    'Shiver Armor deals cold contact retaliation while Chilling Armor returns only ranged bolts',
    () {
      cast('shiverArmor');
      final m = enemy(), hp = m.life.value;
      defense().onHit(m, melee: false);
      expect(m.life.value, hp);
      defense().onMeleeHit(m);
      expect(m.life.value, lessThan(hp));
      expect(m.slow, greaterThan(0));
      expect(shots(), isEmpty);
      cast('chillingArmor');
      final afterShiver = m.life.value;
      defense().onHit(m, melee: true);
      expect(m.life.value, afterShiver);
      expect(shots(), isEmpty);
      defense().onHit(m, melee: false);
      expect(shots().length, 1);
      expect(
        m.life.value,
        afterShiver,
        reason: 'returning ice must actually travel',
      );
      for (var frame = 0; frame < 20; frame++) {
        for (final shot in shots()) {
          shot.update(.02);
        }
      }
      expect(m.life.value, lessThan(afterShiver));
    },
  );

  test(
    'only Shiver Armor retaliates when an actual melee strike is dodged',
    () {
      final m = enemy(s.hero.body.center + const Offset(36, 0));
      for (final id in ['frozenArmor', 'shiverArmor']) {
        cast(id);
        m.life.update(m.life.max);
        m.stun = m.hurt = m.slow = 0;
        m.bearing = math.pi;
        m.meleeWindup = .01;
        s.hero.invulnerable = 1;
        final hp = s.progress.hp, enemyHp = m.life.value;
        m.update(.02);
        expect(s.progress.hp, hp, reason: 'the hero dodges the actual strike');
        if (id == 'shiverArmor') {
          expect(
            m.life.value,
            lessThan(enemyHp),
            reason: 'original attackedinmelee trigger includes misses',
          );
        } else {
          expect(m.life.value, enemyHp);
          expect(m.stun, 0, reason: 'damagedinmelee requires a successful hit');
        }
      }
    },
  );

  test('an accepted melee strike triggers Shiver retaliation exactly once', () {
    final stats = cast('shiverArmor');
    final m = enemy(s.hero.body.center + const Offset(36, 0));
    m.bearing = math.pi;
    m.meleeWindup = .01;
    s.hero.invulnerable = 0;
    final hp = s.progress.hp, enemyHp = m.life.value;
    m.update(.02);
    expect(s.progress.hp, lessThan(hp));
    expect(enemyHp - m.life.value, closeTo(stats.retaliationDamage, 1e-8));
  });

  test(
    'actual incoming damage pays Energy Shield mana before armor mitigation',
    () {
      cast('frozenArmor');
      final es = cast('energyShield');
      final m = enemy();
      s.progress.energy = 50;
      s.hero.invulnerable = 0;
      final hp = s.progress.hp;
      // ES requires Teleport and therefore one real Telekinesis point: 31/16.
      expect(s.progress.rank('telekinesis'), 1);
      expect(es.shieldAbsorb, closeTo(.08, 1e-9));
      final remainingRaw = 20 * (1 - .08);
      final expectedHpLoss = s.progress.mitigate(remainingRaw);
      s.hurtHero(20, origin: m.body.center);
      expect(s.progress.energy, closeTo(50 - 20 * .08 * 31 / 16, 1e-9));
      expect(s.progress.hp, closeTo(hp - expectedHpLoss, 1e-9));
      expect(m.stun, greaterThan(0));
    },
  );

  test(
    'hard Telekinesis points improve original mana efficiency and exhaustion passes remainder to HP',
    () {
      expect(
        SorceressRules.evaluate(
          'energyShield',
          rank: 20,
          hardRanks: const {},
        ).manaPerDamage,
        2,
      );
      train('telekinesis', 20);
      final es = cast('energyShield', 20);
      expect(es.manaPerDamage, .75);
      expect(es.shieldAbsorb, .75);
      s.progress.energy = 15;
      expect(defense().modifyIncomingDamage(100), closeTo(80, 1e-9));
      expect(s.progress.energy, 0);
      expect(defense().energyShieldTime, 0);
      expect(defense().modifyIncomingDamage(100), 100);
    },
  );

  test(
    'poison bypasses Energy Shield without consuming mana or ending the buff',
    () {
      cast('energyShield', 20);
      final time = defense().energyShieldTime, energy = s.progress.energy;
      expect(defense().modifyIncomingDamage(25, periodic: true), 25);
      expect(s.progress.energy, energy);
      final hp = s.progress.hp, expected = s.progress.mitigate(5);
      s.hurtHero(5, periodic: true);
      expect(s.progress.hp, closeTo(hp - expected, 1e-9));
      expect(s.progress.energy, energy);
      expect(defense().energyShieldTime, time);
    },
  );

  test(
    'Energy Shield defensive absorption is capped at95 percent even for an over-cap supplied snapshot',
    () {
      train('energyShield', 20);
      expect(
        defense().activate(
          'energyShield',
          const SorceressSpellStats(
            id: 'energyShield',
            rank: 20,
            damageType: SorceressDamageType.lightning,
            duration: 10,
            damageAbsorb: 2,
            shieldManaPerDamage: 1,
          ),
        ),
        true,
      );
      s.progress.energy = 90;
      expect(defense().modifyIncomingDamage(20), closeTo(1, 1e-9));
      expect(s.progress.energy, closeTo(71, 1e-9));
    },
  );

  test(
    'source long-lived buffs keep their duration through pause and expire in simulation time',
    () {
      for (final id in [
        'frozenArmor',
        'energyShield',
        'enchant',
        'thunderStorm',
      ]) {
        final stats = cast(id);
        expect(stats.duration, greaterThan(math.max(30, stats.castDelay)));
      }
      final snapshot = defense().captureState();
      s.paused = true;
      defense().update(1000);
      expect(defense().captureState(), snapshot);
      s.paused = false;
      defense().update(1.25);
      final updated = defense().captureState()['buffs'] as List;
      for (final original in snapshot['buffs'] as List) {
        final now = updated.cast<Map>().firstWhere(
          (v) => v['id'] == (original as Map)['id'],
        );
        expect(
          now['remaining'],
          closeTo((original['remaining'] as num) - 1.25, 1e-9),
        );
      }
      defense().update(1000);
      expect(defense().hasBuffs, false);
      expect(s.progress.sorceressArmorMultiplier, 1);
    },
  );

  test(
    'Thunder Storm chooses only one target and never replays paused or long-frame backlog',
    () {
      final stats = cast('thunderStorm', 20);
      final mobs = [
        enemy(s.hero.body.center + const Offset(90, 0)),
        enemy(s.hero.body.center + const Offset(0, 90)),
        enemy(s.hero.body.center + const Offset(-90, 0)),
      ];
      s.paused = true;
      defense().update(30);
      expect(mobs.every((m) => m.life.value == 10000), true);
      s.paused = false;
      defense().update(10);
      expect(mobs.where((m) => m.life.value < 10000).length, 1);
      final total = mobs.fold<double>(0, (sum, m) => sum + m.life.value);
      defense().update(stats.interval / 2);
      expect(mobs.fold<double>(0, (sum, m) => sum + m.life.value), total);
    },
  );

  test(
    'actual static field walls prevent retaliation and Thunder Storm target acquisition',
    () {
      cast('chillingArmor');
      cast('thunderStorm');
      HuntEnemy? behind;
      for (final prop in s.world.props) {
        for (final solid in prop.collisionBodies) {
          final from =
              Offset(solid.left - 35, solid.center.dy) - const Offset(14, 12);
          final to =
              Offset(solid.right + 35, solid.center.dy) - const Offset(12, 11);
          if (s.world.blocksEnemy(from & const Size(28, 24)) ||
              s.world.blocksEnemy(to & const Size(24, 22)) ||
              s.world.clearEnemyLine(
                (from & const Size(28, 24)).center,
                (to & const Size(24, 22)).center,
                const Size(3, 3),
              )) {
            continue;
          }
          s.hero.position.setValues(from.dx, from.dy);
          behind = s.spawnEnemy('goblin', to)!..life.initial(10000);
          break;
        }
        if (behind != null) break;
      }
      expect(
        behind,
        isNotNull,
        reason: 'use an actual authored field prop, not a fake LOS stub',
      );
      expect(s.sheltered, false);
      defense().onHit(behind!, melee: false);
      defense().update(10);
      expect(behind.life.value, 10000);
      expect(shots(), isEmpty);
    },
  );

  test(
    'moving inside the real village gate denies both Storm and armor retaliation',
    () {
      cast('chillingArmor');
      cast('thunderStorm');
      final gate = safetyGate(s.world);
      s.hero.position.setValues(
        gate.boundary.dx - 18 - 14,
        gate.boundary.dy - 12,
      );
      expect(s.world.blocked(s.hero.body), false);
      expect(s.sheltered, true);
      final m = enemy(gate.boundary + gate.outward * 70);
      defense().onHit(m, melee: false);
      defense().update(10);
      expect(m.life.value, 10000);
      expect(shots(), isEmpty);
    },
  );

  test(
    'Enchant stays a weapon buff without enabling a removed staff basic or buffing spells',
    () {
      final spec = cast('enchant');
      expect(spec.enchantFireMin, greaterThan(0));
      expect(s.progress.selectBasic('sorceressAttack'), false);
      expect(s.progress.selectSkill('firebolt'), true);
      final firebolt = s.progress.sorceressSpell(skill('firebolt'));
      s.hero.castLock = s.hero.attackClock = s.hero.swing = 0;
      s.hero.skill();
      final shot = shots().last;
      expect(
        shot.damageAmount,
        inInclusiveRange(firebolt.minDamage, firebolt.maxDamage),
      );
    },
  );

  test(
    'forged defense saves are rejected transactionally without altering current buffs',
    () {
      cast('frozenArmor');
      final valid = defense().captureState();
      train('shiverArmor');
      final variants = <Map<String, dynamic>>[];
      for (final change in <void Function(Map<String, dynamic>)>[
        (m) => m['version'] = 2,
        (m) => (m['buffs'] as List).add({
          'id': 'shiverArmor',
          'rank': 1,
          'remaining': 1,
        }),
        (m) => (m['buffs'] as List).add({
          'id': 'frozenArmor',
          'rank': 1,
          'remaining': 1,
        }),
        (m) => ((m['buffs'] as List).first as Map)['id'] = 'enchant',
        (m) => ((m['buffs'] as List).first as Map)['rank'] = 21,
        (m) => ((m['buffs'] as List).first as Map)['remaining'] = 999999,
        (m) => ((m['buffs'] as List).first as Map)['remaining'] = double.nan,
        (m) => m['thunderClock'] = 1,
      ]) {
        final bad = copy(valid);
        change(bad);
        variants.add(bad);
      }
      for (final bad in variants) {
        expect(SorceressDefenses.validateState(bad, s.progress), isNull);
        expect(defense().restoreState(bad), false);
        expect(defense().captureState(), valid);
      }
      expect(SorceressDefenses.validateState(valid, Progress()), isNull);
    },
  );

  test(
    'restored cast rank and lifetimes recompute armor and Thunder Storm clock without refreshing',
    () {
      final armor = cast('frozenArmor');
      cast('thunderStorm');
      defense().update(.5);
      final saved = defense().captureState();
      train('frozenArmor', 20);
      defense().clear();
      expect(defense().restoreState(saved), true);
      expect(defense().armorMultiplier, armor.armorMultiplier);
      expect(s.progress.sorceressArmorMultiplier, armor.armorMultiplier);
      expect(defense().captureState(), saved);
      defense().update(.25);
      expect(defense().armorTime, closeTo(armor.duration - .75, 1e-9));
      s.progress.ranks['frozenArmor'] = 0;
      defense().update(.01);
      expect(defense().armorId, isNull);
      expect(s.progress.sorceressArmorMultiplier, 1);
    },
  );
}

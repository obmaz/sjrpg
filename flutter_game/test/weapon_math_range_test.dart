import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/area_damage.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/combat_numbers.dart';
import 'package:guardian_new/equipment_panel.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/sorceress_combat.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Adventure field(HeroClass heroClass, [String? weapon]) {
    final s = inCombatField(Adventure(GameArt(), heroClass: heroClass))
      ..start(TestGame());
    s.mobs.clear();
    s.waveTime = 10000;
    if (weapon != null) {
      final gear = s.progress.createGear(gearById(weapon));
      s.progress.inventory.add(gear);
      expect(s.progress.equip(gear), true);
    }
    addTearDown(s.dispose);
    return s;
  }

  void train(Progress p, String id, [int rank = 1]) {
    final skill = p.skills.firstWhere((skill) => skill.id == id);
    for (final need in skill.requires.entries) {
      train(p, need.key, need.value);
    }
    while (p.rank(id) < rank) {
      expect(p.learn(skill), true, reason: '$id rank$rank');
    }
  }

  test(
    'raw weapon attack, mastery-adjusted attack, hit and base DPS are distinct and exact',
    () {
      final p = Progress();
      expect(p.weapon.attack, 15);
      expect(p.swordDamage, closeTo(9.5625, 1e-10));
      expect(p.basicDamage, closeTo(5.7375, 1e-10));
      expect(p.attackInterval, closeTo(.34 / .30, 1e-10));
      expect(p.basicDps, closeTo(6.075, 1e-10));
      final mage = Progress(heroClass: HeroClass.mage);
      expect(mage.weapon.attack, 14);
      expect(
        mage.basicDamage,
        closeTo(
          4.5 *
              .6 * // One-point spells use 60% of their source damage.
              Progress.playerDamageScale *
              CombatBalance.skillDamageScale *
              CombatBalance.sorceressDamageScale,
          1e-10,
        ),
      );
      expect(mage.attackInterval, .52);
      expect(
        mage.basicDps,
        closeTo(mage.basicDamage / .52 * CombatBalance.gameSpeed, 1e-10),
      );
    },
  );

  test(
    'real attack cooldowns and expected critical DPS match every basic mode and tempo state',
    () {
      for (final hero in HeroClass.values) {
        final s = field(hero), p = s.progress;
        p.level = 100;
        p.skillPoints = 1000;
        if (hero == HeroClass.warrior) {
          train(p, 'swordMastery', 5);
          train(p, 'frenzy', 5);
        } else {
          train(p, 'fireMastery', 5);
        }
        for (final basic in p.basicSkills) {
          train(p, basic.id, math.min(5, basic.rankLimit));
          expect(p.selectBasic(basic.id), true);
          for (final state in ['normal', 'frenzy', 'slow', 'both']) {
            final frenzy =
                hero == HeroClass.warrior &&
                (state == 'frenzy' || state == 'both');
            final slowed = state == 'slow' || state == 'both';
            p.energy = p.maxEnergy;
            s.afflictions.clear();
            if (slowed) s.afflictions.apply(PlayerStatus.attackSlow);
            s.hero
              ..resetCombo()
              ..attackClock = 0
              ..castLock = 0
              ..frenzyTime = frenzy ? 10 : 0;
            p.frenzyStacks = frenzy ? 6 : 0;
            final tempo = frenzy ? p.frenzyAttackTempo : 1.0;
            final stats = p.basicAttackStats(
              frenzyTempo: tempo,
              attackTempo: s.afflictions.attackTempo,
            );
            final expected =
                (p.isSorceressSpell(basic)
                    ? p.skillMotionTime(basic)
                    : math.max(.4, p.attackInterval / tempo)) /
                (slowed ? .72 : 1);
            s.hero.slash();
            expect(
              stats.interval,
              closeTo(expected / CombatBalance.gameSpeed, 1e-9),
              reason: '${basic.id} $state',
            );
            expect(s.hero.attackClock, closeTo(expected, 1e-9));
            expect(s.hero.castLock, lessThanOrEqualTo(expected));
            final criticalChance = hero == HeroClass.warrior
                ? p.weaponCriticalChance
                : 0.0;
            expect(stats.damage, p.basicDamage);
            expect(stats.criticalChance, criticalChance);
            expect(
              stats.dps,
              closeTo(
                p.basicDamage *
                    (1 + criticalChance) /
                    expected *
                    CombatBalance.gameSpeed,
                1e-9,
              ),
            );
          }
        }
      }
    },
  );

  test(
    'candidate DPS includes buffs, selected basic and all other gear without mutating progress',
    () {
      final p = Progress()
        ..level = 100
        ..skillPoints = 1000;
      train(p, 'cleave', 3);
      train(p, 'bash');
      train(p, 'swordMastery', 2);
      train(p, 'spearMastery', 4);
      expect(p.selectBasic('cleave'), true);
      expect(p.selectSkill('bash'), true);
      final candidate = p.createGear(
        gearById('spear'),
        rarity: Rarity.magic,
        power: 4,
      );
      p.inventory.add(candidate);
      final saved = jsonEncode(p.toSave());
      final preview = p.previewBasicAttack(
        candidate,
        frenzyTempo: 1.14,
        attackTempo: .72,
      )!;
      expect(jsonEncode(p.toSave()), saved);
      final copy = Progress.fromSave(p.toSave())!;
      expect(
        copy.equip(
          copy.inventory.firstWhere((g) => g.serial == candidate.serial),
        ),
        true,
      );
      final actual = copy.basicAttackStats(frenzyTempo: 1.14, attackTempo: .72);
      expect(preview.damage, actual.damage);
      expect(preview.interval, actual.interval);
      expect(preview.dps, actual.dps);
      expect(p.previewBasicAttack(p.createGear(gearById('wand'))), isNull);
      expect(() => p.actualBasicInterval(attackTempo: 0), throwsArgumentError);
      expect(
        () => p.actualBasicInterval(frenzyTempo: double.nan),
        throwsArgumentError,
      );
    },
  );

  test(
    'long melee weapons aim at their true reach even from the opposite facing',
    () {
      for (final id in ['mace', 'halberd']) {
        final s = field(HeroClass.warrior, id);
        final from = s.hero.body.center;
        final mob = s.spawnEnemy('goblin', from + const Offset(190, 0))!
          ..life.initial(1000);
        mob.position.setValues(from.dx + 178, from.dy - mob.size.y / 2);
        expect(
          s.world.clearLine(from, mob.body.center, const ui.Size(3, 3)),
          true,
        );
        s.hero.bearing = math.pi;
        s.hero.slash();
        expect(mob.life.value < 1000, id == 'halberd', reason: id);
        if (id == 'halberd') expect(s.hero.attackBearing, closeTo(0, 1e-8));
      }
    },
  );

  test(
    'thrusting and sweeping weapons differ in width as well as distance',
    () {
      for (final id in ['rapier', 'glaive']) {
        final s = field(HeroClass.warrior, id);
        final at = s.hero.body.center;
        s.progress.ranks['cleave'] = 5;
        final front = s.spawnEnemy('goblin', at + const Offset(50, 0))!
          ..life.initial(1000);
        front.position.setValues(at.dx + 38, at.dy - 12);
        final side = s.spawnEnemy(
          'goblin',
          at + Offset(math.cos(.65), math.sin(.65)) * 140,
        )!..life.initial(1000);
        side.position.setValues(
          at.dx + math.cos(.65) * 140 - 12,
          at.dy + math.sin(.65) * 140 - 12,
        );
        s.hero.bearing = 0;
        s.hero.slash();
        expect(front.life.value, lessThan(1000));
        expect(side.life.value < 1000, id == 'glaive', reason: id);
      }
      expect(
        distanceToTargetBody(
          Offset.zero,
          const ui.Rect.fromLTWH(20, 100, 80, 20),
        ),
        closeTo(math.sqrt(10400), 1e-9),
      );
    },
  );

  test(
    'Sorceress spell range is intrinsic and remains independent of equipped staff statistics',
    () {
      final ranges = <double>{}, attacks = <double>{};
      for (final def in gearCatalog.where(
        (g) => g.slot == GearSlot.weapon && g.heroClass == HeroClass.mage,
      )) {
        final s = field(HeroClass.mage, def.id), game = s.game! as TestGame;
        s.hero.slash();
        final bolt = game.added.whereType<SorceressProjectile>().single;
        expect(
          bolt.range,
          s.progress.sorceressSpell(s.progress.basicSkill).range,
        );
        expect(bolt.range, 450);
        ranges.add(bolt.range);
        attacks.add(s.progress.weapon.attack);
      }
      expect(ranges, {450});
      expect(attacks.length, greaterThan(1));
      final s = field(HeroClass.mage), from = s.hero.body.center;
      final bolt = SorceressProjectile(
        s.hero.sorceressCombat,
        s.progress.sorceressSpell(s.progress.basicSkill),
        from,
        bearing: 0,
        damageAmount: 1,
        rangeOverride: 180,
      );
      for (var i = 0; i < 20 && !bolt.finished; i++) {
        bolt.update(.05);
      }
      expect(bolt.finished, true);
      expect(bolt.travelled, closeTo(180, .01));
      expect(
        (ui.Offset(bolt.position.x, bolt.position.y) - from).distance,
        closeTo(180, .01),
      );
    },
  );

  test(
    'area growth is sublinear and preserves the requested 100/80/70 values',
    () {
      var previousTotal = 0.0;
      for (var count = 1; count <= 32; count++) {
        final each = 100 * enemyGroupDamageScale(count), total = count * each;
        expect(each, lessThanOrEqualTo(100));
        if (count > 1) expect(total - previousTotal, lessThan(100));
        expect(total, greaterThan(previousTotal));
        previousTotal = total;
      }
      expect(100 * enemyGroupDamageScale(1), 100);
      expect(100 * enemyGroupDamageScale(2), closeTo(80, 1e-10));
      expect(100 * enemyGroupDamageScale(3), closeTo(70, 1e-10));
    },
  );

  testWidgets('equipment comparisons show current frenzy and attack-slow DPS', (
    tester,
  ) async {
    final s = field(HeroClass.warrior), p = s.progress;
    s.pause();
    p.level = 100;
    p.skillPoints = 1000;
    train(p, 'frenzy', 5);
    p.frenzyStacks = 6;
    s.hero.frenzyTime = 10;
    s.afflictions.apply(PlayerStatus.attackSlow);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentPanel(session: s, onClose: () {}),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.bySemanticsLabel(RegExp('보관 장비 · ${p.weapon.name}'));
    final hint = tester.getSemantics(row).getSemanticsData().hint;
    final expected = CombatNumbers.stat(
      p
          .basicAttackStats(frenzyTempo: p.frenzyAttackTempo, attackTempo: .72)
          .dps,
    );
    expect(hint, contains('현재 초당 피해 $expected'));
    expect(hint, isNot(contains('현재 초당 피해 ${CombatNumbers.stat(p.basicDps)}')));
    semantics.dispose();
  });
}

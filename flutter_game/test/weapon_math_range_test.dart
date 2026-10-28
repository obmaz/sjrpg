import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/area_damage.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/equipment_panel.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/rpg_model.dart';

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

  test(
    'raw weapon attack, mastery-adjusted attack, hit and base DPS are distinct and exact',
    () {
      final p = Progress();
      expect(p.weapon.attack, 15);
      expect(p.swordDamage, closeTo(9.5625, 1e-10));
      expect(p.basicDamage, closeTo(5.7375, 1e-10));
      expect(p.attackInterval, closeTo(.34 / .30, 1e-10));
      expect(p.basicDps, closeTo(5.0625, 1e-10));
      final mage = Progress(heroClass: HeroClass.mage);
      expect(mage.weapon.attack, 14);
      expect(mage.basicDamage, closeTo(5.355, 1e-10));
      expect(mage.basicDps, closeTo(3.825, 1e-10));
    },
  );

  test(
    'real attack cooldowns match reported single-hit DPS for every basic mode and tempo state',
    () {
      for (final hero in HeroClass.values) {
        final s = field(hero), p = s.progress;
        p.level = 30;
        p.ranks.addAll({'battleFocus': 5, 'weaponTempo': 5, 'frenzy': 5});
        for (final basic in p.skills.where((skill) => skill.basic)) {
          p.ranks[basic.id] = 5;
          expect(p.selectBasic(basic.id), true);
          for (final state in ['normal', 'frenzy', 'slow', 'both']) {
            final frenzy =
                hero == HeroClass.warrior &&
                (state == 'frenzy' || state == 'both');
            final slowed = state == 'slow' || state == 'both';
            s.afflictions.clear();
            if (slowed) s.afflictions.apply(PlayerStatus.attackSlow);
            s.hero
              ..resetCombo()
              ..attackClock = 0
              ..castLock = 0
              ..frenzyTime = frenzy ? 10 : 0;
            final tempo = frenzy ? p.frenzyAttackTempo : 1.0;
            final stats = p.basicAttackStats(
              frenzyTempo: tempo,
              attackTempo: s.afflictions.attackTempo,
            );
            final expected =
                math.max(.4, p.attackInterval / tempo) / (slowed ? .72 : 1);
            s.hero.slash();
            expect(
              stats.interval,
              closeTo(expected, 1e-9),
              reason: '${basic.id} $state',
            );
            expect(s.hero.attackClock, closeTo(stats.interval, 1e-9));
            expect(s.hero.castLock, lessThanOrEqualTo(stats.interval));
            expect(stats.dps, closeTo(p.basicDamage / expected, 1e-9));
          }
        }
      }
    },
  );

  test(
    'candidate DPS includes buffs, selected basic and all other gear without mutating progress',
    () {
      final p = Progress()..level = 10;
      p.ranks.addAll({
        'cleave': 3,
        'mastery': 2,
        'heavyStrike': 3,
        'battleFocus': 4,
      });
      expect(p.selectBasic('heavyStrike'), true);
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

  test('each mage weapon supplies its actual projectile travel limit', () {
    final ranges = <double>{};
    for (final def in gearCatalog.where(
      (g) => g.slot == GearSlot.weapon && g.heroClass == HeroClass.mage,
    )) {
      final s = field(HeroClass.mage, def.id), game = s.game! as TestGame;
      s.hero.slash();
      final bolt = game.added.whereType<ArcaneBolt>().single;
      expect(bolt.maxRange, def.range);
      expect(bolt.remaining, closeTo(def.range / ArcaneBolt.speed, 1e-10));
      ranges.add(def.range);
    }
    expect(ranges.length, 6);
    final s = field(HeroClass.mage), from = s.hero.body.center;
    final bolt = ArcaneBolt(s, from, 0, 1, maxRange: 180);
    for (var i = 0; i < 20 && !bolt.resolved; i++) {
      bolt.update(.05);
    }
    expect(bolt.resolved, true);
    expect(
      (ui.Offset(bolt.position.x, bolt.position.y) - from).distance,
      closeTo(180, .01),
    );
  });

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
    p.ranks['frenzy'] = 5;
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
    final expected = p
        .basicAttackStats(frenzyTempo: p.frenzyAttackTempo, attackTempo: .72)
        .dps
        .toStringAsFixed(1);
    expect(hint, contains('현재 초당 피해 $expected'));
    expect(hint, isNot(contains('현재 초당 피해 ${p.basicDps.toStringAsFixed(1)}')));
    semantics.dispose();
  });
}

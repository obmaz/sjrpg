import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_numbers.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'combat stats use1000 units and resources use10 with readable grouping',
    () {
      expect(CombatNumbers.stat(1), '1,000');
      expect(CombatNumbers.stat(35), '35,000');
      expect(CombatNumbers.stat(100), '100,000');
      expect(CombatNumbers.stat(.4), '400');
      expect(CombatNumbers.stat(-1.234), '-1,234');
      expect(CombatNumbers.resource(100), '1,000');
      expect(CombatNumbers.resource(6), '60');
      expect(CombatNumbers.resource(.65, digits: 2), '6.5');
      expect(CombatNumbers.stat(double.nan), '—');
    },
  );
  test(
    'current resource floors after conversion and positive health can ceil',
    () {
      expect(
        CombatNumbers.resource(25.75, rounding: CombatRounding.down),
        '257',
      );
      expect(CombatNumbers.stat(.0002, rounding: CombatRounding.up), '1');
      expect(CombatNumbers.stat(-.00001), '0');
    },
  );
  test('damage and resource ratios survive the denomination exactly', () {
    const hp = 326.0, damage = 35.0, mana = 90.0, cost = 6.5;
    expect(
      (CombatNumbers.value(hp, CombatUnit.stat) /
              CombatNumbers.value(damage, CombatUnit.stat))
          .ceil(),
      (hp / damage).ceil(),
    );
    expect(
      CombatNumbers.value(mana, CombatUnit.resource) /
          CombatNumbers.value(cost, CombatUnit.resource),
      mana / cost,
    );
    for (final unit in CombatUnit.values) {
      expect(CombatNumbers.value(35.5, unit) / unit.scale, 35.5);
    }
  });
  test(
    'real fractional hits show their applied damage before integer rounding',
    () {
      final s = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(s.dispose);
      final mob = s.spawnEnemy(
        'goblin',
        s.hero.body.center + const Offset(100, 0),
      )!;
      mob.life.initial(100);
      expect(s.hit(mob, .4, Offset.zero), true);
      final actual = 100 - mob.life.value;
      expect(actual, greaterThan(0));
      final number = s.texts.last;
      expect(number.combatAmount, closeTo(actual, 1e-8));
      expect(number.displayLabel, CombatNumbers.stat(actual));
      expect(number.displayLabel, isNot('0'));
      expect(number.isReward, false);
    },
  );
  test('reward quantities keep their own units while damage is normalized', () {
    final s = Adventure(GameArt());
    addTearDown(s.dispose);
    final damage = BattleText(s, '1', Offset.zero, const Color(0xffffdd77));
    final gold = BattleText(s, '+1 골드', Offset.zero, const Color(0xffffdd77));
    expect(damage.displayLabel, '1,000');
    expect(gold.displayLabel, '+1 골드');
  });
  test(
    'an old canonical save keeps health, costs, equipment and resource fractions on every reload',
    () {
      for (final hero in HeroClass.values) {
        final p = Progress(heroClass: hero)..level = 30;
        p.hp = p.maxHp * .375;
        p.energy = 25.75;
        final before = jsonEncode(p.toSave());
        for (final skill in p.skills) {
          for (final row in previewSkill(p, skill)) {
            row.format(row.current);
            row.format(row.next);
          }
        }
        for (final gear in p.inventory) {
          expect(gear.stats, isNotEmpty);
        }
        expect(jsonEncode(p.toSave()), before);
        final once = Progress.fromSave(jsonDecode(before))!;
        final twice = Progress.fromSave(once.toSave())!;
        expect(twice.hp, p.hp);
        expect(twice.maxHp, p.maxHp);
        expect(twice.energy, 25.75);
        expect(twice.weapon.attack, p.weapon.attack);
        expect(twice.basicAttackStats().damage, p.basicAttackStats().damage);
      }
    },
  );
  test(
    'spell previews distinguish mana, damage, counts, durations and percentages',
    () {
      final p = Progress(heroClass: HeroClass.mage)..level = 100;
      for (final skill in p.skills) {
        p.ranks[skill.id] = 5;
      }
      for (final skill in p.skills) {
        final rows = previewSkill(p, skill);
        for (final row in rows) {
          if (['%', '초', '명', '개', '걸음', '걸음/초'].contains(row.suffix)) {
            expect(row.unit, null, reason: '${skill.id}: ${row.label}');
          }
          if (row.label == '마나 소모' ||
              row.label == '유지 마나' ||
              row.label == '마나 회복') {
            expect(row.unit, CombatUnit.resource);
          }
          if (row.label.endsWith('최소 피해') ||
              row.label.endsWith('최대 피해') ||
              row.label == '투사체 1개 초당 피해') {
            expect(row.unit, CombatUnit.stat);
          }
        }
      }
      final shield = p.skills.firstWhere((s) => s.id == 'energyShield');
      final exchange = previewSkill(
        p,
        shield,
      ).singleWhere((r) => r.label == '피해 1,000당 마나');
      expect(exchange.unit, CombatUnit.resource);
      expect(exchange.current, p.sorceressSpell(shield).shieldManaPerDamage);
      expect(
        CombatNumbers.value(exchange.current, CombatUnit.resource) / 1000,
        exchange.current / 100,
      );
    },
  );
}

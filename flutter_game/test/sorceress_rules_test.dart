import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/sorceress_rules.dart';

void main() {
  final fixture =
      jsonDecode(
            File('test/fixtures/diablo2_sorceress_113.json').readAsStringSync(),
          )
          as Map;
  final original = fixture['skills'] as Map;
  final scale = Progress.playerDamageScale * CombatBalance.skillDamageScale;

  test(
    'all thirty spells retain original first and twentieth-rank mana and delays',
    () {
      expect(mageSkills.map((s) => s.id).toSet(), original.keys.toSet());
      for (final skill in mageSkills) {
        final source = original[skill.id] as Map;
        for (final rank in [1, 20]) {
          final stats = SorceressRules.evaluate(
            skill.id,
            rank: rank,
            hardRanks: const {},
          );
          final mana = source['mana'] as Map;
          if (skill.id == 'inferno') {
            expect(stats.manaCost, 0);
            expect(stats.minimumStartMana, 6);
            final expected = rank == 1 ? 7.03125 : 10.7421875;
            expect(stats.manaPerSecond, expected);
          } else {
            expect(
              stats.manaCost,
              mana[rank == 1 ? 'first' : 'rank20'],
              reason: '${skill.id} rank$rank',
            );
          }
          expect(
            stats.castDelay,
            (source['delay'] as Map)['seconds'],
            reason: skill.id,
          );
          expect(stats.timerGroup.isNotEmpty, stats.castDelay > 0);
        }
      }
    },
  );

  test(
    'original HitShift and piecewise elemental damage are applied before one balance scale',
    () {
      for (final skill in mageSkills) {
        if (skill.id == 'energyShield') continue;
        final damage = (original[skill.id] as Map)['damage'] as Map;
        for (final rank in [1, 20]) {
          final stats = SorceressRules.evaluate(
            skill.id,
            rank: rank,
            hardRanks: const {},
            damageScale: scale,
          );
          final packet =
              damage[rank == 1 ? 'basePacketFirst' : 'basePacketRank20']
                  as List;
          final dot = const {'inferno', 'blaze', 'firewall'}.contains(skill.id);
          final factor = skill.id == 'inferno' ? 25 : 75;
          expect(
            dot ? stats.minDamagePerSecond : stats.minDamage,
            closeTo((packet[0] as num) * scale * (dot ? factor : 1), 1e-9),
            reason: '${skill.id} min rank$rank',
          );
          expect(
            dot ? stats.maxDamagePerSecond : stats.maxDamage,
            closeTo((packet[1] as num) * scale * (dot ? factor : 1), 1e-9),
            reason: '${skill.id} max rank$rank',
          );
        }
      }
    },
  );

  test('hard-point synergies and elemental mastery multiply exactly once', () {
    final base = SorceressRules.evaluate(
      'firebolt',
      rank: 20,
      hardRanks: const {},
    );
    final enhanced = SorceressRules.evaluate(
      'firebolt',
      rank: 20,
      hardRanks: const {'fireball': 20, 'meteor': 20, 'fireMastery': 20},
    );
    expect(enhanced.minDamage, closeTo(base.minDamage * 7.4 * 2.63, 1e-9));
    final lightning = SorceressRules.evaluate(
      'lightning',
      rank: 20,
      hardRanks: const {
        'chargedBolt': 20,
        'chainLightning': 20,
        'nova': 20,
        'lightningMastery': 20,
      },
    );
    final plain = SorceressRules.evaluate(
      'lightning',
      rank: 20,
      hardRanks: const {},
    );
    expect(lightning.maxDamage, closeTo(plain.maxDamage * 5.8 * 3.78, 1e-9));
    final cold = SorceressRules.evaluate(
      'iceBolt',
      rank: 20,
      hardRanks: const {'coldMastery': 20},
    );
    final coldPlain = SorceressRules.evaluate(
      'iceBolt',
      rank: 20,
      hardRanks: const {},
    );
    expect(cold.minDamage, coldPlain.minDamage);
    expect(SorceressRules.coldPierce(20), closeTo(1.15, 1e-9));
  });

  test(
    'source armor, shield and enchant retain long durations and distinct defenses',
    () {
      SorceressSpellStats stats(
        String id,
        int rank, [
        Map<String, int> hard = const {},
      ]) => SorceressRules.evaluate(id, rank: rank, hardRanks: hard);
      expect(stats('frozenArmor', 1).duration, 120);
      expect(stats('frozenArmor', 20).duration, 348);
      expect(stats('frozenArmor', 1).armorMultiplier, 1.3);
      expect(stats('shiverArmor', 20).armorMultiplier, closeTo(2.59, 1e-9));
      expect(stats('chillingArmor', 20).duration, 258);
      expect(
        stats('frozenArmor', 1, const {
          'shiverArmor': 20,
          'chillingArmor': 20,
        }).duration,
        520,
      );
      expect(stats('energyShield', 1).damageAbsorb, .20);
      expect(stats('energyShield', 20).damageAbsorb, .75);
      expect(stats('energyShield', 20).duration, 1284);
      expect(stats('energyShield', 20).manaPerDamage, 2);
      expect(
        stats('energyShield', 20, const {'telekinesis': 20}).manaPerDamage,
        .75,
      );
      expect(stats('energyShield', 20).meanDamage, 0);
      expect(stats('enchant', 1).duration, 144);
      expect(stats('enchant', 20).duration, 600);
      expect(stats('enchant', 20).attackRatingBonus, 191);
    },
  );

  test(
    'projectile multiplicity, timers and source residual fields have bounded explicit contracts',
    () {
      SorceressSpellStats stats(String id, int rank) =>
          SorceressRules.evaluate(id, rank: rank, hardRanks: const {});
      expect(stats('chargedBolt', 1).projectileCount, 3);
      expect(stats('chargedBolt', 20).projectileCount, 22);
      expect(stats('chainLightning', 1).lightningBounces, 5);
      expect(stats('chainLightning', 20).lightningBounces, 9);
      expect(stats('lightning', 20).pierces, true);
      expect(stats('frozenOrb', 20).range, 300);
      expect(stats('frozenOrb', 20).projectileCount, 46);
      expect(stats('hydra', 20).duration, 10);
      expect(stats('hydra', 20).projectileCount, 3);
      expect(stats('blizzard', 20).duration, 4);
      expect(stats('blizzard', 20).interval, .16);
      expect(stats('blaze', 20).maxTargets, 30);
      final meteor = stats('meteor', 1);
      expect(meteor.minDamagePerSecond, 35.15625);
      expect(meteor.maxDamagePerSecond, 58.59375);
      expect(meteor.groundDuration, 1.2);
      expect(stats('meteor', 20).groundDuration, 12.6);
      expect(stats('staticField', 1).currentHpFraction, .25);
    },
  );
}

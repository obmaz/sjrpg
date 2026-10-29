import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/area_damage.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_growth.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'package:guardian_new/sorceress_rules.dart';

void main() {
  Progress sorceress() {
    final p = Progress(heroClass: HeroClass.mage)
      ..level = 100
      ..skillPoints = 1000;
    void train(String id, int rank) {
      final def = p.skills.firstWhere((s) => s.id == id);
      for (final need in def.requires.entries) {
        if (p.rank(need.key) < need.value) train(need.key, need.value);
      }
      while (p.rank(id) < rank) {
        expect(p.learn(def), true);
      }
    }

    for (final def in mageSkills) {
      train(def.id, 20);
    }
    return p;
  }

  test(
    'all original Sorceress damage packets retain exactly one shared damage reduction',
    () {
      final p = sorceress();
      final scale =
          Progress.playerDamageScale *
          CombatBalance.skillDamageScale *
          CombatBalance.sorceressDamageScale;
      expect(scale, closeTo(.57375, 1e-9));
      for (final def in mageSkills) {
        for (final rank in [1, 7, 20]) {
          final raw = SorceressRules.evaluate(
            def.id,
            rank: rank,
            hardRanks: p.ranks,
          );
          final actual = p.sorceressSpell(def, atRank: rank);
          expect(
            actual.minDamage,
            closeTo(raw.minDamage * scale, 1e-9),
            reason: def.id,
          );
          expect(
            actual.maxDamage,
            closeTo(raw.maxDamage * scale, 1e-9),
            reason: def.id,
          );
          expect(
            actual.damagePerSecond,
            closeTo(raw.damagePerSecond * scale, 1e-9),
            reason: def.id,
          );
        }
      }
    },
  );

  test(
    'Sorceress ranks grow damage and target budgets while cast pacing stays fixed',
    () {
      final p = sorceress();
      for (final def in mageSkills.where((d) => !d.passive)) {
        for (var rank = 1; rank <= 20; rank++) {
          expect(p.skillTempo(def, atRank: rank), 1);
          expect(p.skillCooldown(def, atRank: rank), def.cooldown);
          final expected = switch (def.id) {
            'chargedBolt' => rank + 2,
            'chainLightning' => ((rank + 25) ~/ 5).clamp(0, rank + 2),
            'firebolt' ||
            'iceBolt' ||
            'iceBlast' ||
            'telekinesis' ||
            'thunderStorm' => 1,
            'frozenArmor' ||
            'shiverArmor' ||
            'chillingArmor' ||
            'energyShield' ||
            'enchant' ||
            'blink' => 0,
            _ => rank + 2,
          };
          expect(
            p.skillTargetLimit(def, atRank: rank),
            expected,
            reason: '${def.id} rank$rank',
          );
        }
      }
      for (final id in ['firebolt', 'iceBolt', 'chargedBolt']) {
        expect(
          p.skillCost(p.skills.firstWhere((s) => s.id == id)),
          greaterThan(0),
        );
      }
      expect(
        p.skillCost(p.skills.firstWhere((s) => s.id == 'sorceressAttack')),
        0,
      );
      expect(SkillGrowth.particles(5), greaterThan(SkillGrowth.particles(1)));
      expect(SkillGrowth.layers(5), greaterThan(SkillGrowth.layers(1)));
    },
  );

  test(
    'original mastery and Warmth gains remain finite and are never compounded a second time',
    () {
      final p = sorceress();
      expect(p.fireDamageMultiplier, closeTo(2.63, 1e-9));
      expect(p.lightningDamageMultiplier, closeTo(3.78, 1e-9));
      expect(p.sorceressColdPierce, closeTo(1.15, 1e-9));
      expect(
        p.manaRecovery,
        closeTo(9 * CombatBalance.resourceGainScale * 3.58, 1e-9),
      );
      expect(
        p.attackMultiplier,
        Progress.playerDamageScale,
        reason: 'spell mastery does not multiply physical staff attack',
      );
      for (final id in [
        'frozenArmor',
        'shiverArmor',
        'chillingArmor',
        'energyShield',
        'enchant',
      ]) {
        final def = p.skills.firstWhere((s) => s.id == id);
        expect(p.sorceressSpell(def).duration, greaterThan(100));
        expect(p.skillCooldown(def), 0);
      }
    },
  );

  test(
    'D2 ranks preserve the shared damage scale and bounded weapon haste',
    () {
      final p = Progress()..level = 100;
      for (final skill in p.skills) {
        p.ranks[skill.id] = skill.rankLimit;
      }
      final bash = p.skills.firstWhere((s) => s.id == 'bash');
      expect(
        p.skillDamage(bash, atRank: 1),
        closeTo(p.swordDamage * 1.5 * CombatBalance.skillDamageScale, .000001),
      );
      expect(
        p.skillDamage(bash, atRank: 20),
        closeTo(p.swordDamage * 2.26 * CombatBalance.skillDamageScale, .000001),
      );
      p.equipped[GearSlot.charm] = Gear(
        999,
        const GearDef('haste-stress', '가속', GearSlot.charm, haste: .9),
      );
      p.frenzyStacks = 6;
      expect(p.attackHaste, .15);
      expect(p.frenzyAttackTempo, closeTo(1.24, .000001));
      expect(p.weaponCriticalChance, lessThanOrEqualTo(.15));
      expect(
        p.actualBasicInterval(frenzyTempo: p.frenzyAttackTempo),
        greaterThan(0),
      );
      final whirlwind = p.skills.firstWhere((s) => s.id == 'whirlwind');
      expect(
        [
          for (var r = 1; r <= 20; r++)
            p.skillTargetLimit(whirlwind, atRank: r),
        ],
        [for (var r = 1; r <= 20; r++) r + 2],
      );
      final damage = p.skillDamage(whirlwind);
      expect(
        damage * enemyGroupDamageScale(22),
        lessThan(damage * enemyGroupDamageScale(3)),
      );
      for (final id in ['bash', 'stun', 'concentrate', 'berserk']) {
        expect(p.skillTargetLimit(p.skills.firstWhere((s) => s.id == id)), 1);
      }
      expect(
        p.skillTargetLimit(p.skills.firstWhere((s) => s.id == 'doubleThrow')),
        2,
      );
      expect(
        p.skillTargetLimit(p.skills.firstWhere((s) => s.id == 'shadowAssault')),
        5,
      );
    },
  );

  test(
    'rank-scaled area caps still divide multi-target damage without legacy target perks',
    () {
      final p = sorceress();
      for (final id in [
        'meteor',
        'blizzard',
        'frozenOrb',
        'firewall',
        'frostNova',
      ]) {
        final def = p.skills.firstWhere((s) => s.id == id);
        expect(p.skillTargetLimit(def), 22);
        final damage = p.skillDamage(def);
        expect(damage, greaterThan(0));
        expect(
          damage * enemyGroupDamageScale(5),
          lessThan(damage * enemyGroupDamageScale(3)),
        );
      }
    },
  );

  test(
    'new rank20 saves retain equipment and derived previews without another reduction on load',
    () {
      final p = sorceress()..energy = 999;
      final ranks = Map<String, int>.of(p.ranks),
          gear = p.inventory.map((g) => g.toSave()).toList();
      final restored = Progress.fromSave(jsonDecode(jsonEncode(p.toSave())))!;
      expect(restored.ranks, ranks);
      expect(restored.inventory.map((g) => g.toSave()), gear);
      expect(restored.energy, restored.maxEnergy);
      for (final def in mageSkills.where((d) => !d.passive && !d.mobility)) {
        expect(restored.skillDamage(def), p.skillDamage(def));
        expect(restored.skillCooldown(def), p.skillCooldown(def));
        expect(
          previewSkill(
            restored,
            def,
          ).firstWhere((r) => r.label == '공통 시전 지연').current,
          restored.skillCooldown(def),
        );
      }
    },
  );
}

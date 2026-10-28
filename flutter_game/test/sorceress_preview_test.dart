import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';

SkillDef _skill(String id) => mageSkills.firstWhere((s) => s.id == id);

SkillPreviewValue _row(Progress p, String id, String label) =>
    previewSkill(p, _skill(id)).singleWhere((row) => row.label == label);

void main() {
  test(
    'all thirty summaries preserve actual damage, resource and delay at every tier',
    () {
      for (final rank in [0, 1, 7, 16, 20]) {
        for (final skill in mageSkills) {
          final p = Progress(heroClass: HeroClass.mage)..level = 100;
          // Other hard points exercise original synergies and both masteries.
          for (final other in mageSkills) {
            p.ranks[other.id] = 8;
          }
          p.ranks[skill.id] = rank;
          final before = jsonEncode(p.toSave());
          final rows = previewSkill(p, skill);
          final stats = p.sorceressSpell(skill);
          expect(rows, isNotEmpty, reason: '${skill.id} rank $rank');
          expect(rows.map((r) => r.label).toSet().length, rows.length);
          expect(jsonEncode(p.toSave()), before);
          if (!skill.passive) {
            expect(
              rows.singleWhere((r) => r.label == '마나 소모').current,
              stats.manaCost,
            );
            expect(
              rows.singleWhere((r) => r.label == '공통 시전 지연').current,
              stats.castDelay,
            );
            if (stats.maxDamage > 0) {
              expect(
                rows.singleWhere((r) => r.label.endsWith('최소 피해')).current,
                stats.minDamage,
              );
              expect(
                rows.singleWhere((r) => r.label.endsWith('최대 피해')).current,
                stats.maxDamage,
              );
            }
            if (stats.maxDamagePerSecond > 0) {
              expect(
                rows.singleWhere((r) => r.label == '최소 지속 피해').current,
                stats.minDamagePerSecond,
              );
              expect(
                rows.singleWhere((r) => r.label == '최대 지속 피해').current,
                stats.maxDamagePerSecond,
              );
            }
            if (stats.duration > 0 && skill.id != 'inferno') {
              expect(
                rows.singleWhere((r) => r.label == '효과 지속').current,
                stats.duration,
              );
            }
            if (stats.freezeDuration > 0) {
              expect(
                rows.singleWhere((r) => r.label == '빙결 시간').current,
                stats.freezeDuration,
              );
            }
            if (stats.chillDuration > 0) {
              expect(
                rows.singleWhere((r) => r.label == '냉기 감속 시간').current,
                stats.chillDuration,
              );
            }
          }
          // Upgrade comparisons must match the subsequently applied hard point,
          // including synergy changes, without changing the inspected character.
          final nextValues = rows.map((r) => r.next).toList();
          p.ranks[skill.id] = (rank + 1).clamp(1, 20);
          expect(
            previewSkill(p, skill).map((r) => r.current),
            nextValues,
            reason: '${skill.id} rank $rank',
          );
        }
      }
    },
  );

  test(
    'original Fire Bolt damage is balanced exactly once and basic DPS is per projectile',
    () {
      final p = Progress(heroClass: HeroClass.mage);
      final bolt = _skill('firebolt');
      final scale = Progress.playerDamageScale * CombatBalance.skillDamageScale;
      expect(
        _row(p, 'firebolt', '1회 최소 피해').current,
        closeTo(3 * scale, 1e-10),
      );
      expect(
        _row(p, 'firebolt', '1회 최대 피해').current,
        closeTo(6 * scale, 1e-10),
      );
      for (final id in ['firebolt', 'iceBolt', 'chargedBolt']) {
        p.ranks[id] = 7;
        final skill = _skill(id), stats = p.sorceressSpell(skill);
        expect(_row(p, id, '마나 소모').current, stats.manaCost);
        expect(_row(p, id, '발사 투사체').current, stats.projectileCount);
        final dps = _row(p, id, '투사체 1개 초당 피해');
        expect(dps.current, stats.meanDamage / p.attackIntervalFor(skill));
        expect(
          dps.format(dps.current),
          '${(stats.meanDamage / CombatBalance.realSeconds(p.attackIntervalFor(skill))).toStringAsFixed(2)}/초',
        );
      }
      expect(bolt.basic, true);
    },
  );

  test(
    'channel, armor, shield, teleport and summons expose their actual unique parameters',
    () {
      final p = Progress(heroClass: HeroClass.mage)..level = 100;
      for (final skill in mageSkills) {
        p.ranks[skill.id] = 12;
      }
      final inferno = p.sorceressSpell(_skill('inferno'));
      expect(_row(p, 'inferno', '마나 소모').current, 0);
      expect(_row(p, 'inferno', '유지 마나').current, inferno.manaPerSecond);
      expect(_row(p, 'inferno', '시작에 필요한 마나').current, 6);
      expect(_row(p, 'inferno', '사거리').current, inferno.range);
      expect(
        previewSkill(p, _skill('inferno')).any((r) => r.label == '효과 지속'),
        false,
      );
      for (final id in ['frozenArmor', 'shiverArmor', 'chillingArmor']) {
        final stats = p.sorceressSpell(_skill(id));
        expect(
          _row(p, id, '방어력 증가').current,
          (stats.armorMultiplier - 1) * 100,
        );
      }
      final shield = p.sorceressSpell(_skill('energyShield'));
      expect(
        _row(p, 'energyShield', '피해 흡수율').current,
        shield.damageAbsorb * 100,
      );
      expect(_row(p, 'energyShield', '피해 1당 마나').current, (32 - 12) / 16);
      expect(_row(p, 'blink', '순간이동 거리').current, p.mobilityRange);
      expect(_row(p, 'blink', '공통 시전 지연').current, 0);
      expect(_row(p, 'hydra', '불뱀 머리').current, 3);
      expect(_row(p, 'hydra', '한 차례 최대 대상').current, 3);
      expect(_row(p, 'frozenOrb', '얼음 파편').current, 46);
      expect(
        _row(p, 'chainLightning', '연쇄 적중').current,
        p.sorceressSpell(_skill('chainLightning')).lightningBounces,
      );
      expect(_row(p, 'staticField', '현재 생명 피해').current, 25);
      expect(_row(p, 'staticField', '보스 최소 남은 생명').current, 50);
      for (final id in [
        'blizzard',
        'frozenOrb',
        'meteor',
        'firewall',
        'hydra',
      ]) {
        final row = _row(p, id, '공통 시전 지연');
        expect(row.current, p.sorceressSpell(_skill(id)).castDelay);
        expect(
          row.format(row.current),
          '${CombatBalance.realSeconds(row.current).toStringAsFixed(2)}초',
        );
      }
      for (final id in ['meteor', 'blaze', 'firewall']) {
        expect(
          _row(p, id, '바닥 불길 지속').current,
          p.sorceressSpell(_skill(id)).groundDuration,
        );
      }
    },
  );

  test(
    'passives show recovery and resistance penetration, not obsolete cold damage growth',
    () {
      final p = Progress(heroClass: HeroClass.mage);
      final ice = _skill('iceBolt');
      p.ranks[ice.id] = 1;
      final damage = p.sorceressSpell(ice).meanDamage;
      for (final id in [
        'warmth',
        'coldMastery',
        'fireMastery',
        'lightningMastery',
      ]) {
        p.ranks[id] = 20;
      }
      expect(p.sorceressSpell(ice).meanDamage, damage);
      expect(_row(p, 'coldMastery', '냉기 저항 관통').current, closeTo(115, 1e-10));
      expect(_row(p, 'warmth', '마나 회복').current, p.manaRecovery);
      expect(_row(p, 'warmth', '마나 회복 증가').current, closeTo(258, 1e-10));
      expect(
        _row(p, 'fireMastery', '화염 피해 증가').current,
        (p.fireDamageMultiplier - 1) * 100,
      );
      expect(
        _row(p, 'lightningMastery', '번개 피해 증가').current,
        (p.lightningDamageMultiplier - 1) * 100,
      );
      expect(
        previewSkill(
          p,
          _skill('coldMastery'),
        ).any((r) => r.label.contains('피해 배율')),
        false,
      );
    },
  );
}

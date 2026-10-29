import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'package:guardian_new/stage_content.dart';

import 'support/sorceress_fixture.dart';

void train(Progress p, String id, [int target = 1]) =>
    trainSkill(p, id, target);

void main() {
  for (final heroClass in [HeroClass.mage]) {
    Progress fresh() => trainedSorceress();
    final alternatives = ['iceBolt', 'chargedBolt'];
    test(
      '$heroClass has three selectable elemental basics and a firebolt primary',
      () {
        final p = Progress(heroClass: heroClass);
        expect(p.basicSkills.length, 3);
        expect(p.selectedBasic, p.defaultBasicId);
        expect(p.basicSkill.basic, true);
        expect(p.basicTargetLimit, 1);
        expect(p.skillAt(0)!.id, 'firebolt');
        for (final basic in p.basicSkills) {
          expect(basic.cost, greaterThan(0));
          expect(p.canSelectSkill(basic.id), basic.id == 'firebolt');
        }
      },
    );
    test(
      '$heroClass learning a basic keeps all four active slots and upgrades cost one point',
      () {
        final p = fresh();
        for (final id in ['frozenArmor', 'inferno', 'firewall']) {
          train(p, id);
        }
        expect(p.skillSlots.whereType<String>().length, 4);
        final slots = p.skillSlots.toList();
        for (final id in alternatives) {
          final basic = p.skills.firstWhere((s) => s.id == id);
          for (final requirement in basic.requires.entries) {
            train(p, requirement.key, requirement.value);
          }
          final points = p.skillPoints;
          expect(p.learn(basic), true);
          expect(p.skillPoints, points - 1);
          expect(p.selectedBasic, id);
          expect(p.skillSlots, slots);
          expect(p.learn(basic), true);
          expect(p.skillPoints, points - 2);
          expect(p.skillSlots, slots);
        }
      },
    );
    test(
      '$heroClass switches learned basics freely and rejects unlearned, active or foreign skills',
      () {
        final p = fresh();
        expect(p.selectBasic(alternatives.first), false);
        train(p, alternatives.first);
        final before = (p.gold, p.skillPoints, p.energy, p.skillSlots.toList());
        for (var i = 0; i < 10; i++) {
          expect(p.selectBasic(p.defaultBasicId), true);
          expect(p.selectBasic(alternatives.first), true);
        }
        expect(
          (p.gold, p.skillPoints, p.energy),
          (before.$1, before.$2, before.$3),
        );
        expect(p.skillSlots, before.$4);
        expect(p.selectBasic('frozenArmor'), false);
        expect(p.selectBasic('not-a-skill'), false);
        expect(p.selectBasic('bash'), false);
      },
    );
    test(
      '$heroClass chosen basic survives save, old saves default and invalid selections are rejected',
      () {
        final p = fresh();
        train(p, alternatives.first);
        expect(
          Progress.fromSave(p.toSave())!.selectedBasic,
          alternatives.first,
        );
        final legacy = p.toSave()..remove('selectedBasic');
        expect(Progress.fromSave(legacy)!.selectedBasic, p.defaultBasicId);
        for (final invalid in [
          alternatives.last,
          'frozenArmor',
          'unknown',
          42,
        ]) {
          final data = p.toSave()..['selectedBasic'] = invalid;
          expect(Progress.fromSave(data), isNull);
        }
      },
    );
    test(
      '$heroClass reset refunds alternative ranks and returns to the free canonical basic',
      () {
        final p = fresh()..awardSkillResetTicket(WorldStage.forest);
        train(p, alternatives.first, 3);
        train(p, alternatives.last, 2);
        final points = p.skillPoints, invested = p.investedSkillPoints;
        expect(p.resetSkills(), true);
        expect(p.skillPoints, points + invested);
        expect(p.selectedBasic, p.defaultBasicId);
        expect(p.rank(p.defaultBasicId), 1);
        for (final id in alternatives) {
          expect(p.rank(id), 0);
          expect(p.canSelectBasic(id), false);
        }
        expect(Progress.fromSave(p.toSave()), isNotNull);
      },
    );
    test(
      '$heroClass preview describes the inspected basic without changing the selected attack',
      () {
        final p = fresh();
        train(p, alternatives.first, 2);
        train(p, alternatives.last, 2);
        final inspected = p.skills.firstWhere(
          (s) => s.id == alternatives.first,
        );
        expect(p.selectedBasic, alternatives.last);
        final before = jsonEncode(p.toSave());
        final rows = previewSkill(p, inspected);
        expect(jsonEncode(p.toSave()), before);
        final stats = p.sorceressSpell(inspected);
        expect(
          rows.firstWhere((r) => r.label == '시전 동작').current,
          p.skillMotionTime(inspected),
        );
        expect(
          rows.firstWhere((r) => r.label == '1회 최소 피해').current,
          stats.minDamage,
        );
        expect(
          rows.firstWhere((r) => r.label == '투사체 1개 초당 피해').current,
          stats.meanDamage / p.attackIntervalFor(inspected),
        );
        final learned = Progress.fromSave(p.toSave())!;
        expect(learned.learn(inspected), true);
        final nextStats = learned.sorceressSpell(inspected);
        expect(
          rows.firstWhere((r) => r.label == '시전 동작').next,
          learned.skillMotionTime(inspected),
        );
        expect(
          rows.firstWhere((r) => r.label == '1회 최소 피해').next,
          nextStats.minDamage,
        );
        expect(
          rows.firstWhere((r) => r.label == '투사체 1개 초당 피해').next,
          nextStats.meanDamage / learned.attackIntervalFor(inspected),
        );
        expect(learned.selectedBasic, alternatives.last);
      },
    );
    test('$heroClass equipment comparison retains the selected basic mode', () {
      final p = fresh();
      train(p, alternatives.last);
      final gear = p.createGear(gearById('stormrod'));
      final before = jsonEncode(p.toSave()),
          preview = p.previewBasicAttack(gear)!;
      expect(jsonEncode(p.toSave()), before);
      final changed = Progress.fromSave(p.toSave())!
        ..equipped[GearSlot.weapon] = gear;
      expect(preview.damage, changed.basicDamage);
      expect(preview.interval, changed.basicAttackStats().interval);
    });
  }
  group('Barbarian canonical basic and original combat actions', () {
    Progress fresh() => Progress()
      ..level = 100
      ..skillPoints = 1000;
    test('one free basic remains separate from the starter howl', () {
      final p = Progress();
      expect(p.basicSkills.map((skill) => skill.id), ['cleave']);
      expect(p.selectedBasic, 'cleave');
      expect(p.skillAt(0)!.id, 'howl');
      expect(p.basicSkill.cost, 0);
      expect(p.basicTargetLimit, 1);
      expect(p.canSelectSkill('cleave'), false);
    });
    test(
      'upgrading the basic never replaces the four assigned active actions',
      () {
        final p = fresh();
        for (final id in ['bash', 'leap', 'doubleSwing']) {
          train(p, id);
        }
        expect(p.skillSlots.whereType<String>(), hasLength(4));
        final slots = p.skillSlots.toList(), points = p.skillPoints;
        final basic = p.basicSkill;
        expect(p.learn(basic), true);
        expect(p.skillPoints, points - 1);
        expect(p.selectedBasic, 'cleave');
        expect(p.rank('cleave'), 2);
        expect(p.skillSlots, slots);
      },
    );
    test('learned active or passive skills cannot become the free basic', () {
      final p = fresh();
      train(p, 'bash');
      train(p, 'swordMastery');
      final before = jsonEncode(p.toSave());
      expect(p.selectBasic('cleave'), true);
      for (final id in ['bash', 'swordMastery', 'firebolt', 'missing']) {
        expect(p.selectBasic(id), false);
      }
      expect(jsonEncode(p.toSave()), before);
    });
    test(
      'canonical selection roundtrips while invalid active selections reject',
      () {
        final p = fresh();
        train(p, 'bash');
        expect(Progress.fromSave(p.toSave())!.selectedBasic, 'cleave');
        final withoutBasic = p.toSave()..remove('selectedBasic');
        expect(Progress.fromSave(withoutBasic)!.selectedBasic, 'cleave');
        for (final invalid in ['bash', 'howl', 'firebolt', 'unknown', 42]) {
          expect(
            Progress.fromSave(p.toSave()..['selectedBasic'] = invalid),
            isNull,
          );
        }
      },
    );
    test(
      'reset refunds basic and active ranks and returns both free starters',
      () {
        final p = fresh()..awardSkillResetTicket(WorldStage.forest);
        train(p, 'cleave', 4);
        train(p, 'bash', 8);
        p.selectSkill('bash');
        final points = p.skillPoints, invested = p.investedSkillPoints;
        expect(p.resetSkills(), true);
        expect(p.skillPoints, points + invested);
        expect(p.ranks, {'cleave': 1, 'howl': 1});
        expect(p.selectedBasic, 'cleave');
        expect(p.skillSlots, ['howl', null, null, null]);
        expect(Progress.fromSave(p.toSave()), isNotNull);
      },
    );
    test(
      'basic preview agrees with the upgrade while the selected active stays independent',
      () {
        final p = fresh();
        train(p, 'bash');
        p.selectSkill('bash');
        train(p, 'cleave', 2);
        final basic = p.basicSkill, before = jsonEncode(p.toSave());
        final rows = previewSkill(p, basic);
        expect(jsonEncode(p.toSave()), before);
        expect(
          rows.firstWhere((r) => r.label == '기본 공격 간격').current,
          p.attackIntervalFor(basic),
        );
        expect(
          rows.firstWhere((r) => r.label == '기본 1타 피해').current,
          p.skillDamage(basic),
        );
        final learned = Progress.fromSave(p.toSave())!;
        expect(learned.learn(basic), true);
        expect(
          rows.firstWhere((r) => r.label == '기본 공격 간격').next,
          learned.attackIntervalFor(basic),
        );
        expect(
          rows.firstWhere((r) => r.label == '기본 1타 피해').next,
          learned.skillDamage(basic),
        );
        expect(learned.selectedBasic, 'cleave');
        expect(learned.selectedSkill, 'bash');
      },
    );
    test(
      'equipment comparison uses the canonical basic even with an active strike selected',
      () {
        final p = fresh();
        train(p, 'bash');
        p.selectSkill('bash');
        final gear = p.createGear(gearById('longsword'));
        final before = jsonEncode(p.toSave()),
            preview = p.previewBasicAttack(gear)!;
        expect(jsonEncode(p.toSave()), before);
        final changed = Progress.fromSave(p.toSave())!
          ..equipped[GearSlot.weapon] = gear;
        expect(preview.damage, changed.basicDamage);
        expect(preview.interval, changed.basicAttackStats().interval);
        expect(changed.selectedSkill, 'bash');
      },
    );
    test(
      'twenty-rank precision actions retain one victim while the basic gains area targets',
      () {
        final p = fresh();
        train(p, 'cleave', 5);
        train(p, 'bash', 20);
        final bash = p.skills.firstWhere((skill) => skill.id == 'bash');
        expect(p.skillTargetLimit(bash), 1);
        expect(p.basicTargetLimit, 5);
        expect(p.selectedBasic, 'cleave');
        expect(p.skillDamage(bash), greaterThan(0));
      },
    );
  });
  test('chosen ice and electricity override a different weapon element', () {
    final p = trainedSorceress();
    expect(p.weapon.base.style, 'fire');
    train(p, 'iceBolt', 5);
    expect(p.basicElement, 'ice');
    expect(p.basicTargetLimit, 1);
    train(p, 'chargedBolt', 2);
    expect(p.basicElement, 'lightning');
    expect(p.basicTargetLimit, 4);
    train(p, 'chargedBolt', 3);
    expect(p.basicTargetLimit, 5);
    p.selectBasic('firebolt');
    expect(p.basicElement, 'fire');
  });
}

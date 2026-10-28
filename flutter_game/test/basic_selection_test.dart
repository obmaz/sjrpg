import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'package:guardian_new/stage_content.dart';

void train(Progress p, String id, [int target = 1]) {
  final def = p.skills.firstWhere((s) => s.id == id);
  for (final need in def.requires.entries) {
    train(p, need.key, need.value);
  }
  while (p.rank(id) < target) {
    expect(p.learn(def), true, reason: 'learn $id rank $target');
  }
}

void main() {
  for (final heroClass in HeroClass.values) {
    Progress fresh() => Progress(heroClass: heroClass)..gainXp(50000);
    final alternatives = heroClass == HeroClass.warrior
        ? ['quickCut', 'heavyStrike']
        : ['iceShard', 'sparkBolt'];
    test(
      '$heroClass has three selectable basic attacks and an independent active starter',
      () {
        final p = Progress(heroClass: heroClass);
        expect(p.basicSkills.length, 3);
        expect(p.selectedBasic, p.defaultBasicId);
        expect(p.basicSkill.basic, true);
        expect(p.basicTargetLimit, 1);
        expect(p.skillAt(0)!.basic, false);
        for (final basic in p.basicSkills) {
          expect(basic.cost, 0);
          expect(p.canSelectSkill(basic.id), false);
        }
      },
    );
    test(
      '$heroClass learning a basic keeps all four active slots and upgrades cost one point',
      () {
        final p = fresh();
        for (final id
            in heroClass == HeroClass.warrior
                ? ['whirlwind', 'seismicSlam', 'charge']
                : ['iceArmor', 'chainLightning', 'meteor']) {
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
        expect(p.selectBasic(p.activeSkill.id), false);
        expect(p.selectBasic('not-a-skill'), false);
        expect(
          p.selectBasic(
            heroClass == HeroClass.warrior ? 'iceShard' : 'quickCut',
          ),
          false,
        );
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
          p.activeSkill.id,
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
        expect(
          rows.firstWhere((r) => r.label == '기본 공격 간격').current,
          p.attackIntervalFor(inspected),
        );
        expect(
          rows.firstWhere((r) => r.label == '기본 1타 피해').current,
          p.skillDamage(inspected),
        );
        final learned = Progress.fromSave(p.toSave())!;
        expect(learned.learn(inspected), true);
        expect(
          rows.firstWhere((r) => r.label == '기본 공격 간격').next,
          learned.attackIntervalFor(inspected),
        );
        expect(
          rows.firstWhere((r) => r.label == '기본 1타 피해').next,
          learned.skillDamage(inspected),
        );
        expect(learned.selectedBasic, alternatives.last);
      },
    );
    test('$heroClass equipment comparison retains the selected basic mode', () {
      final p = fresh();
      train(p, alternatives.last);
      final gear = p.createGear(
        gearById(heroClass == HeroClass.warrior ? 'longsword' : 'stormrod'),
      );
      final before = jsonEncode(p.toSave()),
          preview = p.previewBasicAttack(gear)!;
      expect(jsonEncode(p.toSave()), before);
      final changed = Progress.fromSave(p.toSave())!
        ..equipped[GearSlot.weapon] = gear;
      expect(preview.damage, changed.basicDamage);
      expect(preview.interval, changed.attackInterval);
    });
  }
  test(
    'precision and broad attacks retain different caps and meaningful speeds',
    () {
      final warrior = Progress()..gainXp(50000);
      train(warrior, 'cleave', 5);
      final ordinary = warrior.attackInterval;
      train(warrior, 'quickCut', 5);
      expect(warrior.basicTargetLimit, 1);
      expect(warrior.attackInterval, lessThan(ordinary));
      train(warrior, 'heavyStrike', 5);
      expect(warrior.basicTargetLimit, 1);
      expect(warrior.attackInterval, greaterThan(ordinary));
      warrior.selectBasic('cleave');
      expect(warrior.basicTargetLimit, 5);
    },
  );
  test('chosen ice and electricity override a different weapon element', () {
    final p = Progress(heroClass: HeroClass.mage)..gainXp(50000);
    expect(p.weapon.base.style, 'fire');
    train(p, 'iceShard', 5);
    expect(p.basicElement, 'ice');
    expect(p.basicTargetLimit, 1);
    train(p, 'sparkBolt', 2);
    expect(p.basicElement, 'lightning');
    expect(p.basicTargetLimit, 2);
    train(p, 'sparkBolt', 3);
    expect(p.basicTargetLimit, 3);
    p.selectBasic('firebolt');
    expect(p.basicElement, 'fire');
  });
}

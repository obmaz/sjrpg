import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree_layout.dart';
import 'package:guardian_new/stage_content.dart';

void main() {
  void train(Progress p, String id, int rank) {
    final skill = p.skills.firstWhere((s) => s.id == id);
    for (final entry in skill.requires.entries) {
      train(p, entry.key, entry.value);
    }
    while (p.rank(id) < rank) {
      expect(p.learn(skill), true, reason: id);
    }
  }

  for (final hero in HeroClass.values) {
    test(
      '$hero mobility learns at8 without occupying a regular skill slot',
      () {
        final p = Progress(heroClass: hero)
          ..level = 7
          ..skillPoints = 40;
        final skill = p.mobilitySkill;
        expect(skill.mobility, true);
        expect(skill.requiredLevel, 8);
        expect(skill.cost, 0);
        for (final parent in skill.requires.entries) {
          train(p, parent.key, parent.value);
        }
        final before = p.skillSlots;
        expect(p.canLearn(skill), false);
        expect(p.mobilityCooldown, 0);
        p.level = 8;
        train(p, skill.id, 5);
        expect(p.skillSlots, before);
        expect(p.canSelectSkill(skill.id), false);
        expect(p.selectSkill(skill.id), false);
        expect(
          p.mobilityCooldown,
          closeTo(hero == HeroClass.warrior ? 12.42 : 8.28, .000001),
        );
        expect(p.mobilityDuration, hero == HeroClass.warrior ? 2.8 : 0);
        expect(p.mobilityRange, hero == HeroClass.mage ? 380 : 0);
        final node = skillTreeRows(
          hero,
        )[2].firstWhere((slot) => slot.id == skill.id);
        expect(node.column, 5);
        expect(skillTreeRows(hero)[2].last.id, skill.id);
        expect(
          skill.requires,
          hero == HeroClass.warrior
              ? {'resoundingCry': 1}
              : {'conductivity': 1},
        );
        final restored = Progress.fromSave(jsonDecode(jsonEncode(p.toSave())))!;
        expect(restored.rank(skill.id), 5);
        expect(restored.skillSlots, before);
        for (final key in [
          'selectedSkill',
          'secondarySkill',
          'tertiarySkill',
          'quaternarySkill',
        ]) {
          final invalid =
              jsonDecode(jsonEncode(p.toSave())) as Map<String, dynamic>;
          invalid[key] = skill.id;
          expect(Progress.fromSave(invalid), null, reason: key);
        }
        p.awardSkillResetTicket(WorldStage.forest);
        final refund = p.investedSkillPoints, points = p.skillPoints;
        expect(p.resetSkills(), true);
        expect(p.skillPoints, points + refund);
        expect(p.rank(skill.id), 0);
        expect(p.mobilityCooldown, 0);
      },
    );
  }
  test('normal and sprint speed remain explicit and distinct', () {
    expect(CombatBalance.normalMoveSpeed, 135);
    expect(CombatBalance.sprintMoveSpeed, 270);
  });
}

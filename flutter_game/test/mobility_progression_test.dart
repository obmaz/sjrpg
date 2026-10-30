import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree_layout.dart';
import 'package:guardian_new/stage_content.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
      '$hero mobility uses its class source unlock and never occupies a regular skill slot',
      () {
        final p = Progress(heroClass: hero)
          ..level = hero == HeroClass.warrior ? 7 : 17
          ..skillPoints = 40;
        final skill = p.mobilitySkill;
        expect(skill.mobility, true);
        expect(skill.requiredLevel, hero == HeroClass.warrior ? 8 : 18);
        expect(skill.cost, hero == HeroClass.warrior ? 0 : 24);
        for (final parent in skill.requires.entries) {
          train(p, parent.key, parent.value);
        }
        final before = p.skillSlots;
        expect(p.canLearn(skill), false);
        expect(p.mobilityCooldown, 0);
        p.level = skill.requiredLevel;
        train(p, skill.id, 1);
        if (hero == HeroClass.mage) {
          expect(
            p.canLearn(skill),
            false,
            reason: 'rank2 requires character level19',
          );
          p.level = 22;
        }
        train(p, skill.id, 5);
        expect(p.skillSlots, before);
        expect(p.canSelectSkill(skill.id), false);
        expect(p.selectSkill(skill.id), false);
        expect(
          p.mobilityCooldown,
          closeTo(hero == HeroClass.warrior ? 12.42 : 0, .000001),
        );
        expect(p.mobilityDuration, hero == HeroClass.warrior ? 2.8 : 0);
        expect(
          p.mobilityRange,
          closeTo(hero == HeroClass.mage ? 256.57894736842104 : 0, 1e-9),
          reason: 'rank-five Teleport has not reached its rank-twenty range',
        );
        if (hero == HeroClass.mage) {
          final node = skillTreeRows(
            hero,
          )[3].firstWhere((slot) => slot.id == skill.id);
          expect(node.column, 5);
          expect(
            skillTreeRows(hero)[3].where((s) => s.id == 'blink').single.column,
            5,
          );
          expect(
            p.skillCost(skill),
            20,
            reason:
                'Teleport trades points for mana efficiency, not a fake cooldown',
          );
        } else {
          final layout = SkillTreeLayout(p, 390, dense: true, textScale: 1);
          expect(layout.rects, contains(skill.id));
          expect(layout.rects[skill.id]!.top, greaterThan(layout.bonusTop!));
          expect(
            warriorTreeIds,
            isNot(contains(skill.id)),
            reason:
                'mobility is an extra below the unchanged thirty-skill tree',
          );
        }
        expect(
          skill.requires,
          hero == HeroClass.warrior ? {'shout': 1} : {'telekinesis': 1},
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
  test(
    'increased speed applies once to real Frenzy movement and once after it expires',
    () {
      final session = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(session.dispose);
      final p = session.progress
        ..level = 100
        ..skillPoints = 1000;
      train(p, 'increasedSpeed', 20);
      train(p, 'frenzy', 5);
      p.frenzyStacks = 6;
      session.hero.frenzyTime = 10;
      final expected =
          CombatBalance.normalMoveSpeed *
          p.increasedSpeedMultiplier *
          (1 + 6 * (.025 + p.effectiveRank('frenzy') * .001));
      session.hero.update(.05);
      expect(p.frenzyMoveSpeed, closeTo(expected, .00001));
      expect(session.hero.speed, closeTo(expected, .00001));
      session.hero.frenzyTime = 0;
      session.hero.update(.05);
      expect(p.frenzyStacks, 0);
      expect(
        session.hero.speed,
        closeTo(
          CombatBalance.normalMoveSpeed * p.increasedSpeedMultiplier,
          .00001,
        ),
      );
    },
  );
  test('normal and sprint speed remain explicit and distinct', () {
    expect(CombatBalance.normalMoveSpeed, 135);
    expect(CombatBalance.sprintMoveSpeed, 270);
  });
}

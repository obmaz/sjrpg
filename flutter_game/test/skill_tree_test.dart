import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree_layout.dart';
import 'package:guardian_new/stage_content.dart';

import 'support/sorceress_fixture.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final hero in HeroClass.values) {
    test(
      '$hero has one acyclic graph with three schools with valid rank requirements',
      () {
        final p = Progress(heroClass: hero);
        expect(p.skillBranches.length, 3);
        expect(p.skills.length, hero == HeroClass.warrior ? 33 : 31);
        for (final branch in p.skillBranches) {
          expect(
            p.skills
                .where(
                  (s) =>
                      s.branch == branch &&
                      (hero == HeroClass.warrior
                          ? warriorTreeIds.contains(s.id)
                          : mageTreeIds.contains(s.id)),
                )
                .length,
            10,
          );
        }
        final ids = p.skills.map((s) => s.id).toSet();
        expect(ids.length, p.skills.length);
        void visit(SkillDef skill, Set<String> path) {
          expect(path.contains(skill.id), false);
          for (final requirement in skill.requires.entries) {
            expect(ids.contains(requirement.key), true);
            final parent = p.skills.firstWhere((s) => s.id == requirement.key);
            expect(requirement.value, inInclusiveRange(1, parent.rankLimit));
            expect(
              parent.requiredLevel,
              lessThanOrEqualTo(skill.requiredLevel),
            );
            visit(parent, {...path, skill.id});
          }
        }

        for (final skill in p.skills) {
          visit(skill, {});
        }
      },
    );
  }
  test(
    'a new Sorceress must learn original direct predecessors without spending on failures',
    () {
      final p = trainedSorceress();
      SkillDef skill(String id) => p.skills.firstWhere((s) => s.id == id);
      final points = p.skillPoints;
      expect(p.learn(skill('meteor')), false);
      expect(p.learn(skill('chainLightning')), false);
      expect(p.skillPoints, points);
      for (final id in ['warmth', 'fireball']) {
        expect(p.learn(skill(id)), true);
      }
      expect(p.learn(skill('meteor')), false);
      for (final id in ['inferno', 'blaze', 'firewall']) {
        expect(p.learn(skill(id)), true);
      }
      expect(p.learn(skill('meteor')), true);
      expect(p.learn(skill('chainLightning')), false);
      for (final id in ['chargedBolt', 'lightning', 'chainLightning']) {
        expect(p.learn(skill(id)), true);
      }
      expect(p.skillPoints, points - 9);
      expect(Progress.fromSave(p.toSave())!.toSave(), p.toSave());
    },
  );

  test(
    'current Sorceress saves require every parent and reject the ignored old skill tree',
    () {
      final p = trainedSorceress();
      trainSkill(p, 'meteor');
      p.selectSkill('meteor');
      final saved = p.toSave(), restored = Progress.fromSave(p.toSave())!;
      final meteor = restored.skills.firstWhere((s) => s.id == 'meteor');
      expect(restored.prerequisitesMet(meteor), true);
      expect(restored.learn(meteor), true);
      expect(restored.rank('meteor'), 2);
      final legacy = Map<String, dynamic>.from(saved)
        ..remove('sorceressTreeVersion');
      expect(Progress.fromSave(legacy), isNull);
      final orphaned = {
        ...saved,
        'ranks': {...p.ranks}..remove('firewall'),
      };
      expect(Progress.fromSave(orphaned), isNull);
      restored.awardSkillResetTicket(WorldStage.forest);
      expect(restored.resetSkills(), true);
      expect(restored.ranks, {'firebolt': 1, 'sorceressAttack': 1});
      expect(restored.canLearn(meteor), false);
    },
  );
  test(
    'warrior weapon and armor masteries affect combat while rage requires contact',
    () {
      final s = Adventure(GameArt());
      s.start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      s.hero.bearing = 0;
      final p = s.progress;
      p.level = 40;
      p.skillPoints = 100;
      final damage = p.basicDamage, defense = p.armor;
      for (final id in ['swordMastery', 'ironSkin', 'increasedStamina']) {
        expect(s.learn(p.skills.firstWhere((skill) => skill.id == id)), true);
      }
      expect(p.basicDamage, greaterThan(damage));
      expect(p.armor, greaterThan(defense));
      p.energy = 0;
      final mob = s.spawnEnemy('golem', const Offset(6050, 4200), boss: true)!;
      s.hero.slash();
      final firstContact = p.energy;
      expect(firstContact, greaterThan(0));
      s.hero.attackClock = 0;
      s.hero.slash();
      expect(p.energy, greaterThan(firstContact));
      final afterContacts = p.energy;
      mob.position.setValues(7000, 4200);
      s.hero.attackClock = 0;
      s.hero.slash();
      expect(p.energy, afterContacts);
      p.awardSkillResetTicket(WorldStage.forest);
      expect(s.resetSkills(), true);
      expect(p.basicDamage, damage);
      expect(p.armor, defense);
    },
  );
  test(
    'original masteries amplify their spell families while Warmth regenerates mana',
    () {
      final p = trainedSorceress();
      final fire = p.weapon, ice = p.createGear(gearById('frostwand'));
      p.inventory.add(ice);
      final originalFire = p.basicDamage;
      p.equip(ice);
      expect(
        p.basicDamage,
        originalFire,
        reason: 'staff art does not change the selected spell element',
      );
      trainSkill(p, 'warmth');
      expect(p.manaRecovery, closeTo(9 * .7 * 1.12, .000001));
      trainSkill(p, 'iceBolt');
      p.selectBasic('iceBolt');
      final iceDamage = p.basicDamage;
      trainSkill(p, 'coldMastery');
      expect(p.coldDamageMultiplier, 1);
      expect(p.sorceressColdPierce, closeTo(.08, 1e-9));
      expect(
        p.basicDamage,
        iceDamage,
        reason:
            'Cold Mastery is target resistance penetration, not base damage',
      );
      p.equip(fire);
      expect(p.basicDamage, iceDamage);
      trainSkill(p, 'fireMastery');
      expect(p.basicDamage, iceDamage);
      p.selectBasic('firebolt');
      expect(p.basicDamage, closeTo(originalFire * 1.12, .000001));
      trainSkill(p, 'chargedBolt');
      p.selectBasic('chargedBolt');
      final lightningDamage = p.basicDamage;
      trainSkill(p, 'lightningMastery');
      expect(p.lightningDamageMultiplier, 1.2);
      expect(p.basicDamage, closeTo(lightningDamage * 1.2, .000001));
      expect(Progress.fromSave(p.toSave())!.toSave(), p.toSave());
    },
  );
}

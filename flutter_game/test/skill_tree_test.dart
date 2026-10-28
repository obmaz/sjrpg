import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree_layout.dart';
import 'package:guardian_new/stage_content.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final hero in HeroClass.values) {
    test(
      '$hero has one acyclic graph with three schools with valid rank requirements',
      () {
        final p = Progress(heroClass: hero);
        expect(p.skillBranches.length, 3);
        expect(p.skills.length, hero == HeroClass.warrior ? 33 : 21);
        for (final branch in p.skillBranches) {
          expect(
            p.skills
                .where(
                  (s) =>
                      s.branch == branch &&
                      (hero == HeroClass.warrior
                          ? warriorTreeIds.contains(s.id)
                          : !s.basic || s.id == p.defaultBasicId),
                )
                .length,
            hero == HeroClass.warrior
                ? 10
                : (branch == '전투 기술' ? 8 : 6) +
                      (branch == p.mobilitySkill.branch ? 1 : 0),
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
    'a fresh mage must unlock predecessors; failures never spend points',
    () {
      final p = Progress(heroClass: HeroClass.mage)..gainXp(2000);
      SkillDef skill(String id) => p.skills.firstWhere((s) => s.id == id);
      final points = p.skillPoints;
      expect(p.learn(skill('meteor')), false);
      expect(p.learn(skill('chainLightning')), false);
      expect(p.skillPoints, points);
      expect(p.learn(skill('warmth')), true);
      expect(p.learn(skill('meteor')), false);
      expect(p.learn(skill('firebolt')), true);
      expect(p.learn(skill('emberFocus')), true);
      expect(p.learn(skill('arcaneMastery')), true);
      expect(p.learn(skill('chainLightning')), true);
      expect(p.learn(skill('meteor')), false);
      expect(p.learn(skill('iceArmor')), true);
      expect(p.learn(skill('meteor')), true);
      expect(p.skillPoints, points - 7);
      expect(Progress.fromSave(p.toSave())!.toSave(), p.toSave());
    },
  );
  test(
    'existing saved skills remain usable and upgradable without newly added parents',
    () {
      final p = Progress(heroClass: HeroClass.mage)..gainXp(1000);
      p.ranks['meteor'] = 1;
      p.skillPoints--;
      p.selectSkill('meteor');
      final restored = Progress.fromSave(p.toSave())!;
      final meteor = restored.skills.firstWhere((s) => s.id == 'meteor');
      expect(restored.prerequisitesMet(meteor), false);
      expect(restored.canLearn(meteor), true);
      expect(restored.learn(meteor), true);
      expect(restored.rank('meteor'), 2);

      restored.awardSkillResetTicket(WorldStage.forest);
      expect(restored.resetSkills(), true);
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
  test('elemental mastery and warmth change the actual mage combat values', () {
    final p = Progress(heroClass: HeroClass.mage)..gainXp(4000);
    final fire = p.weapon;
    final ice = p.createGear(gearById('frostwand'));
    p.inventory.add(ice);
    p.equip(ice);
    for (final id in [
      'warmth',
      'iceArmor',
      'arcaneMastery',
      'frostNova',
      'deepFreeze',
    ]) {
      expect(p.learn(p.skills.firstWhere((s) => s.id == id)), true);
    }
    final iceDamage = p.basicDamage;
    for (final id in ['coldMastery']) {
      expect(p.learn(p.skills.firstWhere((s) => s.id == id)), true);
    }
    expect(p.manaRecovery, closeTo(6.615, .000001));
    expect(p.coldDamageMultiplier, closeTo(1.04, .000001));
    expect(p.basicDamage, closeTo(iceDamage * 1.04 / 1.015, .001));
    p.equip(fire);
    final fireDamage = p.basicDamage;
    expect(p.learn(p.skills.firstWhere((s) => s.id == 'coldMastery')), true);
    expect(p.basicDamage, fireDamage);
    for (final id in ['arcaneMastery', 'chainLightning', 'lightningMastery']) {
      expect(p.learn(p.skills.firstWhere((s) => s.id == id)), true);
    }
    expect(p.lightningDamageMultiplier, 1.025);
    expect(Progress.fromSave(p.toSave())!.toSave(), p.toSave());
  });
}

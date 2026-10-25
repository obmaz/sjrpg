import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final hero in HeroClass.values) {
    test(
      '$hero has one acyclic graph with three schools with valid rank requirements',
      () {
        final p = Progress(heroClass: hero);
        expect(p.skillBranches.length, 3);
        for (final branch in p.skillBranches) {
          expect(
            p.skills.where((s) => s.branch == branch).length,
            greaterThanOrEqualTo(3),
          );
        }
        final ids = p.skills.map((s) => s.id).toSet();
        expect(ids.length, p.skills.length);
        void visit(SkillDef skill, Set<String> path) {
          expect(path.contains(skill.id), false);
          for (final requirement in skill.requires.entries) {
            expect(ids.contains(requirement.key), true);
            expect(requirement.value, inInclusiveRange(1, SkillDef.maxRank));
            final parent = p.skills.firstWhere((s) => s.id == requirement.key);
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
      final p = Progress(heroClass: HeroClass.mage)..gainXp(1000);
      SkillDef skill(String id) => p.skills.firstWhere((s) => s.id == id);
      final points = p.skillPoints;
      expect(p.learn(skill('meteor')), false);
      expect(p.learn(skill('chainLightning')), false);
      expect(p.skillPoints, points);
      expect(p.learn(skill('warmth')), true);
      expect(p.learn(skill('meteor')), false);
      expect(p.learn(skill('warmth')), true);
      expect(p.learn(skill('arcaneMastery')), true);
      expect(p.learn(skill('chainLightning')), true);
      expect(p.learn(skill('meteor')), true);
      expect(p.skillPoints, points - 5);
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
      restored.gold = 100;
      expect(restored.resetSkills(), true);
      expect(restored.canLearn(meteor), false);
    },
  );
  test(
    'new warrior passives affect real attack speed, life and only connected rage',
    () {
      final s = Adventure(GameArt());
      s.start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      s.hero.bearing = 0;
      final p = s.progress..gainXp(4000);
      final interval = p.attackInterval, hp = p.maxHp;
      for (final id in [
        'mastery',
        'mastery',
        'ironSkin',
        'cleave',
        'frenzy',
        'battleFocus',
        'battleVigor',
        'battleVigor',
        'rallyingVoice',
      ]) {
        expect(s.learn(p.skills.firstWhere((skill) => skill.id == id)), true);
      }
      expect(p.attackInterval, lessThan(interval));
      expect(p.maxHp, hp + 24);
      p.energy = 0;
      final mob = s.spawnEnemy('golem', const Offset(6050, 4200), boss: true)!;
      s.hero.slash();
      expect(p.energy, 3);
      s.hero.armorTime = 6;
      s.hero.attackClock = 0;
      s.hero.slash();
      expect(p.energy, 7);
      mob.position.setValues(7000, 4200);
      s.hero.attackClock = 0;
      s.hero.slash();
      expect(p.energy, 7);
      p.gold = 100;
      expect(s.resetSkills(), true);
      expect(p.attackInterval, interval);
      expect(p.maxHp, hp);
    },
  );
  test('elemental mastery and warmth change the actual mage combat values', () {
    final p = Progress(heroClass: HeroClass.mage)..gainXp(4000);
    final fire = p.weapon;
    final ice = p.createGear(gearById('frostwand'));
    p.inventory.add(ice);
    p.equip(ice);
    final iceDamage = p.basicDamage;
    for (final id in ['warmth', 'iceArmor', 'arcaneMastery', 'coldMastery']) {
      expect(p.learn(p.skills.firstWhere((s) => s.id == id)), true);
    }
    expect(p.manaRecovery, 10.5);
    expect(p.basicDamage, closeTo(iceDamage * 1.09 * 1.08, .001));
    p.equip(fire);
    final fireDamage = p.basicDamage;
    expect(p.learn(p.skills.firstWhere((s) => s.id == 'coldMastery')), true);
    expect(p.basicDamage, fireDamage);
    for (final id in ['arcaneMastery', 'chainLightning', 'lightningMastery']) {
      expect(p.learn(p.skills.firstWhere((s) => s.id == id)), true);
    }
    expect(p.lightningDamageMultiplier, 1.08);
    expect(Progress.fromSave(p.toSave())!.toSave(), p.toSave());
  });
}

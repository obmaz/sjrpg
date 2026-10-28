import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'package:guardian_new/stage_content.dart';
import 'support/sorceress_fixture.dart';

void main() {
  for (final (hero, ids) in [
    (
      HeroClass.warrior,
      [
        'swordMastery',
        'axeMastery',
        'maceMastery',
        'polearmMastery',
        'throwingMastery',
        'spearMastery',
        'increasedStamina',
        'ironSkin',
        'increasedSpeed',
        'naturalResistance',
      ],
    ),
    (
      HeroClass.mage,
      ['warmth', 'fireMastery', 'lightningMastery', 'coldMastery'],
    ),
  ]) {
    for (final id in ids) {
      test(
        '$id changes real preview stats, saves and resets without losing points',
        () {
          final p = Progress(heroClass: hero)
            ..level = 100
            ..skillPoints = 1000;
          for (final skill in p.skills) {
            p.ranks[skill.id] = 2.clamp(1, skill.rankLimit);
          }
          p.ranks[id] = 0;
          p.skillPoints = 20;
          final skill = p.skills.firstWhere((s) => s.id == id);
          final points = p.skillPoints;
          final before = previewSkill(p, skill);
          expect(p.learn(skill), true);
          expect(p.skillPoints, points - 1);
          final after = previewSkill(p, skill);
          expect(after.map((s) => s.current), before.map((s) => s.next));
          expect(
            List.generate(
              after.length,
              (index) => after[index].current != before[index].current,
            ).any((changed) => changed),
            true,
          );
          final restored = Progress.fromSave(p.toSave())!;
          expect(restored.rank(id), p.rank(id));
          expect(
            previewSkill(restored, skill).map((s) => s.current),
            previewSkill(p, skill).map((s) => s.current),
          );

          final refund = restored.investedSkillPoints;
          final remaining = restored.skillPoints;
          restored.awardSkillResetTicket(WorldStage.forest);
          expect(restored.resetSkills(), true);
          expect(restored.rank(id), 0);
          expect(restored.skillPoints, remaining + refund);
        },
      );
    }
  }
  for (final (id, weaponId) in [
    ('swordMastery', 'shortsword'),
    ('axeMastery', 'axe'),
    ('maceMastery', 'mace'),
    ('polearmMastery', 'halberd'),
    ('spearMastery', 'spear'),
  ]) {
    test(
      '$id affects its matching weapon without granting every weapon mastery at once',
      () {
        final p = Progress()
          ..level = 100
          ..skillPoints = 1000;
        final gear = p.createGear(gearById(weaponId));
        p.addOwnedGear(gear);
        expect(p.equip(gear), true);
        expect(p.weaponMasteryId, id);
        final skill = p.skills.firstWhere((skill) => skill.id == id);
        final before = p.basicDamage;
        expect(p.learn(skill), true);
        expect(p.basicDamage, closeTo(before * 1.02, .00001));
        final after = p.basicDamage;
        final foreign = p.skills.firstWhere(
          (skill) =>
              skill.id ==
              (id == 'swordMastery' ? 'axeMastery' : 'swordMastery'),
        );
        expect(p.learn(foreign), true);
        expect(p.basicDamage, after);
        final restored = Progress.fromSave(p.toSave())!;
        expect(restored.basicDamage, p.basicDamage);
        expect(restored.weaponCriticalChance, p.weaponCriticalChance);
      },
    );
  }
  test(
    'throwing mastery scales the original thrown attack while leaving the free basic alone',
    () {
      final p = Progress()
        ..level = 100
        ..skillPoints = 1000;
      p.ranks['doubleThrow'] = 1;
      final skill = p.skills.firstWhere((skill) => skill.id == 'doubleThrow');
      final mastery = p.skills.firstWhere(
        (skill) => skill.id == 'throwingMastery',
      );
      final basic = p.basicDamage, thrown = p.skillDamage(skill);
      expect(p.learn(mastery), true);
      expect(p.basicDamage, basic);
      expect(p.skillDamage(skill), closeTo(thrown * 1.02, .00001));
      expect(p.throwingCriticalChance, greaterThan(0));
    },
  );
  test('Meteor needs both original fire parents at their stated rank', () {
    final p = trainedSorceress(),
        skill = p.skills.firstWhere((skill) => skill.id == 'meteor');
    expect(skill.requires, {'fireball': 1, 'firewall': 1});
    trainSkill(p, 'fireball');
    final points = p.skillPoints;
    expect(p.learn(skill), false);
    expect(p.skillPoints, points);
    trainSkill(p, 'firewall');
    expect(p.learn(skill), true);
    expect(p.rank('meteor'), 1);
  });
  for (final (mastery, spell, multiplier) in [
    ('fireMastery', 'firebolt', 1.3),
    ('lightningMastery', 'chargedBolt', 1.5),
  ]) {
    test(
      '$mastery increases only its own element and keeps original target geometry',
      () {
        final p = trainedSorceress();
        trainSkill(p, spell);
        trainSkill(p, 'iceBolt');
        final skill = p.skills.firstWhere((s) => s.id == spell),
            cold = p.skills.firstWhere((s) => s.id == 'iceBolt');
        final before = p.skillDamage(skill),
            coldBefore = p.skillDamage(cold),
            targets = p.skillTargetLimit(skill);
        final points = p.skillPoints;
        trainSkill(p, mastery);
        expect(p.skillPoints, points - 1);
        expect(p.skillDamage(skill), closeTo(before * multiplier, .00001));
        expect(p.skillDamage(cold), coldBefore);
        expect(p.skillTargetLimit(skill), targets);
        expect(
          Progress.fromSave(p.toSave())!.skillDamage(skill),
          p.skillDamage(skill),
        );
        trainSkill(p, mastery, 20);
        final expected = mastery == 'fireMastery' ? 2.63 : 3.78;
        expect(p.skillDamage(skill), closeTo(before * expected, .00001));
      },
    );
  }
  test(
    'Cold Mastery penetrates resistance rather than inflating raw damage or area',
    () {
      final p = trainedSorceress();
      trainSkill(p, 'iceBolt');
      final ice = p.skills.firstWhere((s) => s.id == 'iceBolt');
      final damage = p.skillDamage(ice), targets = p.skillTargetLimit(ice);
      trainSkill(p, 'coldMastery');
      expect(p.sorceressColdPierce, .20);
      expect(p.skillDamage(ice), damage);
      expect(p.skillTargetLimit(ice), targets);
      trainSkill(p, 'coldMastery', 20);
      expect(p.sorceressColdPierce, closeTo(1.15, .000001));
      final restored = Progress.fromSave(p.toSave())!;
      expect(restored.sorceressColdPierce, p.sorceressColdPierce);
    },
  );
  for (final id in [
    'meteor',
    'frozenOrb',
    'energyShield',
    'blizzard',
    'hydra',
  ]) {
    test(
      '$id original twenty-point ceiling preserves previews, points and save/refund identity',
      () {
        final p = trainedSorceress();
        trainSkill(p, id, 20);
        final skill = p.skills.firstWhere((skill) => skill.id == id),
            points = p.skillPoints;
        expect(p.rank(id), 20);
        expect(skill.rankLimit, 20);
        expect(p.learn(skill), false);
        expect(p.skillPoints, points);
        final preview = previewSkill(p, skill);
        expect(
          preview.map((row) => row.next),
          preview.map((row) => row.current),
        );
        final restored = Progress.fromSave(p.toSave())!;
        expect(restored.rank(id), 20);
        expect(
          previewSkill(restored, skill).map((row) => row.current),
          preview.map((row) => row.current),
        );
        final refund = restored.investedSkillPoints,
            remaining = restored.skillPoints;
        restored.awardSkillResetTicket(WorldStage.forest);
        expect(restored.resetSkills(), true);
        expect(restored.rank(id), 0);
        expect(restored.skillPoints, remaining + refund);
      },
    );
  }
}

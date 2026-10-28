import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'package:guardian_new/stage_content.dart';

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
      [
        'emberFocus',
        'cinderReach',
        'phoenixHeart',
        'deepFreeze',
        'frozenAegis',
        'glacialReserve',
        'conductivity',
        'forkedStorm',
        'arcaneEconomy',
      ],
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
            p.ranks[skill.id] = 2;
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
          // Every specialty point adds one victim to its linked area skills.
          if (['cinderReach', 'forkedStorm'].contains(id)) {
            expect(after.first.current, before.first.current + 1);
            expect(p.learn(skill), true);
            expect(
              previewSkill(p, skill).first.current,
              before.first.current + 2,
            );
            expect(p.learn(skill), true);
            final cap = previewSkill(p, skill);
            expect(cap.first.current, before.first.current + 3);
          } else {
            expect(
              List.generate(
                after.length,
                (index) => after[index].current != before[index].current,
              ).any((changed) => changed),
              true,
            );
          }
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
  test('new mage convergence needs every parent at its stated rank', () {
    final p = Progress(heroClass: HeroClass.mage)..gainXp(20000);
    final skill = p.skills.firstWhere((s) => s.id == 'forkedStorm');
    expect(skill.requires, {'coldMastery': 1, 'lightningMastery': 1});
    p.ranks['lightningMastery'] = 1;
    final points = p.skillPoints;
    expect(p.learn(skill), false);
    expect(p.skillPoints, points);
    // An old same-school parent cannot replace the adjacent cold mastery.
    p.ranks['conductivity'] = 1;
    expect(p.learn(skill), false);
    expect(p.skillPoints, points);
    p.ranks['coldMastery'] = 1;
    p.ranks.remove('lightningMastery');
    expect(p.learn(skill), false);
    expect(p.skillPoints, points);
    expect(p.rank(skill.id), 0);
    p.ranks['lightningMastery'] = 1;
    expect(p.learn(skill), true);
    expect(p.skillPoints, points - 1);
    expect(p.rank(skill.id), 1);
  });
  for (final (hero, perkId, affected) in [
    (HeroClass.mage, 'cinderReach', ['meteor']),
    (HeroClass.mage, 'forkedStorm', ['chainLightning']),
  ]) {
    test(
      '$perkId gives real damage on its first point and bounded area growth',
      () {
        final p = Progress(heroClass: hero)
          ..level = 100
          ..skillPoints = 1000;
        for (final skill in p.skills) {
          p.ranks[skill.id] = 2;
        }
        p.ranks[perkId] = 0;
        final perk = p.skills.firstWhere((s) => s.id == perkId);
        final damage = {
          for (final s in p.skills.where((s) => !s.passive))
            s.id: p.skillDamage(s),
        };
        final caps = {
          for (final id in affected)
            id: p.skillTargetLimit(p.skills.firstWhere((s) => s.id == id)),
        };
        final points = p.skillPoints,
            basic = p.basicDamage,
            basicTargets = p.basicTargetLimit;
        expect(p.learn(perk), true);
        expect(p.basicDamage, basic);
        expect(p.basicTargetLimit, basicTargets);
        expect(p.skillPoints, points - 1);
        for (final skill in p.skills.where((s) => !s.passive)) {
          expect(
            p.skillDamage(skill),
            closeTo(
              damage[skill.id]! * (affected.contains(skill.id) ? 1.005 : 1),
              .00001,
            ),
          );
        }
        for (final id in affected) {
          expect(
            p.skillTargetLimit(p.skills.firstWhere((s) => s.id == id)),
            caps[id]! + 1,
          );
        }
        expect(
          previewSkill(p, perk)
              .where((r) => r.label.contains('피해'))
              .every((r) => r.next > r.current),
          true,
        );
        final restored = Progress.fromSave(p.toSave())!;
        for (final id in affected) {
          final skill = p.skills.firstWhere((s) => s.id == id);
          expect(restored.skillDamage(skill), p.skillDamage(skill));
        }
        while (p.rank(perkId) < perk.rankLimit) {
          expect(p.learn(perk), true);
        }
        for (final id in affected) {
          final skill = p.skills.firstWhere((s) => s.id == id);
          expect(p.skillDamage(skill), closeTo(damage[id]! * 1.025, .00001));
          expect(p.skillTargetLimit(skill), caps[id]! + perk.rankLimit);
        }
      },
    );
  }
}

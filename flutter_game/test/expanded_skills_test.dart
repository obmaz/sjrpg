import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'package:guardian_new/stage_content.dart';

void main() {
  for (final (hero, ids) in [
    (
      HeroClass.warrior,
      [
        'rendingEdge',
        'stormOfSteel',
        'weaponTempo',
        'veteranGuard',
        'secondWind',
        'resoundingCry',
        'warDrums',
        'unyieldingOath',
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
          final p = Progress(heroClass: hero)..gainXp(20000);
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
          // Target-cap perks increase every two ranks, avoiding a free extra victim.
          if (['stormOfSteel', 'cinderReach', 'forkedStorm'].contains(id)) {
            expect(after.first.current, before.first.current);
            expect(p.learn(skill), true);
            final cap = previewSkill(p, skill);
            expect(cap.first.current, before.first.current + 1);
          } else {
            expect(after.any((s) => s.current != before.first.current), true);
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
    (HeroClass.warrior, 'stormOfSteel', ['whirlwind', 'seismicSlam']),
    (HeroClass.mage, 'cinderReach', ['meteor']),
    (HeroClass.mage, 'forkedStorm', ['chainLightning']),
  ]) {
    test(
      '$perkId gives real damage on its first point and bounded area growth',
      () {
        final p = Progress(heroClass: hero)..gainXp(20000);
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
              damage[skill.id]! * (affected.contains(skill.id) ? 1.02 : 1),
              .00001,
            ),
          );
        }
        for (final id in affected) {
          expect(
            p.skillTargetLimit(p.skills.firstWhere((s) => s.id == id)),
            caps[id],
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
        while (p.rank(perkId) < SkillDef.maxRank) {
          expect(p.learn(perk), true);
        }
        for (final id in affected) {
          final skill = p.skills.firstWhere((s) => s.id == id);
          expect(p.skillDamage(skill), closeTo(damage[id]! * 1.1, .00001));
          expect(p.skillTargetLimit(skill), caps[id]! + 2);
        }
      },
    );
  }
}

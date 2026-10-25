import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';

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
            expect(p.learn(skill), true);
            final cap = previewSkill(p, skill);
            expect(cap.any((s) => s.current > before.first.current), true);
          } else {
            expect(after.any((s) => s.current != before.first.current), true);
          }
          final restored = Progress.fromSave(p.toSave())!;
          expect(restored.rank(id), p.rank(id));
          expect(
            previewSkill(restored, skill).map((s) => s.current),
            previewSkill(p, skill).map((s) => s.current),
          );
          restored.gold = 10000;
          final refund = restored.investedSkillPoints;
          final remaining = restored.skillPoints;
          expect(restored.resetSkills(), true);
          expect(restored.rank(id), 0);
          expect(restored.skillPoints, remaining + refund);
        },
      );
    }
  }
  test('new mage convergence needs every parent at its stated rank', () {
    final p = Progress(heroClass: HeroClass.mage)..gainXp(20000);
    final skill = p.skills.firstWhere((s) => s.id == 'arcaneEconomy');
    p.ranks['lightningMastery'] = 1;
    final points = p.skillPoints;
    expect(p.learn(skill), false);
    expect(p.skillPoints, points);
    p.ranks['phoenixHeart'] = 1;
    expect(p.learn(skill), true);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/rpg_model.dart';

void main() {
  for (final hero in HeroClass.values) {
    test(
      '$hero original multi-parent milestones require every ancestor and remain attainable',
      () {
        final p = Progress(heroClass: hero)
          ..level = 100
          ..skillPoints = 1000;
        final shared = p.skills
            .where(
              (s) => hero == HeroClass.mage
                  ? s.requires.length > 1
                  : s.requires.keys.any(
                      (id) =>
                          p.skills.firstWhere((v) => v.id == id).branch !=
                          s.branch,
                    ),
            )
            .toList();
        expect(
          shared.map((skill) => skill.id).toSet(),
          hero == HeroClass.warrior
              ? {'shadowAssault', 'battleSprint'}
              : {
                  'shiverArmor',
                  'enchant',
                  'thunderStorm',
                  'energyShield',
                  'meteor',
                  'blizzard',
                },
        );
        for (final skill in shared) {
          p.ranks
            ..clear()
            ..addAll(Progress(heroClass: hero).ranks);
          p.selectedBasic = p.defaultBasicId;
          p.secondarySkill = p.tertiarySkill = p.quaternarySkill = null;
          p.skillPoints = 50;
          void train(String id, int rank) {
            final def = p.skills.firstWhere((d) => d.id == id);
            for (final parent in def.requires.entries) {
              if (p.rank(parent.key) < parent.value) {
                train(parent.key, parent.value);
              }
            }
            while (p.rank(id) < rank) {
              expect(p.learn(def), true);
            }
          }

          for (final requirement in skill.requires.entries) {
            train(requirement.key, requirement.value);
          }
          expect(p.canLearn(skill), true);
          for (final requirement in skill.requires.entries) {
            p.ranks[requirement.key] = requirement.value - 1;
            final points = p.skillPoints;
            expect(
              p.learn(skill),
              false,
              reason: '${skill.id} missing ${requirement.key}',
            );
            expect(p.skillPoints, points);
            p.ranks[requirement.key] = requirement.value;
          }
          expect(p.learn(skill), true);
          expect(Progress.fromSave(p.toSave())!.rank(skill.id), 1);
        }
        // Buy the full graph from its roots without special grants or cycles.
        final fresh = Progress(heroClass: hero)
          ..level = 100
          ..skillPoints = 500;
        var changed = true;
        while (changed) {
          changed = false;
          for (final s in fresh.skills) {
            if (fresh.rank(s.id) < (s.rankLimit < 2 ? s.rankLimit : 2) &&
                fresh.learn(s)) {
              changed = true;
            }
          }
        }
        expect(
          fresh.skills.every(
            (s) => fresh.rank(s.id) >= (s.rankLimit < 2 ? s.rankLimit : 2),
          ),
          true,
        );
      },
    );
    test(
      '$hero outgoing damage is reduced once at every progression tier without rewriting saves',
      () {
        for (final xp in [0, 1000, 20000]) {
          final p = Progress(heroClass: hero)..gainXp(xp);
          for (final s in p.skills.where((s) => s.requiredLevel <= p.level)) {
            var rank = s.rankLimit < 3 ? s.rankLimit : 3;
            while (rank > 1 && s.requiredLevelForRank(rank) > p.level) {
              rank--;
            }
            p.ranks[s.id] = rank;
          }
          final raw =
              (p.bonusAttack +
                  (p.level - 1) * 2 +
                  p.equipped.values.fold(0.0, (v, g) => v + g.attack) +
                  (p.usingFallbackWeapon ? p.weapon.attack : 0)) *
              (hero == HeroClass.warrior
                  ? 1 + p.rank(p.weaponMasteryId) * .02
                  : 1.0);
          expect(p.swordDamage, closeTo(raw * .75 * .85, .00001));
          final mastery = p.rank(p.weaponMasteryId);
          final criticalChance = hero == HeroClass.warrior && mastery > 0
              ? .03 + mastery * .004
              : 0;
          expect(
            p.basicDps,
            closeTo(
              p.basicDamage *
                  (1 + criticalChance) /
                  p.attackInterval *
                  CombatBalance.gameSpeed,
              .00001,
            ),
          );
          final saved = p.toSave(), restored = Progress.fromSave(saved)!;
          expect(restored.toSave(), saved);
          for (final s in p.skills.where((s) => !s.passive)) {
            expect(restored.skillDamage(s), p.skillDamage(s));
          }
          expect(restored.basicDamage, p.basicDamage);
          final before = p.swordDamage, spellBefore = p.basicDamage;
          p.swordDamage += 5;
          expect(p.swordDamage, closeTo(before + 5, .00001));
          if (hero == HeroClass.mage) {
            expect(
              p.basicDamage,
              spellBefore,
              reason: 'physical training does not amplify intrinsic spells',
            );
          }
        }
      },
    );
  }
}

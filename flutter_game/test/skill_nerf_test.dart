import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/area_damage.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_growth.dart';
import 'package:guardian_new/skill_preview_model.dart';

void main() {
  final baseline =
      jsonDecode(
            File(
              'test/fixtures/skill_balance_mobile69.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  Progress ranked(HeroClass hero, int rank, {bool stacked = false}) {
    final p = Progress(heroClass: hero)..level = 30;
    p.ranks.clear();
    for (final s in p.skills) {
      if (stacked || s.basic || !s.passive && !s.mobility) p.ranks[s.id] = rank;
    }
    return p;
  }

  for (final hero in const [HeroClass.mage]) {
    test(
      '$hero every basic and damaging skill is materially weaker at1/3/5',
      () {
        for (final rank in [1, 3, 5]) {
          final p = ranked(hero, rank);
          final old = (baseline[hero.name] as Map)['$rank'] as Map;
          for (final s in p.skills.where(
            (s) =>
                (s.basic || !s.passive && !s.mobility) && old.containsKey(s.id),
          )) {
            final previous = old[s.id] as Map;
            final oldDamage = (previous['damage'] as num).toDouble();
            if (oldDamage > 0) {
              expect(
                p.skillDamage(s) / oldDamage,
                inInclusiveRange(.50, .600001),
                reason: '${s.id} rank$rank',
              );
            }
            final tempo = s.basic ? p.basicTempoFor(s) : p.skillTempo(s);
            expect(
              tempo / (previous['tempo'] as num),
              inInclusiveRange(.64, .751),
              reason: '${s.id} rank$rank pacing',
            );
            if (!s.passive) {
              expect(
                p.skillCooldown(s),
                greaterThan(previous['cooldown'] as num),
              );
            }
          }
        }
      },
    );

    test(
      '$hero offensive points have small damage gains and one target per point',
      () {
        final p = ranked(hero, 1);
        for (final s in p.skills.where(
          (s) => s.basic || !s.passive && !s.mobility,
        )) {
          final first = p.skillDamage(s, atRank: 1);
          if (first > 0) {
            expect(
              p.skillDamage(s, atRank: 5) / first,
              lessThan(1.06),
              reason: s.id,
            );
          }
          final caps = [
            for (var rank = 1; rank <= 5; rank++)
              p.skillTargetLimit(s, atRank: rank),
          ];
          if (s.id == 'shadowAssault') {
            expect(caps, [1, 2, 3, 4, 5]);
          } else if (s.id == 'iceArmor') {
            expect(caps, [0, 0, 0, 0, 0]);
          } else if (['quickCut', 'heavyStrike', 'iceShard'].contains(s.id)) {
            expect(caps, [1, 1, 1, 1, 1]);
          } else {
            final initial = s.basic ? 1 : 3;
            expect(caps, [
              initial,
              initial + 1,
              initial + 2,
              initial + 3,
              initial + 4,
            ], reason: s.id);
          }
        }
        expect(SkillGrowth.particles(5), greaterThan(SkillGrowth.particles(1)));
        expect(SkillGrowth.layers(5), greaterThan(SkillGrowth.layers(1)));
      },
    );

    test(
      '$hero stacked rank5 DPS and resource amplification remain bounded',
      () {
        final p = ranked(hero, 5, stacked: true);
        final old = (baseline[hero.name] as Map)['stacked'] as Map;
        final dps =
            p.basicDps * (hero == HeroClass.warrior ? p.frenzyAttackTempo : 1);
        // Compare balance at the same global pace: the legacy fixture was
        // recorded at 1.0x, while basicDps now reports real seconds at 1.2x.
        final oldAtCurrentPace =
            (old['buffedDps'] as num) * CombatBalance.gameSpeed;
        expect(dps / oldAtCurrentPace, inExclusiveRange(.08, .30));
        expect(
          p.attackMultiplier / Progress.playerDamageScale,
          lessThanOrEqualTo(1.15),
        );
        expect(p.manaRecovery, lessThanOrEqualTo(8.400001));
        expect(p.rageOnHit(protected: true), lessThanOrEqualTo(3.675001));
        for (final (id, duration, key) in [
          ('warcry', p.warcryDuration, 'warcryDuration'),
          ('frenzy', p.frenzyDuration, 'frenzyDuration'),
          ('iceArmor', p.iceArmorDuration, 'iceArmorDuration'),
          ('frostNova', p.novaSlowDuration, 'novaSlowDuration'),
        ]) {
          if (p.rank(id) == 0) continue;
          final skill = p.skills.firstWhere((s) => s.id == id);
          expect(duration, lessThanOrEqualTo((old[key] as num).toDouble()));
          expect(duration, lessThan(p.skillCooldown(skill)));
        }
      },
    );
  }

  test(
    'D2 ranks preserve the shared damage scale and bounded weapon haste',
    () {
      final p = Progress()..level = 100;
      for (final skill in p.skills) {
        p.ranks[skill.id] = skill.rankLimit;
      }
      final bash = p.skills.firstWhere((s) => s.id == 'bash');
      expect(
        p.skillDamage(bash, atRank: 1),
        closeTo(p.swordDamage * 1.5 * CombatBalance.skillDamageScale, .000001),
      );
      expect(
        p.skillDamage(bash, atRank: 20),
        closeTo(p.swordDamage * 2.26 * CombatBalance.skillDamageScale, .000001),
      );
      p.equipped[GearSlot.charm] = Gear(
        999,
        const GearDef('haste-stress', '가속', GearSlot.charm, haste: .9),
      );
      p.frenzyStacks = 6;
      expect(p.attackHaste, .15);
      expect(p.frenzyAttackTempo, closeTo(1.24, .000001));
      expect(p.weaponCriticalChance, lessThanOrEqualTo(.15));
      expect(
        p.actualBasicInterval(frenzyTempo: p.frenzyAttackTempo),
        greaterThan(0),
      );
      final whirlwind = p.skills.firstWhere((s) => s.id == 'whirlwind');
      expect(
        [
          for (var r = 1; r <= 20; r++)
            p.skillTargetLimit(whirlwind, atRank: r),
        ],
        [for (var r = 1; r <= 20; r++) r + 2],
      );
      final damage = p.skillDamage(whirlwind);
      expect(
        damage * enemyGroupDamageScale(22),
        lessThan(damage * enemyGroupDamageScale(3)),
      );
      for (final id in ['bash', 'stun', 'concentrate', 'berserk']) {
        expect(p.skillTargetLimit(p.skills.firstWhere((s) => s.id == id)), 1);
      }
      expect(
        p.skillTargetLimit(p.skills.firstWhere((s) => s.id == 'doubleThrow')),
        2,
      );
      expect(
        p.skillTargetLimit(p.skills.firstWhere((s) => s.id == 'shadowAssault')),
        5,
      );
    },
  );

  test('each target perk rank adds one victim and damage still divides', () {
    for (final (hero, id, affected) in [
      (HeroClass.mage, 'cinderReach', 'meteor'),
      (HeroClass.mage, 'forkedStorm', 'chainLightning'),
    ]) {
      final p = ranked(hero, 1),
          skill = p.skills.firstWhere((s) => s.id == affected);
      final caps = <int>[];
      for (var rank = 1; rank <= 5; rank++) {
        p.ranks[id] = rank;
        caps.add(p.skillTargetLimit(skill));
      }
      expect(caps, [4, 5, 6, 7, 8]);
      final damage = p.skillDamage(skill);
      expect(
        damage * enemyGroupDamageScale(5),
        lessThan(damage * enemyGroupDamageScale(3)),
      );
    }
  });

  test(
    'saved ranks survive the nerf and previews use the same new derived values',
    () {
      for (final hero in const [HeroClass.mage]) {
        final p = ranked(hero, 5, stacked: true)..energy = 999;
        final ranks = Map<String, int>.of(p.ranks),
            gear = p.inventory.map((g) => g.toSave()).toList();
        final restored = Progress.fromSave(jsonDecode(jsonEncode(p.toSave())))!;
        expect(restored.ranks, ranks);
        expect(restored.inventory.map((g) => g.toSave()), gear);
        expect(restored.energy, restored.maxEnergy);
        for (final s in p.skills.where((s) => !s.passive && !s.mobility)) {
          expect(restored.skillDamage(s), p.skillDamage(s));
          expect(restored.skillCooldown(s), p.skillCooldown(s));
          expect(
            previewSkill(restored, s).first.current,
            restored.skillCooldown(s),
          );
        }
      }
    },
  );
}

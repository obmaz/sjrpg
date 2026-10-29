import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final heroClass in HeroClass.values) {
    test(
      '$heroClass revival fills both resources without healing a normal resume',
      () {
        final s = inCombatField(Adventure(GameArt(), heroClass: heroClass))
          ..start(TestGame());
        addTearDown(s.dispose);
        s.progress
          ..hp = 7
          ..energy = 0;
        s.afflictions.apply(PlayerStatus.poison);
        final checkpoint = GameCheckpoint.capture(s)!;
        final ordinary = checkpoint.restore(GameArt())..start(TestGame());
        addTearDown(ordinary.dispose);
        expect(ordinary.progress.hp, 7);
        expect(ordinary.progress.energy, 0);
        expect(ordinary.hero.revivalProtection, 0);
        expect(ordinary.afflictions.active, isNotEmpty);
        final retry = checkpoint.forRevival().restore(GameArt())
          ..start(TestGame());
        addTearDown(retry.dispose);
        expect(retry.progress.hp, retry.progress.maxHp);
        expect(retry.progress.energy, retry.progress.maxEnergy);
        expect(retry.afflictions.active, isEmpty);
        expect(retry.hero.revivalProtection, CombatBalance.revivalProtection);
        expect(checkpoint.progress.hp, 7);
        expect(checkpoint.progress.energy, 0);
        final hp = retry.progress.hp;
        retry.hurtHero(100, status: PlayerStatus.freeze, dispel: true);
        retry.hurtHero(100, periodic: true);
        expect(retry.progress.hp, hp);
        expect(retry.afflictions.active, isEmpty);
        retry.pause();
        retry.hero.update(1);
        expect(retry.hero.revivalProtection, CombatBalance.revivalProtection);
        retry.resume();
        retry.hero.dodge();
        for (
          var frame = 0;
          frame < (CombatBalance.revivalProtection / .05).round() - 1;
          frame++
        ) {
          retry.hero.update(.05);
        }
        retry.hurtHero(100, periodic: true);
        expect(retry.progress.hp, hp);
        retry.hero.update(.05);
        retry.hero.update(.01);
        expect(retry.hero.revivalProtection, 0);
        retry.hurtHero(1, periodic: true);
        expect(retry.progress.hp, lessThan(hp));
        final saved = GameCheckpoint.capture(retry)!;
        final later = saved.restore(GameArt());
        addTearDown(later.dispose);
        expect(
          later.hero.revivalProtection,
          0,
          reason: 'ordinary resume must never renew revival protection',
        );
      },
    );
  }
  test(
    'every enemy tier adds 20 percent XP without changing gold or kills',
    () {
      for (final (boss, elite, unique, xp, gold) in [
        (false, false, false, 12, 8),
        (false, true, false, 26, 20),
        (false, true, true, 38, 35),
        (true, false, false, 115, 100),
      ]) {
        final p = Progress();
        final beforeGold = p.gold;
        p.reward(boss: boss, elite: elite, unique: unique);
        var totalXp = p.xp;
        for (var level = 1; level < p.level; level++) {
          totalXp += CombatBalance.experienceForLevel(level);
        }
        expect(totalXp, xp);
        expect(p.gold - beforeGold, gold);
        expect(p.kills, 1);
        expect(p.bossDefeated, boss);
      }
    },
  );
  test(
    'original class-specific quantities preserve Barbarian per-point growth and Sorceress source caps',
    () {
      for (final (heroClass, ids) in [
        (
          HeroClass.warrior,
          [
            'cleave',
            'leap',
            'howl',
            'warcry',
            'battleCry',
            'grimWard',
            'whirlwind',
            'shadowAssault',
          ],
        ),
        (
          HeroClass.mage,
          [
            'firebolt',
            'iceBolt',
            'iceBlast',
            'telekinesis',
            'thunderStorm',
            'chargedBolt',
            'chainLightning',
            'frostNova',
            'nova',
            'staticField',
            'fireball',
            'blizzard',
            'frozenOrb',
            'hydra',
            'inferno',
            'blaze',
            'firewall',
            'meteor',
          ],
        ),
      ]) {
        final p = Progress(heroClass: heroClass);
        for (final id in ids) {
          final skill = p.skills.firstWhere((skill) => skill.id == id);
          var old = p.skillTargetLimit(skill, atRank: 1);
          expect(old, greaterThan(0), reason: id);
          for (var rank = 2; rank <= skill.rankLimit; rank++) {
            final next = p.skillTargetLimit(skill, atRank: rank);
            final expected = heroClass == HeroClass.warrior
                ? old + 1
                : switch (id) {
                    'chargedBolt' => 3 + rank - 1,
                    'chainLightning' => ((rank + 25) ~/ 5).clamp(0, rank + 2),
                    'firebolt' ||
                    'iceBolt' ||
                    'iceBlast' ||
                    'telekinesis' ||
                    'thunderStorm' => 1,
                    _ => rank + 2,
                  };
            expect(next, expected, reason: '$id rank$rank');
            old = next;
          }
        }
      }
      final p = Progress();
      for (final id in [
        'bash',
        'doubleSwing',
        'stun',
        'leapAttack',
        'concentrate',
        'frenzy',
        'berserk',
        'taunt',
        'findPotion',
        'findItem',
      ]) {
        final skill = p.skills.firstWhere((skill) => skill.id == id);
        for (var rank = 1; rank <= skill.rankLimit; rank++) {
          expect(
            p.skillTargetLimit(skill, atRank: rank),
            1,
            reason: '$id rank$rank',
          );
        }
      }
      final doubleThrow = p.skills.firstWhere(
        (skill) => skill.id == 'doubleThrow',
      );
      for (var rank = 1; rank <= doubleThrow.rankLimit; rank++) {
        expect(p.skillTargetLimit(doubleThrow, atRank: rank), 2);
      }
    },
  );
}

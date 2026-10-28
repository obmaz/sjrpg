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
  test('every enemy tier reduces XP without changing gold or kill rewards', () {
    for (final (boss, elite, unique, xp, gold) in [
      (false, false, false, 5, 8),
      (false, true, false, 11, 20),
      (false, true, true, 16, 35),
      (true, false, false, 48, 100),
    ]) {
      final p = Progress();
      final beforeGold = p.gold;
      p.reward(boss: boss, elite: elite, unique: unique);
      expect(p.xp, xp);
      expect(p.gold - beforeGold, gold);
      expect(p.kills, 1);
      expect(p.bossDefeated, boss);
    }
  });
  test(
    'each invested point increases every learned area target cap by one',
    () {
      for (final heroClass in HeroClass.values) {
        final p = Progress(heroClass: heroClass);
        for (final skill in p.skills.where((skill) => !skill.passive)) {
          var old = p.skillTargetLimit(skill, atRank: 1);
          if (old == 0 ||
              skill.id == 'quickCut' ||
              skill.id == 'heavyStrike' ||
              skill.id == 'iceShard') {
            continue;
          }
          for (var rank = 2; rank <= 5; rank++) {
            final next = p.skillTargetLimit(skill, atRank: rank);
            expect(next, old + 1, reason: '${skill.id} rank$rank');
            old = next;
          }
        }
      }
    },
  );
}

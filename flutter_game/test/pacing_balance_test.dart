import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/enemy_catalog.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('each class and rank uses restrained cooldown and motion growth', () {
    for (final hero in HeroClass.values) {
      final p = Progress(heroClass: hero)..gainXp(100000);
      for (final skill in p.skills.where((s) => !s.passive)) {
        for (var rank = 1; rank <= skill.rankLimit; rank++) {
          p.ranks[skill.id] = rank;
          expect(
            p.skillCooldown(skill),
            closeTo(
              skill.cooldown *
                  .9 *
                  (skill.rankLimit == 20 ? 1 : (1 - (rank - 1) * .02)),
              .000001,
            ),
          );
          expect(
            p.skillTempo(skill),
            closeTo(
              .75 * (1 + (rank - 1) * (skill.rankLimit == 20 ? .005 : .035)),
              .000001,
            ),
          );
        }
      }
    }
  });
  test('ordinary, elite and boss health is 80 percent of the old formula', () {
    for (final level in [1, 20]) {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      s.progress.level = level;
      s.mobs.clear();
      for (final (kind, boss, trait, x) in [
        ('goblin', false, EnemyTrait.none, 6000.0),
        ('wolf', false, EnemyTrait.armored, 6100.0),
        ('golem', true, EnemyTrait.none, 6200.0),
      ]) {
        final mob = s.spawnEnemy(
          kind,
          Offset(x, 4200),
          boss: boss,
          trait: trait,
        )!;
        final old =
            (boss ? 1800 : enemyCatalog[kind]!.health) *
            (boss ? 1 : trait.healthScale) *
            2 *
            (1 + (level - 1) * (boss ? .15 : .08));
        expect(mob.life.max, closeTo(old * .8, .000001));
        expect(mob.life.value, mob.life.max);
      }
    }
  });
  for (final oldBalance in [1, 2]) {
    test('balance $oldBalance migrates health ratio and cooldown once', () {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.spawnEnemy('goblin', const Offset(6000, 4200));
      s.spawnEnemy('golem', const Offset(6200, 4200), boss: true);
      final data = GameCheckpoint.capture(s)!.data;
      data['balance'] = oldBalance;
      data['cooldowns'] = {'warcry': 5.0};
      final enemy = data['enemies'][0] as Map, boss = data['boss'] as Map;
      enemy['hp'] = 28.0;
      enemy['maxHp'] = 56.0;
      boss['hp'] = oldBalance == 1 ? 900.0 : 1800.0;
      boss['maxHp'] = oldBalance == 1 ? 1800.0 : 3600.0;
      final decoded = GameCheckpoint.decode(jsonEncode(data))!;
      expect(decoded.data['balance'], 3);
      expect(decoded.data['enemies'][0]['hp'], closeTo(22.4, .000001));
      expect(decoded.data['enemies'][0]['maxHp'], closeTo(44.8, .000001));
      expect(decoded.data['boss']['hp'], 1440);
      expect(decoded.data['boss']['maxHp'], 2880);
      expect(decoded.data['cooldowns']['warcry'], 4.5);
      expect(GameCheckpoint.decode(decoded.encode())!.data, decoded.data);
    });
  }
}

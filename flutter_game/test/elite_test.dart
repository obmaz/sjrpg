import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  setUp(() {
    s = Adventure(GameArt());
    s.start(TestGame());
    s.mobs.clear();
    s.hero.position.setValues(6000, 4200);
  });
  tearDown(() => s.dispose());
  test('traits scale health and movement but never change boss statistics', () {
    final normal = HuntEnemy(s, 'goblin', const Offset(6100, 4200));
    final armored = HuntEnemy(
      s,
      'goblin',
      const Offset(6100, 4200),
      trait: EnemyTrait.armored,
    );
    final swift = HuntEnemy(
      s,
      'goblin',
      const Offset(6100, 4200),
      trait: EnemyTrait.swift,
    );
    expect(armored.life.max, closeTo(normal.life.max * 1.8, .001));
    expect(armored.speed, normal.speed);
    expect(swift.life.max, closeTo(normal.life.max * 1.35, .001));
    expect(swift.speed, closeTo(normal.speed * 1.2, .001));
    final boss = s.spawnEnemy(
      'golem',
      const Offset(6400, 4200),
      boss: true,
      trait: EnemyTrait.swift,
    )!;
    expect(boss.isElite, false);
    expect(boss.trait, EnemyTrait.none);
    expect(boss.life.max, 3600);
    expect(boss.speed, 90);
    expect(s.world.blocked(boss.body), false);
  });
  test('opening packs stay ordinary; later packs alternate bounded elites', () {
    for (var i = 0; i < 5; i++) {
      s.spawnPack();
      expect(s.mobs.any((m) => m.isElite), false);
      s.mobs.clear();
    }
    final opening = s.encounterAreas[s.encounterKey];
    if (opening != null && opening.waves >= 3) {
      s.hero.position.setValues(opening.stone.dx - 12, opening.stone.dy - 11);
      for (var hit = 0; hit < 3; hit++) {
        s.strikeEncounterStone(100);
      }
    }
    s.progress.kills = 18;
    s.progress.level = 3;
    s.spawnPack(initial: true);
    expect(s.mobs.any((m) => m.isElite), false);
    s.mobs.clear();
    final found = <EnemyTrait>[];
    for (var i = 0; i < 12; i++) {
      final area = s.encounterAreas[s.encounterKey];
      if (area != null && area.waves >= 3) {
        s.hero.position.setValues(area.stone.dx - 12, area.stone.dy - 11);
        for (var hit = 0; hit < 3; hit++) {
          expect(s.strikeEncounterStone(100), true);
        }
      }
      s.spawnPack();
      final elites = s.mobs.where((m) => m.isElite).toList();
      expect(elites.length, lessThanOrEqualTo(1));
      found.addAll(elites.map((m) => m.trait));
      expect(s.mobs.every((m) => !s.world.blocked(m.body)), true);
      s.mobs.clear();
    }
    expect(found.length, 4);
    expect(found.toSet(), {EnemyTrait.armored, EnemyTrait.swift});
  });
  test(
    'a living elite blocks additional elites and paused packs do not spawn',
    () {
      s.progress.kills = 18;
      s.progress.level = 3;
      s.spawnEnemy(
        'goblin',
        const Offset(6400, 4200),
        trait: EnemyTrait.armored,
      );
      for (var i = 0; i < 8; i++) {
        s.mobs.removeWhere((m) => !m.isElite);
        s.spawnPack();
        expect(s.mobs.where((m) => m.isElite).length, 1);
      }
      final count = s.mobs.length;
      s.pause();
      s.spawnPack();
      expect(s.mobs.length, count);
    },
  );
  for (final hero in HeroClass.values) {
    test(
      'elite reward grants one magic-or-better drop and one kill for $hero',
      () {
        final session = Adventure(GameArt(), heroClass: hero);
        session.start(TestGame());
        addTearDown(session.dispose);
        session.mobs.clear();
        session.progress.kills = 2;
        final elite = session.spawnEnemy(
          'goblin',
          const Offset(6100, 4200),
          trait: EnemyTrait.armored,
        )!;
        final gold = session.progress.gold, xp = session.progress.xp;
        session.hit(elite, 100000, Offset.zero);
        expect(session.progress.kills, 3);
        expect(session.progress.gold, gold + 20);
        expect(session.progress.xp, xp + 18);
        expect(session.loot.length, 1);
        expect(session.loot.single.item.rarity, Rarity.rare);
        session.hit(elite, 100000, Offset.zero);
        expect(session.progress.kills, 3);
        expect(session.progress.gold, gold + 20);
        expect(session.loot.length, 1);
        final p = session.progress;
        for (var seed = 0; seed < 100; seed++) {
          final gear = p.rollLoot(math.Random(seed), elite: true);
          expect(gear.rarity.index, greaterThanOrEqualTo(Rarity.magic.index));
          expect(gear.base.usable(hero), true);
        }
        expect(
          p.rollLoot(math.Random(1), boss: true, elite: true).rarity,
          Rarity.rare,
        );
      },
    );
  }
}

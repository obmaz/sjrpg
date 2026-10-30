import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/enemy_difficulty.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('chapter branches share 20-level bands with bosses at their cap', () {
    for (final stage in WorldStage.values) {
      final chapter = switch (stage) {
        WorldStage.forest => 1,
        WorldStage.sands => 2,
        WorldStage.past || WorldStage.future => 3,
        WorldStage.tombs || WorldStage.foundry => 4,
        WorldStage.convergence => 5,
      };
      final levels = [
        for (final d in [0.0, 4000.0, 12000.0, 28000.0, 43200.0])
          EnemyPower.atDistance(stage: stage, distance: d).level,
      ];
      expect(levels.first, chapter * 20 - 19);
      expect(levels.last, chapter * 20 - 1);
      expect(levels, orderedEquals([...levels]..sort()));
      expect(
        EnemyPower.atDistance(stage: stage, distance: 0, boss: true).level,
        chapter * 20,
      );
    }
  });
  test('species grow different strengths at the same level', () {
    EnemyPower power(String kind, double distance) => EnemyPower.atDistance(
      stage: WorldStage.convergence,
      distance: distance,
      kind: kind,
    );
    final tank = power('troll', 28000),
        attacker = power('wolf', 28000),
        armored = power('skeleton', 28000);
    expect(tank.healthMultiplier, greaterThan(attacker.healthMultiplier));
    expect(attacker.damageMultiplier, greaterThan(tank.damageMultiplier));
    expect(armored.defense, greaterThan(tank.defense));
    expect(attacker.defense, 0);
    for (final kind in ['goblin', 'troll', 'wolf', 'skeleton', 'cultist']) {
      final low = power(kind, 0), high = power(kind, 28000);
      expect(high.level, greaterThan(low.level));
      expect(high.healthMultiplier, greaterThan(low.healthMultiplier));
      expect(high.damageMultiplier, greaterThan(low.damageMultiplier));
      expect(high.defense, greaterThanOrEqualTo(low.defense));
    }
  });
  test('player level no longer scales newly spawned enemy health', () {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    final first = s.spawnEnemy('goblin', const Offset(6100, 4200))!;
    final hp = first.life.max, level = first.power.level;
    s.mobs.clear();
    s.progress.level = 70;
    final later = s.spawnEnemy('goblin', const Offset(6100, 4200))!;
    expect(later.life.max, hp);
    expect(later.power.level, level);
  });
  test('armor changes actual and displayed damage once', () {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    final power = EnemyPower.atDistance(
      stage: WorldStage.convergence,
      distance: 28000,
      kind: 'skeleton',
    );
    final enemy = s.spawnEnemy(
      'skeleton',
      const Offset(6100, 4200),
      power: power,
    )!;
    final hp = enemy.life.value;
    expect(s.hit(enemy, 100, Offset.zero), true);
    final damage = power.mitigate(100);
    expect(enemy.life.value, closeTo(hp - damage, .000001));
    expect(s.texts.last.label, damage.round().toString());
  });
  test('saved levels survive pursuit, dormancy and stage travel snapshots', () {
    final s = inCombatField(Adventure(GameArt(), stage: WorldStage.sands))
      ..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    final enemy = s.spawnEnemy(
      'mummy',
      s.hero.body.center + const Offset(130, 0),
    )!;
    enemy.life.update(enemy.life.max * .4);
    final saved = enemy.power.toSave();
    final checkpoint = GameCheckpoint.decode(
      GameCheckpoint.capture(s)!.encode(),
    )!;
    final restored = checkpoint.restore(GameArt())..start(TestGame());
    addTearDown(restored.dispose);
    final again = restored.mobs.single;
    expect(again.power.toSave(), saved);
    expect(again.life.value / again.life.max, closeTo(.4, .00001));
    again.position.setValues(28000, 22000);
    restored.progress.level = 99;
    expect(again.power.toSave(), saved);
    final raw = jsonDecode(checkpoint.encode()) as Map<String, dynamic>;
    final record = (raw['enemies'] as List).single as Map;
    record['power'] = {'distance': 16000.0, 'health': 1.5, 'damage': 1.1};
    record['hp'] = 40.0;
    record['maxHp'] = 100.0;
    final migrated = GameCheckpoint.decode(jsonEncode(raw))!;
    final updated = (migrated.data['enemies'] as List).single as Map;
    expect(updated['power']['level'], greaterThan(20));
    expect(
      (updated['hp'] as num) / (updated['maxHp'] as num),
      closeTo(.4, .00001),
    );
    expect(
      GameCheckpoint.decode(migrated.encode())!.data['enemies'],
      migrated.data['enemies'],
    );
    updated['power']['level'] = 100;
    expect(GameCheckpoint.decode(migrated.encode()), isNull);
  });
  test(
    'legacy player-level health is replaced canonically in active and dormant records',
    () {
      final s = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.progress.level = 70;
      final enemy = s.spawnEnemy(
        'wolf',
        const Offset(6100, 4200),
        trait: EnemyTrait.armored,
      )!;
      final canonical = enemy.life.max;
      final data =
          jsonDecode(GameCheckpoint.capture(s)!.encode())
              as Map<String, dynamic>;
      final record = (data['enemies'] as List).single as Map;
      final power = enemy.power;
      record['power'] = {
        'distance': power.spawnDistance,
        'health': power.healthMultiplier,
        'damage': power.damageMultiplier,
      };
      record['maxHp'] = canonical * (1 + 69 * .08);
      record['hp'] = (record['maxHp'] as num) * .37;
      final migrated = GameCheckpoint.decode(jsonEncode(data))!;
      final current = (migrated.data['enemies'] as List).single as Map;
      expect(current['maxHp'], closeTo(canonical, .000001));
      expect(
        (current['hp'] as num) / (current['maxHp'] as num),
        closeTo(.37, .000001),
      );
      final active = migrated.restore(GameArt())..start(TestGame());
      addTearDown(active.dispose);
      expect(active.mobs.single.life.max, closeTo(canonical, .000001));
      expect(
        active.mobs.single.life.value / active.mobs.single.life.max,
        closeTo(.37, .000001),
      );
      record['x'] = 25000.0;
      record['y'] = 16000.0;
      final dormant = GameCheckpoint.decode(
        jsonEncode(data),
      )!.restore(GameArt())..start(TestGame());
      addTearDown(dormant.dispose);
      expect(dormant.mobs, isEmpty);
      expect(
        dormant.dormantEnemies.single['maxHp'],
        closeTo(canonical, .000001),
      );
      expect(
        (dormant.dormantEnemies.single['hp'] as num) /
            (dormant.dormantEnemies.single['maxHp'] as num),
        closeTo(.37, .000001),
      );
      final roundtrip = GameCheckpoint.decode(
        GameCheckpoint.capture(dormant)!.encode(),
      )!;
      expect(
        (roundtrip.data['enemies'] as List).single['maxHp'],
        closeTo(canonical, .000001),
      );
    },
  );

  test(
    'archived enemies lose old player-level inflation without healing wounds',
    () {
      final forest = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(forest.dispose);
      forest.mobs.clear();
      forest.progress.level = 70;
      final enemy = forest.spawnEnemy('skeleton', const Offset(6100, 4200))!;
      final expected = enemy.life.max;
      forest.cleansedSites.addAll(forest.world.sites.map((site) => site.id));
      forest.progress.bossDefeated = true;
      forest.progress.kills = 120;
      final data = GameCheckpoint.advance(forest)!.data;
      final record =
          (data['travel']['archives']['forest']['enemies'] as List).single
              as Map;
      record['power'] = {
        'distance': enemy.power.spawnDistance,
        'health': enemy.power.healthMultiplier,
        'damage': enemy.power.damageMultiplier,
      };
      record['maxHp'] = expected * (1 + 69 * .08);
      record['hp'] = (record['maxHp'] as num) * .23;
      final checkpoint = GameCheckpoint.decode(jsonEncode(data))!;
      final migrated =
          (checkpoint.data['travel']['archives']['forest']['enemies'] as List)
                  .single
              as Map;
      expect(migrated['maxHp'], closeTo(expected, .000001));
      expect(
        (migrated['hp'] as num) / (migrated['maxHp'] as num),
        closeTo(.23, .000001),
      );
      expect(
        GameCheckpoint.decode(checkpoint.encode())!.data['travel'],
        checkpoint.data['travel'],
      );
    },
  );
}

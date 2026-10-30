import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/enemy_difficulty.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

class WakeBudgetAdventure extends Adventure {
  WakeBudgetAdventure() : super(GameArt());
  int attempts = 0, populationReads = 0;
  bool rejectSpawns = true;

  @override
  int get living {
    populationReads++;
    return super.living;
  }

  @override
  HuntEnemy? spawnEnemy(
    String kind,
    Offset desired, {
    bool boss = false,
    EnemyTrait trait = EnemyTrait.none,
    EnemyTier? tier,
    EnemyPower? power,
    Offset? home,
    bool reserveSpacing = false,
    Rect? reservedBody,
  }) {
    attempts++;
    return rejectSpawns
        ? null
        : super.spawnEnemy(
            kind,
            desired,
            boss: boss,
            trait: trait,
            tier: tier,
            power: power,
            home: home,
            reserveSpacing: reserveSpacing,
            reservedBody: reservedBody,
          );
  }
}

Map<String, dynamic> dormantAt(Offset at) => {
  'kind': 'goblin',
  'trait': 'none',
  'tier': 'normal',
  'power': const EnemyPower(0, 1, 1).toSave(),
  'wardPhase': 0.0,
  'area': null,
  'x': at.dx,
  'y': at.dy,
  'hp': 11.0,
  'maxHp': 37.0,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'blocked wake positions have a bounded retry budget and rotate fairly',
    () {
      final s = inCombatField(WakeBudgetAdventure());
      addTearDown(s.dispose);
      final first = dormantAt(s.hero.body.center + const Offset(200, 0));
      s.dormantEnemies.add(first);
      for (var i = 1; i < 5000; i++) {
        s.dormantEnemies.add(
          dormantAt(s.hero.body.center + Offset(200, i % 600)),
        );
      }
      s.wakeEnemies();
      expect(s.attempts, lessThanOrEqualTo(16));
      expect(s.populationReads, lessThanOrEqualTo(2));
      expect(s.dormantEnemies, hasLength(5000));
      expect(identical(s.dormantEnemies.first, first), false);
      expect(s.progress.kills, 0);
    },
  );

  test(
    'waking preserves health and capacity without revisiting a full crowd',
    () {
      final s = inCombatField(WakeBudgetAdventure())
        ..rejectSpawns = false
        ..restoredEncounters = true
        ..start(TestGame());
      addTearDown(s.dispose);
      for (var i = 0; i < 60; i++) {
        s.dormantEnemies.add(
          dormantAt(
            s.hero.body.center + Offset(200 + i % 10 * 45, i ~/ 10 * 45),
          ),
        );
      }
      for (var i = 0; i < 5; i++) {
        s.elapsed += .6;
        s.wakeEnemies();
      }
      expect(s.living, 30);
      expect(s.dormantEnemies, hasLength(30));
      expect(s.mobs.every((m) => m.life.value == 11 && m.life.max == 37), true);
      s.attempts = s.populationReads = 0;
      s.elapsed += .6;
      s.wakeEnemies();
      expect(s.attempts, 0);
      expect(s.populationReads, lessThanOrEqualTo(2));
      expect(s.progress.kills, 0);
    },
  );
}

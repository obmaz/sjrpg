import 'dart:convert';
import 'dart:io';

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/enemy_difficulty.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

import 'test_game.dart';

class CrowdProbeWorld extends AdventureWorld {
  CrowdProbeWorld({super.stage});
  bool recording = false, heroSheltered = false;
  Offset heroGoal = Offset.zero;
  int frame = 0;
  final cornerSearchFrames = <int>{};

  @override
  bool clearEnemyLine(Offset from, Offset to, Size size) {
    // Normal pursuit checks the hero or24px terrain lattice nodes. Fractional
    // local-corner queries identify bounded searches without runtime hooks.
    // Sheltered patrols also check fractional goals, but cannot pursue at all.
    if (recording &&
        !heroSheltered &&
        size == const Size(24, 22) &&
        to != heroGoal &&
        (to.dx % 24 != 0 || to.dy % 24 != 0)) {
      cornerSearchFrames.add(frame);
    }
    return super.clearEnemyLine(from, to, size);
  }
}

class CrowdFixture extends Adventure {
  CrowdFixture({super.stage})
    : observed = CrowdProbeWorld(stage: stage),
      super(GameArt());
  final CrowdProbeWorld observed;
  bool historicalCrowd = false;
  int birthCursor = 0;
  @override
  AdventureWorld get world => observed;
}

CrowdFixture sandsCrowd() {
  final s = CrowdFixture(stage: WorldStage.sands)..start(TestGame());
  expect(s.mobs, isEmpty);
  // Replay the captured field position, independent of the safety shape.
  final expectedHero = _historicalData['hero'] as Map;
  final at = Offset(
    (expectedHero['x'] as num).toDouble(),
    (expectedHero['y'] as num).toDouble(),
  );
  s.hero.position.setValues(at.dx, at.dy);
  expect(s.hero.position.toOffset(), at);
  s.hero.lastClearPosition = s.hero.position.toOffset();
  s.progress.bonusHealth = 2000; // Keep the stationary diagnostic hero alive.
  s.progress.hp = s.progress.maxHp;
  s.syncLife();
  expect(s.sheltered, false);
  expect(s.world.blocked(s.hero.body), false);
  s.observed.recording = true;
  s.historicalCrowd = true;
  return s;
}

void assertCrowdBodies(Adventure s) {
  for (final m in s.mobs) {
    if (m.isDead) continue;
    expect(s.world.blocksEnemy(m.body), false);
    expect(m.body.overlaps(s.hero.body), false);
    for (final other in s.mobs) {
      if (other != m && !other.isDead) {
        expect(m.body.overlaps(other.body), false);
      }
    }
  }
}

// Keep historical birth timing and kinds independent of future pack sizes.
// Positions were captured through spawnEnemy beside the complete settlement ward.
final _historicalData =
    jsonDecode(
          File('test/fixtures/crowd_mobile70_births.json').readAsStringSync(),
        )
        as Map<String, dynamic>;
final _historicalBirths = _historicalData['births'] as List;

void stepCrowd(CrowdFixture s, double dt) {
  if (dt > 0) s.observed.frame++;
  s.observed.heroGoal = s.hero.position.toOffset();
  if (s.historicalCrowd) s.waveTime = 10000;
  s.tick(dt);
  s.observed.heroSheltered = s.sheltered;
  if (s.historicalCrowd && dt > 0) {
    while (s.birthCursor < _historicalBirths.length) {
      final birth = _historicalBirths[s.birthCursor] as Map;
      final frame = birth['frame'] as int;
      final time = frame == 0 ? 0.0 : (frame + 1) / 30;
      if (s.elapsed + 1e-8 < time) break;
      final enemy = birth['enemy'] as Map;
      final at = Offset(
        (enemy['x'] as num).toDouble(),
        (enemy['y'] as num).toDouble(),
      );
      final mob = s.spawnEnemy(
        enemy['kind'] as String,
        at,
        power: EnemyPowerSave.fromSave(enemy['power']),
      )!;
      expect(
        mob.body.topLeft,
        at,
        reason: 'historic stress births must remain walkable',
      );
      expect(mob.life.max, enemy['maxHp']);
      mob.encounterKey = enemy['area'] as String;
      s.birthCursor++;
    }
  }
  for (final m in s.mobs.toList()) {
    m.update(dt);
    assertCrowdBodies(s);
  }
}

double heroDistance(Adventure s, HuntEnemy m) =>
    (m.body.center - s.hero.body.center).distance;

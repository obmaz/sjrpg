import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

import 'test_game.dart';

class CrowdProbeWorld extends AdventureWorld {
  CrowdProbeWorld({super.stage});
  bool recording = false;
  Offset heroGoal = Offset.zero;
  int frame = 0;
  final cornerSearchFrames = <int>{};

  @override
  bool clearEnemyLine(Offset from, Offset to, Size size) {
    // Normal pursuit checks the hero or24px terrain lattice nodes. Fractional
    // local-corner queries identify bounded searches without runtime hooks.
    if (recording &&
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
  @override
  AdventureWorld get world => observed;
}

CrowdFixture sandsCrowd() {
  final s = CrowdFixture(stage: WorldStage.sands)..start(TestGame());
  expect(s.mobs, isEmpty);
  s.hero.position.setValues(5716.6240234375, 6772.603515625);
  s.hero.lastClearPosition = s.hero.position.toOffset();
  s.progress.bonusHealth = 2000; // Keep the stationary diagnostic hero alive.
  s.progress.hp = s.progress.maxHp;
  s.syncLife();
  expect(s.sheltered, false);
  expect(s.world.blocked(s.hero.body), false);
  s.observed.recording = true;
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

void stepCrowd(CrowdFixture s, double dt) {
  if (dt > 0) s.observed.frame++;
  s.observed.heroGoal = s.hero.position.toOffset();
  s.tick(dt);
  for (final m in s.mobs.toList()) {
    m.update(dt);
    assertCrowdBodies(s);
  }
}

double heroDistance(Adventure s, HuntEnemy m) =>
    (m.body.center - s.hero.body.center).distance;

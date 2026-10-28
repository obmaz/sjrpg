import 'dart:math' as math;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/encounters.dart';

import 'support/crowd_fixture.dart';
import 'support/sanctuary_fixture.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CrowdFixture activeDetour() {
    final s = sandsCrowd();
    for (var frame = 0; frame <= 353; frame++) {
      stepCrowd(s, 1 / 30);
    }
    expect(s.observed.cornerSearchFrames.length, 1);
    return s;
  }

  test(
    'historical dense melee mob escapes ranged crowd within6sim seconds',
    () {
      final s = sandsCrowd();
      addTearDown(s.dispose);
      for (var frame = 0; frame <= 350; frame++) {
        stepCrowd(s, 1 / 30);
      }
      final m = s.mobs[9], stalled = heroDistance(s, s.mobs[9]);
      expect(m.kind, 'scorpion');
      expect(stalled, greaterThan(m.idleRange + 80));
      var nearest = stalled;
      for (var frame = 0; frame < 180; frame++) {
        stepCrowd(s, 1 / 30);
        nearest = math.min(nearest, heroDistance(s, m));
      }
      expect(nearest, lessThan(stalled - 80));
      expect(s.progress.hp, greaterThan(0));
      expect(s.observed.cornerSearchFrames.length, 1);
    },
  );

  test('historical60Hz waves also escape without repeated corner searches', () {
    final s = sandsCrowd();
    addTearDown(s.dispose);
    var nearest = double.infinity;
    for (var frame = 0; frame < 1200; frame++) {
      stepCrowd(s, 1 / 60);
      if (s.mobs.length > 9) {
        nearest = math.min(nearest, heroDistance(s, s.mobs[9]));
      }
    }
    expect(nearest, lessThan(123));
    expect(s.observed.cornerSearchFrames.length, 1);
    expect(s.progress.hp, greaterThan(0));
  });

  test('isolated historical pursuer uses ordinary chase', () {
    final s = sandsCrowd();
    addTearDown(s.dispose);
    for (var frame = 0; frame <= 301; frame++) {
      stepCrowd(s, 1 / 30);
    }
    final m = s.mobs[9];
    s.mobs.retainWhere((other) => other == m);
    s.dormantEnemies.clear();
    s.waveTime = 10000;
    s.observed.cornerSearchFrames.clear();
    for (var frame = 0; frame < 200; frame++) {
      stepCrowd(s, 1 / 30);
    }
    expect(heroDistance(s, m), lessThan(m.idleRange + 5));
    expect(s.observed.cornerSearchFrames, isEmpty);
  });

  test('12 uncrowded pursuers need no local detour', () {
    final s = inCombatField(CrowdFixture())..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    s.dormantEnemies.clear();
    s.progress.bonusHealth = 2000;
    s.progress.hp = s.progress.maxHp;
    s.syncLife();
    s.waveTime = 10000;
    s.observed.recording = true;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      expect(
        s.spawnEnemy(
          'goblin',
          s.hero.body.center +
              Offset(math.cos(angle), math.sin(angle)) * 900 -
              const Offset(12, 11),
        ),
        isNotNull,
      );
    }
    for (final key in {
      EncounterArea.keyAt(s.hero.body.center),
      for (final m in s.mobs) EncounterArea.keyAt(m.body.center),
    }) {
      s.encounterAreas[key] = EncounterArea(key, s.hero.body.center, waves: 3);
    }
    for (var frame = 0; frame < 200; frame++) {
      stepCrowd(s, 1 / 30);
    }
    expect(s.observed.cornerSearchFrames, isEmpty);
    final distances = s.mobs.map((m) => heroDistance(s, m)).toList()..sort();
    expect(distances[distances.length ~/ 2], lessThan(300));
  });

  test('zero dt preserves intent while combat and hero changes release it', () {
    for (final mode in [
      'zeroDt',
      'stun',
      'hurt',
      'windup',
      'heroMove',
      'dead',
    ]) {
      final s = activeDetour(),
          m = s.mobs[9],
          origin = s.mobs[9].position.toOffset();
      final searches = s.observed.cornerSearchFrames.length;
      if (mode == 'zeroDt') {
        for (var frame = 0; frame < 100; frame++) {
          stepCrowd(s, 0);
        }
        expect(m.position.toOffset(), origin);
        expect(s.observed.cornerSearchFrames.length, searches);
        for (var frame = 0; frame < 8; frame++) {
          stepCrowd(s, 1 / 30);
        }
        expect((m.position.toOffset() - origin).distance, greaterThan(1));
      } else if (mode == 'dead') {
        m.life.remove(m.life.value);
        stepCrowd(s, 1 / 30);
        expect(m.position.toOffset(), origin);
      } else {
        if (mode == 'stun') m.stun = 1;
        if (mode == 'hurt') m.hurt = 1;
        if (mode == 'windup') m.windup = 1;
        if (mode == 'heroMove') {
          final gate = safetyGate(s.world);
          final hero = s.hero.position.toOffset(),
              target = gate.boundary - gate.outward * 30 - const Offset(14, 12);
          expect(s.world.sanctuary.protects(target & s.hero.body.size), true);
          expect(s.world.blocked(target & s.hero.body.size), false);
          expect(
            s.mobs.any(
              (other) => (target & s.hero.body.size).overlaps(other.body),
            ),
            false,
          );
          s.hero.position.setValues(target.dx, target.dy);
          stepCrowd(s, 1 / 30);
          s.hero.position.setValues(hero.dx, hero.dy);
        } else {
          for (var frame = 0; frame < 31; frame++) {
            stepCrowd(s, 1 / 30);
          }
        }
        for (var frame = 0; frame < 6; frame++) {
          stepCrowd(s, 1 / 30);
        }
        if (mode == 'heroMove') {
          expect(
            (m.position.toOffset() - origin).distance,
            lessThan(1),
            reason:
                'entering the ward cancels the retreat; only brief patrol inertia remains',
          );
        } else {
          expect(
            m.position.toOffset(),
            origin,
            reason:
                '$mode must release the committed retreat before ordinary pursuit can retry',
          );
        }
        expect(s.observed.cornerSearchFrames.length, searches);
      }
      s.dispose();
    }
  });

  test('unchanged enclosure cannot retry on clock alone', () {
    final s = inCombatField(CrowdFixture())..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    s.dormantEnemies.clear();
    s.waveTime = 10000;
    s.observed.recording = true;
    final m = s.spawnEnemy('goblin', const Offset(6500, 4200))!;
    final blockers = [
      for (final d in [
        const Offset(-30, 0),
        const Offset(30, 0),
        const Offset(0, -30),
        const Offset(0, 30),
      ])
        s.spawnEnemy('goblin', const Offset(6500, 4200) + d)!..stun = 100,
    ];
    for (var frame = 0; frame < 200; frame++) {
      stepCrowd(s, 1 / 30);
    }
    expect(s.observed.cornerSearchFrames.length, 1);
    blockers.first.position.x -= 7;
    s.updateEnemySpacing(blockers.first);
    for (var frame = 0; frame < 200; frame++) {
      stepCrowd(s, 1 / 30);
    }
    expect(s.observed.cornerSearchFrames.length, 2);
    expect(m.position.toOffset(), const Offset(6500, 4200));
  });

  test('deadline watches new blockers and permits changed-scene retries', () {
    final s = activeDetour(), trapped = s.mobs[9];
    addTearDown(s.dispose);
    s.mobs.retainWhere((m) => m == trapped);
    s.dormantEnemies.clear();
    s.waveTime = 10000;
    final from = trapped.position.toOffset();
    final blockers = [
      for (final d in [
        const Offset(-30, 0),
        const Offset(30, 0),
        const Offset(0, -30),
        const Offset(0, 30),
      ])
        s.spawnEnemy('goblin', from + d)!..stun = 100,
    ];
    final originalSearches = s.observed.cornerSearchFrames.length;
    for (var frame = 0; frame < 200; frame++) {
      stepCrowd(s, 1 / 30);
    }
    expect(s.observed.cornerSearchFrames.length, originalSearches);
    expect(trapped.position.toOffset(), from);
    blockers.first.position.x -= 7;
    s.updateEnemySpacing(blockers.first);
    for (var frame = 0; frame < 100; frame++) {
      stepCrowd(s, 1 / 30);
    }
    expect(s.observed.cornerSearchFrames.length, originalSearches + 1);
    s.world.openedChests.add(0);
    for (var frame = 0; frame < 100; frame++) {
      stepCrowd(s, 1 / 30);
    }
    expect(s.observed.cornerSearchFrames.length, originalSearches + 2);
    for (final blocker in blockers) {
      blocker.life.remove(blocker.life.value);
    }
    final oldDistance = heroDistance(s, trapped);
    for (var frame = 0; frame < 100; frame++) {
      stepCrowd(s, 1 / 30);
    }
    expect(heroDistance(s, trapped), lessThan(oldDistance - 40));
  });

  test('a noncluster corner blocker changing permits exactly one retry', () {
    final s = sandsCrowd();
    addTearDown(s.dispose);
    for (var frame = 0; frame <= 350; frame++) {
      stepCrowd(s, 1 / 30);
    }
    final m = s.mobs[9], a = s.mobs[1], b = s.mobs[7];
    s.waveTime = 10000;
    Rect envelope(HuntEnemy other) => Rect.fromCenter(
      center: other.body.center,
      width: m.personalSpace.width + other.personalSpace.width,
      height: m.personalSpace.height + other.personalSpace.height,
    );
    final rawBounds = envelope(a).expandToInclude(envelope(b)),
        margin = m.body.shortestSide / 2,
        corner = rawBounds.inflate(margin).bottomRight,
        reach = (m.personalSpace.height + b.personalSpace.height) / 2;
    final outsider = s.spawnEnemy(
      'goblin',
      corner + Offset(0, reach * .95) - const Offset(12, 11),
    )!..stun = 100;
    expect(
      envelope(outsider).overlaps(rawBounds),
      false,
      reason: 'not part of the primary connected cluster',
    );
    expect(
      (outsider.body.center - corner).distance,
      lessThan(reach),
      reason: 'still blocks its inflated exterior corner',
    );
    // The painted polygon leaves the alternate upper entry in open field.
    // Occupy that entry explicitly instead of relying on the old, oversized
    // circular ward to reject it invisibly; the lower escape stays open.
    final upperCorner = rawBounds.inflate(margin).topLeft;
    final upperBlocker = s.spawnEnemy(
      'goblin',
      upperCorner - Offset(0, reach * .95) - const Offset(12, 11),
    )!..stun = 100;
    expect(envelope(upperBlocker).overlaps(rawBounds), false);
    expect((upperBlocker.body.center - upperCorner).distance, lessThan(reach));
    for (var frame = 0; frame < 100; frame++) {
      stepCrowd(s, 1 / 30);
    }
    expect(s.observed.cornerSearchFrames.length, 1);
    final stillFar = heroDistance(s, m);
    outsider.position.y += 7;
    s.updateEnemySpacing(outsider);
    for (var frame = 0; frame < 180; frame++) {
      stepCrowd(s, 1 / 30);
    }
    expect(
      s.observed.cornerSearchFrames.length,
      2,
      reason: 'one new search after actual noncluster rejector changes',
    );
    expect(heroDistance(s, m), lessThan(stillFar - 80));
  });
}

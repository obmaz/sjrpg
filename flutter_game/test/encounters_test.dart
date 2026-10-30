import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/encounters.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  setUp(() {
    s = inCombatField(Adventure(GameArt()))..start(TestGame());
  });
  tearDown(() => s.dispose());
  void clear() {
    for (final m in s.mobs.toList()) {
      s.hit(m, 100000, Offset.zero);
    }
    s.mobs.clear();
  }

  test('a cleared region only respawns after a charged stone is struck', () {
    final area = s.encounterAreas[s.encounterKey]!;
    expect(area.waves, 1);
    expect(s.strikeEncounterStone(100), false);
    clear();
    s.spawnPack();
    s.tick(30);
    expect(
      s.living,
      0,
      reason: 'the periodic director cannot refill this region',
    );
    s.hero.position.setValues(
      area.stone.dx - 60,
      area.stone.dy - s.hero.body.height / 2,
    );
    s.pause();
    expect(s.strikeEncounterStone(100), false);
    s.resume();
    for (var i = 0; i < 3; i++) {
      expect(s.strikeEncounterStone(100), true);
      expect(area.charges, 2 - i);
      expect(s.living, greaterThan(0));
      expect(
        s.strikeEncounterStone(100),
        false,
        reason: 'living enemies prevent stacking',
      );
      clear();
    }
    expect(s.strikeEncounterStone(100), false);
    s.tick(EncounterArea.rechargeSeconds - .01);
    expect(area.charges, 0);
    expect(s.living, 0);
    s.tick(.01);
    expect(area.charges, 1);
    expect(s.living, 0, reason: 'a recharge alone never spawns');
    expect(s.strikeEncounterStone(100), true);
    expect(area.charges, 0);
  });
  test(
    'stone footprints block walking and restore without trapping a player',
    () {
      final area = s.encounterAreas[s.encounterKey]!;
      expect(s.world.blocked(area.body), true);
      expect(area.body.overlaps(s.hero.body), false);
      final from = area.stone - const Offset(70, 10);
      final moved = s.world.move(
        from,
        const Offset(140, 0),
        const Size(20, 20),
      );
      expect(moved.dx, lessThan(area.stone.dx));
      expect(area.body.overlaps(moved & const Size(20, 20)), false);
      final cp = GameCheckpoint.capture(s)!;
      cp.data['x'] = area.stone.dx - s.hero.body.width / 2;
      cp.data['y'] = area.stone.dy - s.hero.body.height / 2;
      final restored = cp.restore(GameArt())..start(TestGame());
      addTearDown(restored.dispose);
      expect(area.body.overlaps(restored.hero.body), false);
    },
  );
  test(
    'a charge takes five real minutes and partial progress survives reload',
    () {
      clear();
      final area = s.encounterAreas[s.encounterKey]!;
      area.charges = 0;
      expect(area.remainingSeconds, 300);
      s.tick(EncounterArea.rechargeSeconds / 2);
      expect(area.remainingSeconds, 150);
      s.pause();
      s.tick(EncounterArea.rechargeSeconds);
      s.resume();
      expect(area.charges, 0);
      final restored = GameCheckpoint.capture(s)!.restore(GameArt())
        ..start(TestGame());
      addTearDown(restored.dispose);
      final saved = restored.encounterAreas[area.key]!;
      expect(saved.charges, 0);
      expect(saved.rechargeElapsed, area.rechargeElapsed);
      restored.tick(EncounterArea.rechargeSeconds / 2);
      expect(saved.charges, 1);
      expect(saved.rechargeElapsed, 0);
      expect(restored.living, 0, reason: 'recharging does not create a wave');
    },
  );
  test(
    'failed packs do not consume waves and different regions have independent budgets',
    () {
      final first = s.encounterAreas[s.encounterKey]!;
      s.pause();
      s.spawnPack();
      expect(first.waves, 1);
      s.resume();
      s.hero.position.setValues(6800, 4700);
      s.spawnPack();
      expect(s.encounterAreas[s.encounterKey]!.waves, 1);
      expect(first.waves, 1);
    },
  );
  test(
    'save restores surviving enemies with their health and spent quota without a free wave',
    () {
      final mob = s.mobs.first;
      s.hit(mob, 10, Offset.zero);
      final original = s.mobs
          .map((m) => (m.kind, m.life.value, m.life.max))
          .toList();
      final cp = GameCheckpoint.capture(s)!;
      final restored = cp.restore(GameArt());
      addTearDown(restored.dispose);
      restored.start(TestGame());
      expect(
        restored.mobs.map((m) => (m.kind, m.life.value, m.life.max)),
        original,
      );
      expect(restored.encounterAreas.values.single.waves, 1);
      restored.pause();
      restored.tick(50);
      expect(restored.encounterAreas.values.single.waves, 1);
    },
  );
  test('far enemies become dormant and wake without new budget or rewards', () {
    final count = s.living;
    final original = s.hero.position.clone();
    s.hero.position.setValues(original.x + 3000, original.y + 3000);
    s.tick(.05);
    expect(s.dormantEnemies.length, count);
    expect(s.living, 0);
    final area = s.encounterAreas.values.single;
    s.hero.position.setFrom(original);
    s.tick(.05);
    expect(s.dormantEnemies, isEmpty);
    expect(s.living, count);
    expect(area.waves, 1);
    expect(s.progress.kills, 0);
  });
  test(
    'malformed quotas and health are rejected instead of bypassing encounter limits',
    () {
      final cp = GameCheckpoint.capture(s)!;
      cp.data['encounters'][0]['waves'] = 4;
      expect(GameCheckpoint.decode(cp.encode()), null);
    },
  );
}

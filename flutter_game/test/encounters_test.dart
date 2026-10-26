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

  test(
    'three successful waves stop; only reachable stone attacks reset an empty region',
    () {
      final area = s.encounterAreas[s.encounterKey]!;
      expect(area.waves, 1);
      expect(s.strikeEncounterStone(100), false);
      clear();
      s.spawnPack();
      clear();
      s.spawnPack();
      expect(area.waves, EncounterArea.waveLimit);
      expect(
        s.strikeEncounterStone(100),
        false,
        reason: 'living enemies prevent stacking waves',
      );
      clear();
      s.spawnPack();
      expect(s.living, 0);
      final kills = s.progress.kills,
          gold = s.progress.gold,
          energy = s.progress.energy;
      s.pause();
      expect(s.strikeEncounterStone(100), false);
      s.resume();
      s.hero.position.setValues(area.stone.dx + 1000, area.stone.dy);
      expect(s.strikeEncounterStone(100), false);
      s.hero.position.setValues(area.stone.dx - 12, area.stone.dy - 11);
      for (var i = 0; i < 2; i++) {
        expect(s.strikeEncounterStone(100), true);
      }
      expect(area.waves, 3);
      expect(s.strikeEncounterStone(100), true);
      expect(area.waves, 0);
      expect(
        (s.progress.kills, s.progress.gold, s.progress.energy),
        (kills, gold, energy),
      );
      s.spawnPack();
      expect(area.waves, 1);
      expect(s.living, greaterThan(0));
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

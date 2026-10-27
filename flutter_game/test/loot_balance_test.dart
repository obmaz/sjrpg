import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Adventure session() {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    return s;
  }

  test(
    'ordinary equipment keeps its reduced interval while kills give no potions',
    () {
      final s = session();
      final healing = s.progress.healingPotions,
          energy = s.progress.energyPotions;
      for (var kill = 1; kill <= 69; kill++) {
        final enemy = s.spawnEnemy('goblin', const Offset(6100, 4200))!;
        expect(s.hit(enemy, 100000, Offset.zero), true);
        expect(s.loot.length, kill ~/ 29, reason: 'equipment after kill $kill');
        expect(
          s.progress.healingPotions - healing,
          0,
          reason: 'healing after kill $kill',
        );
        expect(
          s.progress.energyPotions - energy,
          0,
          reason: 'resource after kill $kill',
        );
      }
    },
  );

  test('chests have equipment, small rewards and one-time ambush outcomes', () {
    final s = session();
    for (var i = 0; i < s.stageChestLocations.length; i++) {
      expect(s.breakChest(i), true);
    }
    expect(s.openedChests.length, 31);
    expect(s.loot.length, inInclusiveRange(20, 23));
    expect(s.mobs.any((m) => m.kind == 'viper'), true);
    final gold = s.progress.gold,
        count = s.loot.length,
        enemies = s.mobs.length;
    for (var i = 0; i < 31; i++) {
      expect(s.breakChest(i), false);
    }
    expect(s.progress.gold, gold);
    expect(s.loot.length, count);
    expect(s.mobs.length, enemies);
  });
}

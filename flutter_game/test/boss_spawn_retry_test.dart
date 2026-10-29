import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/enemy_difficulty.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

class CountingAdventure extends Adventure {
  CountingAdventure() : super(GameArt());
  int attempts = 0;
  bool allowBoss = false;
  @override
  HuntEnemy? spawnEnemy(
    String kind,
    Offset desired, {
    bool boss = false,
    EnemyTrait trait = EnemyTrait.none,
    EnemyTier? tier,
    EnemyPower? power,
    Offset? home,
  }) {
    if (boss) {
      attempts++;
      if (!allowBoss) return null;
    }
    return super.spawnEnemy(
      kind,
      desired,
      boss: boss,
      trait: trait,
      tier: tier,
      power: power,
      home: home,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'blocked boss spawns retry at most once per simulated second and preserve clearance',
    () {
      final s = inCombatField(CountingAdventure())..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      s.waveTime = 1000;
      s.cleansedSites.addAll(s.world.sites.map((s) => s.id));
      s.progress.kills = 120;
      for (var i = 0; i < 20; i++) {
        s.tick(.05);
      }
      expect(s.attempts, 1);
      expect(s.bossSummoned, false);
      expect(s.stageCleared, false);
      s.pause();
      s.tick(50);
      expect(s.attempts, 1);
      s.resume();
      s.allowBoss = true;
      for (var i = 0; i < 25; i++) {
        s.tick(.05);
      }
      expect(s.bossSummoned, true);
      expect(s.mobs.where((m) => m.boss).length, 1);
      final attempts = s.attempts;
      for (var i = 0; i < 20; i++) {
        s.tick(.05);
      }
      expect(s.attempts, attempts);
      expect(s.world.blocked(s.mobs.single.body), false);
    },
  );
}

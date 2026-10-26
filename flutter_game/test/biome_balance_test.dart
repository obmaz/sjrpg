import 'dart:ui' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/enemy_catalog.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all stages distribute mandatory sites over the map and keep their bodies accessible',
    () {
      for (final stage in WorldStage.values) {
        final world = AdventureWorld(stage: stage);
        var bounds = Rect.fromCircle(center: world.sites.first.at, radius: 1);
        for (final q in world.sites) {
          bounds = bounds.expandToInclude(
            Rect.fromCircle(center: q.at, radius: 1),
          );
        }
        expect(
          bounds.width,
          greaterThan(worldSize.width * .45),
          reason: stage.name,
        );
        expect(
          bounds.height,
          greaterThan(worldSize.height * .45),
          reason: stage.name,
        );
        for (final q in world.sites) {
          expect(
            world.blocked(
              Rect.fromCenter(
                center: q.at + const Offset(0, 80),
                width: 40,
                height: 32,
              ),
            ),
            false,
          );
        }
      }
    },
  );
  test(
    'terrain populations differ and all new enemies have real combat patterns and persistent health',
    () {
      expect(biomeEnemies(WorldStage.forest, wooded: true), contains('boar'));
      expect(biomeEnemies(WorldStage.forest, sand: true), contains('basilisk'));
      expect(
        biomeEnemies(WorldStage.forest, sand: true),
        isNot(contains('goblin')),
      );
      expect(biomeEnemies(WorldStage.past), contains('wraith'));
      expect(biomeEnemies(WorldStage.future), contains('drone'));
      final s = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      for (final (i, kind) in ['boar', 'basilisk', 'wraith', 'drone'].indexed) {
        final m = s.spawnEnemy(kind, Offset(6000 + i * 80, 4200))!;
        expect(m.usesPounce || m.usesSweep || m.usesBolt, true);
        expect(
          m.life.max,
          closeTo(enemyCatalog[kind]!.health * 2 * .8, .000001),
        );
      }
      expect(GameCheckpoint.capture(s)!.data['enemies'].length, 4);
    },
  );
  test(
    'ordinary leveling takes seven kills and earned levels are preserved on load',
    () {
      final p = Progress();
      for (var i = 0; i < 6; i++) {
        p.reward();
      }
      expect(p.level, 1);
      p.reward();
      expect(p.level, 2);
      expect(Progress.fromSave(p.toSave())!.level, 2);
    },
  );
  test('potions drop at the reduced kill intervals, not every short pack', () {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    final health = s.progress.healingPotions, mana = s.progress.energyPotions;
    for (var i = 0; i < 48; i++) {
      final m = s.spawnEnemy('goblin', const Offset(6000, 4200))!;
      s.hit(m, 100000, Offset.zero);
      if (i == 11) expect(s.progress.healingPotions, health);
      if (i == 13) expect(s.progress.energyPotions, mana);
    }
    expect(s.progress.healingPotions, health + 1);
    expect(s.progress.energyPotions, mana + 1);
  });
}

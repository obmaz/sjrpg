import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/encounters.dart';
import 'package:guardian_new/enemy_catalog.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/loot_policy.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session({WorldStage stage = WorldStage.forest}) {
    final s = Adventure(GameArt(), stage: stage)..start(TestGame());
    s.mobs.clear();
    addTearDown(s.dispose);
    return s;
  }

  int ambush(Adventure s) =>
      List.generate(s.stageChestLocations.length, (i) => i).firstWhere(
        (i) =>
            chestContent(s.world.stage, i) == ChestContent.ambush &&
            !s.world.sanctuary.protects(s.world.chestBody(i)),
      );

  void approach(Adventure s, int index) {
    final at = s.world.spawnNear(
      s.stageChestLocations[index] + const Offset(-14, 90),
      const Size(28, 24),
      avoidSanctuary: true,
    )!;
    s.hero.position.setValues(at.dx, at.dy);
  }

  test(
    'a chest ambush appears outside bodies and wards, warns and saves once',
    () {
      final s = session(), index = ambush(s);
      approach(s, index);
      final hp = s.progress.hp, gold = s.progress.gold;
      expect(s.breakChest(index), true);
      expect(s.loot, isEmpty);
      expect(s.progress.gold, gold);
      expect(s.progress.hp, hp, reason: 'opening cannot apply surprise damage');
      expect(s.mobs, hasLength(2));
      for (final enemy in s.mobs) {
        expect(enemy.kind, 'viper');
        expect(s.world.blocksEnemy(enemy.body), false);
        expect(enemy.body.overlaps(s.hero.body), false);
        expect(
          (enemy.body.center - s.hero.body.center).distance,
          greaterThanOrEqualTo(90),
        );
        expect(enemy.attackClock, 1.2);
        expect(
          s.world.clearEnemyLine(
            enemy.body.center,
            s.stageChestLocations[index],
            const Size(3, 3),
          ),
          true,
        );
      }
      expect(s.mobs.first.body.overlaps(s.mobs.last.body), false);
      expect(
        s.areaHasEnemies(EncounterArea.keyAt(s.stageChestLocations[index])),
        true,
      );
      final cp = GameCheckpoint.capture(s)!;
      final restored = GameCheckpoint.decode(cp.encode())!.restore(GameArt())
        ..start(TestGame());
      addTearDown(restored.dispose);
      expect(restored.mobs.where((e) => e.kind == 'viper'), hasLength(2));
      expect(restored.breakChest(index), false);
      expect(restored.progress.gold, gold);
      expect(restored.loot, isEmpty);
      expect(restored.mobs.where((e) => e.kind == 'viper'), hasLength(2));
    },
  );

  test(
    'a full crowd replaces the ambush with a small purse, never more enemies',
    () {
      final s = session(), index = ambush(s);
      approach(s, index);
      for (var i = 0; i < 40; i++) {
        s.mobs.add(HuntEnemy(s, 'goblin', Offset(10000 + i * 30, 10000)));
      }
      expect(s.living, 40);
      expect(s.breakChest(index), true);
      expect(s.living, 40);
      expect(s.progress.gold, 6);
      expect(s.loot, isEmpty);
      expect(s.breakChest(index), false);
      expect(s.progress.gold, 6);
    },
  );

  for (final stage in WorldStage.values) {
    test(
      '${stage.name} ambushes use local enemies with safe whole-body placement',
      () {
        final s = session(stage: stage), index = ambush(s);
        approach(s, index);
        expect(s.breakChest(index), true);
        expect(s.living, inInclusiveRange(0, 2));
        for (final enemy in s.mobs) {
          expect(enemy.kind, stage.usesCityArt ? 'drone' : 'viper');
          expect(s.world.blocksEnemy(enemy.body), false);
          expect(enemy.body.overlaps(s.hero.body), false);
          expect(
            (enemy.body.center - s.hero.body.center).distance,
            greaterThanOrEqualTo(90),
          );
          expect(
            (enemy.body.center - s.stageChestLocations[index]).distance,
            lessThanOrEqualTo(240),
          );
        }
        expect(s.progress.gold, s.mobs.isEmpty ? 6 : 0);
      },
    );
  }

  test(
    'a committed viper bite has one strengthened contact and a recovery',
    () {
      final s = inCombatField(session());
      final enemy = s.spawnEnemy('viper', const Offset(6160, 4200))!
        ..attackClock = 0;
      final hp = s.progress.hp;
      for (var i = 0; i < 26; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, closeTo(hp - s.progress.mitigate(7.2), .001));
      expect(enemy.body.overlaps(s.hero.body), false);
      expect(enemy.pounceRemaining, 0);
      expect(enemy.attackClock, greaterThan(2));
      final after = s.progress.hp;
      for (var i = 0; i < 20; i++) {
        enemy.update(.05);
      }
      expect(s.progress.hp, after);
    },
  );

  test(
    'a protected futuristic chest cannot release enemies across the fence',
    () {
      final s = session(stage: WorldStage.future);
      expect(chestContent(s.world.stage, 0), ChestContent.ambush);
      expect(s.world.sanctuary.protects(s.world.chestBody(0)), true);
      expect(s.breakChest(0), true);
      expect(s.mobs, isEmpty);
      expect(s.loot, isEmpty);
      expect(s.progress.gold, ChestContent.coins.gold);
    },
  );

  test(
    'first forest supplies remain helpful and rare enemies still guarantee gear',
    () {
      final s = session();
      final heals = s.progress.healingPotions;
      expect(s.breakChest(0), true);
      expect(s.progress.healingPotions, heals + 1);
      expect(s.progress.gold, 18);
      expect(s.loot, hasLength(1));
      inCombatField(s);
      for (final elite in [true, false]) {
        final enemy = s.spawnEnemy(
          'goblin',
          const Offset(6100, 4200),
          boss: !elite,
          trait: elite ? EnemyTrait.armored : EnemyTrait.none,
        )!;
        expect(s.hit(enemy, 100000, Offset.zero), true);
      }
      expect(s.loot.where((e) => e.item.rarity == Rarity.rare), hasLength(2));
    },
  );

  test(
    'vipers inhabit wooded and sandy ground with their own readable attack',
    () {
      expect(biomeEnemies(WorldStage.forest, wooded: true), contains('viper'));
      expect(biomeEnemies(WorldStage.sands), contains('viper'));
      expect(biomeEnemies(WorldStage.past, wooded: true), contains('viper'));
      expect(biomeEnemies(WorldStage.future), isNot(contains('viper')));
      final s = inCombatField(session());
      final enemy = s.spawnEnemy('viper', const Offset(6160, 4200))!
        ..attackClock = 0;
      final body = enemy.body;
      enemy.update(.05);
      expect(enemy.windup, closeTo(.55, .001));
      expect(enemy.body, body);
      final locked = enemy.pounceGoal, hp = s.progress.hp;
      s.pause();
      enemy.update(.5);
      expect(enemy.windup, closeTo(.55, .001));
      s.resume();
      s.hero.position.y += 120;
      var lunged = false;
      for (var i = 0; i < 30; i++) {
        enemy.update(.05);
        lunged |= enemy.pounceRemaining > 0;
        if (lunged && enemy.pounceRemaining == 0) break;
      }
      expect(lunged, true);
      expect(s.progress.hp, hp);
      expect((enemy.body.center.dy - locked!.dy).abs(), lessThan(2));
      expect(s.world.blocksEnemy(enemy.body), false);
    },
  );
}

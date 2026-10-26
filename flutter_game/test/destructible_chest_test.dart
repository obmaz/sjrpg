import 'dart:math' as math;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/destructible_chest.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session({
    WorldStage stage = WorldStage.forest,
    HeroClass heroClass = HeroClass.warrior,
  }) {
    final s = Adventure(GameArt(), stage: stage, heroClass: heroClass)
      ..start(TestGame());
    addTearDown(s.dispose);
    return s;
  }

  for (final stage in WorldStage.values) {
    test('$stage closed chest blocks a complete body until broken', () {
      final s = session(stage: stage);
      final index = stage == WorldStage.forest ? 4 : 0;
      final body = s.world.chestBody(index);
      final from = Offset(body.center.dx - 100, body.center.dy - 12);
      const size = Size(28, 24);
      expect(s.world.blocked(body), true);
      final stopped = s.world.move(from, const Offset(200, 0), size);
      expect((stopped & size).overlaps(body), false);
      expect(stopped.dx, lessThan(body.left));
      expect(s.world.clearLine(from, from + const Offset(200, 0), size), false);
      expect(s.breakChest(index), true);
      expect(s.world.blocked(body), false);
      expect(s.world.clearLine(from, from + const Offset(200, 0), size), true);
      final passed = s.world.move(from, const Offset(200, 0), size);
      expect((passed - from - const Offset(200, 0)).distance, lessThan(.001));
    });
  }

  for (final heroClass in HeroClass.values) {
    test(
      '$heroClass basic strike breaks a protected chest without enemy combat',
      () {
        final s = session(stage: WorldStage.sands, heroClass: heroClass);
        final game = s.game! as TestGame, chest = s.stageChestLocations.first;
        s.hero.position.setValues(chest.dx - 14, chest.dy + 65);
        expect(s.sheltered, true);
        final hp = s.progress.hp, energy = s.progress.energy;
        final gold = s.progress.gold;
        s.hero.slash();
        if (heroClass == HeroClass.mage) {
          final bolt = game.added.whereType<ArcaneBolt>().single;
          expect(bolt.propOnly, true);
          for (var i = 0; i < 30; i++) {
            bolt.update(1 / 30);
          }
        }
        expect(s.openedChests, contains(0));
        expect(s.progress.gold, gold + 18);
        expect(s.progress.energy, energy);
        expect(s.progress.hp, hp);
        expect(s.hero.cooldowns, isEmpty);
        expect(s.progress.kills, 0);
        expect(game.added.whereType<ChestFragments>(), hasLength(1));
        expect(s.breakChest(0), false);
        expect(s.progress.gold, gold + 18);
      },
    );
  }

  test(
    'a chest consumes one basic melee target and receives no extra reward',
    () {
      final s = session();
      final chest = s.stageChestLocations[4];
      s.hero.position.setValues(chest.dx - 14, chest.dy + 85);
      final mob = s.spawnEnemy('goblin', chest + const Offset(-12, 45))!;
      final hp = mob.life.value;
      s.hero.slash();
      expect(mob.life.value, lessThan(hp));
      expect(s.openedChests, isNot(contains(4)));
      expect(s.progress.basicTargetLimit, 1);
      expect(s.progress.kills, 0);
    },
  );

  test('a fire bolt hits a chest before an enemy behind it', () {
    final s = session(heroClass: HeroClass.mage);
    final chest = s.stageChestLocations[4];
    s.hero.position.setValues(chest.dx - 14, chest.dy + 100);
    final mob = s.spawnEnemy('goblin', chest - const Offset(12, 90))!;
    final hp = mob.life.value;
    final bolt = ArcaneBolt(s, s.hero.body.center, -math.pi / 2, 50);
    for (var i = 0; i < 30; i++) {
      bolt.update(1 / 30);
    }
    expect(s.openedChests, contains(4));
    expect(bolt.resolved, true);
    expect(mob.life.value, hp);
  });

  test(
    'a wall before a chest stops a bolt without breaking or rewarding it',
    () {
      final s = session(heroClass: HeroClass.mage);
      ({int index, Offset from})? blockedChest;
      for (var index = 0; index < s.stageChestLocations.length; index++) {
        final chest = s.stageChestLocations[index];
        for (var direction = 0; direction < 16; direction++) {
          final angle = direction * math.pi / 8;
          final from = chest + Offset(math.cos(angle), math.sin(angle)) * 400;
          if (s.world.blocked(
                Rect.fromCenter(center: from, width: 28, height: 24),
              ) ||
              s.world.firstChestOnSegment(from, chest)?.index != index ||
              s.world.clearLine(
                from,
                s.world.chestApproach(index, from),
                const Size(3, 3),
              )) {
            continue;
          }
          blockedChest = (index: index, from: from);
          break;
        }
        if (blockedChest != null) break;
      }
      expect(
        blockedChest,
        isNotNull,
        reason: 'a real map wall separates this chest and caster',
      );
      final target = blockedChest!;
      final direction = s.stageChestLocations[target.index] - target.from;
      s.hero.position.setValues(target.from.dx - 14, target.from.dy - 12);
      final gold = s.progress.gold;
      final bolt = ArcaneBolt(
        s,
        target.from,
        math.atan2(direction.dy, direction.dx),
        50,
        propOnly: true,
      );
      for (var i = 0; i < 30; i++) {
        bolt.update(1 / 30);
      }
      expect(bolt.resolved, true);
      expect(s.openedChests, isNot(contains(target.index)));
      expect(s.progress.gold, gold);
    },
  );

  test('saved chest remains are passable before restoring hero position', () {
    final s = session(stage: WorldStage.sands);
    expect(s.breakChest(0), true);
    final body = s.world.chestBody(0);
    s.hero.position.setValues(body.left, body.top);
    final restored = GameCheckpoint.capture(s)!.restore(GameArt());
    addTearDown(restored.dispose);
    expect(restored.openedChests, {0});
    expect(restored.hero.position.toOffset(), s.hero.position.toOffset());
    expect(restored.world.blocked(restored.hero.body), false);
  });

  test('paused and defeated sessions cannot break or reward a chest', () {
    final s = session();
    final gold = s.progress.gold;
    s.pause();
    expect(s.breakChest(0), false);
    s.resume();
    s.defeated = true;
    expect(s.breakChest(0), false);
    expect(s.openedChests, isEmpty);
    expect(s.progress.gold, gold);
  });
}

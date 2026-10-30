import 'dart:math' as math;

import 'stage_content.dart';

// Equipment keeps cumulative kill milestones. Potions only come from chests
// or a purchase; kills and shrine rewards never mint them.
const ordinaryGearInterval = 29;

enum ChestContent {
  gear(18),
  supplies(8),
  coins(10),
  ambush(0);

  const ChestContent(this.gold);
  final int gold;
}

/// A saved campaign seed gives each stage a shuffled ten-chest bag. Categories
/// retain their overall budget while neither reloads nor opening order reroll it.
/// Omitting the seed preserves the legacy policy for source-format consumers.
ChestContent chestContent(WorldStage stage, int index, {int? seed}) {
  if (seed == null) {
    return switch ((index * 7 + stage.index * 3) % 10) {
      7 => ChestContent.supplies,
      8 => ChestContent.coins,
      9 => ChestContent.ambush,
      _ => ChestContent.gear,
    };
  }
  final bag = [
    for (var i = 0; i < 7; i++) ChestContent.gear,
    ChestContent.supplies,
    ChestContent.coins,
    ChestContent.ambush,
  ]..shuffle(_chestRandom(seed, stage, index ~/ 10, 0x193af));
  return bag[index % 10];
}

/// Equipment affixes and bases have a separate per-chest stream, so combat RNG
/// and the sequence of opening other chests cannot move this chest's reward.
math.Random chestRewardRandom(int seed, WorldStage stage, int index) =>
    _chestRandom(seed, stage, index, 0x29f84b);

math.Random _chestRandom(int seed, WorldStage stage, int index, int salt) =>
    math.Random(
      (seed ^
              ((stage.index + 1) * 0x45d9f3b) ^
              ((index + 1) * 0x119de1f3) ^
              salt) &
          0x7fffffff,
    );

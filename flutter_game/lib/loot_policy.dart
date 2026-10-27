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

/// Content categories are stable across reloads and do not advance the loot RNG.
/// Seven equipment rolls, one supply cache, one purse and one ambush per cycle.
ChestContent chestContent(WorldStage stage, int index) =>
    switch ((index * 7 + stage.index * 3) % 10) {
      7 => ChestContent.supplies,
      8 => ChestContent.coins,
      9 => ChestContent.ambush,
      _ => ChestContent.gear,
    };

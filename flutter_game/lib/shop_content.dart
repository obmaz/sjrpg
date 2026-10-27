import 'rpg_model.dart';
import 'stage_content.dart';

class ShopGearOffer {
  ShopGearOffer(this.base, WorldStage stage)
    : tier = switch (stage) {
        WorldStage.forest => 0,
        WorldStage.sands => 1,
        WorldStage.past || WorldStage.future => 2,
        WorldStage.tombs || WorldStage.foundry => 3,
        WorldStage.convergence => 4,
      };
  final GearDef base;
  final int tier;
  int get price => base.value * (1 + tier * 2);
  Rarity get rarity => tier == 0 ? Rarity.common : Rarity.magic;
  int get power => base.slot == GearSlot.weapon ? tier * 3 : 0;
  int get vitality => switch (base.slot) {
    GearSlot.armor => tier * 10,
    GearSlot.charm => tier * 5,
    GearSlot.weapon => 0,
  };
  int get focus => base.slot == GearSlot.charm ? tier * 4 : 0;
  Gear get preview => Gear(
    0,
    base,
    rarity: rarity,
    power: power,
    vitality: vitality,
    focus: focus,
  );
  Gear create(Progress progress) => progress.createGear(
    base,
    rarity: rarity,
    power: power,
    vitality: vitality,
    focus: focus,
  );
  bool matches(Gear item) =>
      item.base.id == base.id &&
      item.rarity == rarity &&
      item.power == power &&
      item.vitality == vitality &&
      item.focus == focus &&
      item.gift == null;
}

import 'rpg_model.dart';
import 'stage_content.dart';

class ShopGearOffer {
  ShopGearOffer(this.base, WorldStage stage, {this.acquiredLevel = 1})
    : tier = switch (stage) {
        WorldStage.forest => 0,
        WorldStage.sands => 1,
        WorldStage.past || WorldStage.future => 2,
        WorldStage.tombs || WorldStage.foundry => 3,
        WorldStage.convergence => 4,
      };
  final GearDef base;
  final int tier;
  final int acquiredLevel;
  int get price => base.value * (1 + tier * 2);
  Rarity get rarity => tier == 0 ? Rarity.common : Rarity.magic;
  int get _power => base.slot == GearSlot.weapon ? tier * 3 : 0;
  int get _vitality => switch (base.slot) {
    GearSlot.armor => tier * 10,
    GearSlot.charm => tier * 5,
    GearSlot.weapon => 0,
  };
  int get _focus => base.slot == GearSlot.charm ? tier * 4 : 0;
  int get power => gearAffixForLevel(_power, acquiredLevel);
  int get vitality => gearAffixForLevel(_vitality, acquiredLevel);
  int get focus => gearAffixForLevel(_focus, acquiredLevel);
  Gear get preview => Gear(
    0,
    base,
    rarity: rarity,
    power: power,
    vitality: vitality,
    focus: focus,
    acquiredLevel: acquiredLevel,
  );
  Gear create(Progress progress) => progress.createGear(
    base,
    rarity: rarity,
    power: _power,
    vitality: _vitality,
    focus: _focus,
    acquiredLevel: acquiredLevel,
  );
  bool matches(Gear item) =>
      item.base.id == base.id &&
      item.rarity == rarity &&
      item.power == power &&
      item.vitality == vitality &&
      item.focus == focus &&
      item.gifts.isEmpty;
}

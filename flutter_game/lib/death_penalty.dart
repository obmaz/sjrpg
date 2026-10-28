import 'dart:math' as math;

import 'rpg_model.dart';

/// Resolved once when the hero dies, before a revival checkpoint is written.
class DeathLoss {
  const DeathLoss({
    required this.goldLost,
    required this.goldPercent,
    this.weaponName,
    this.weaponSerial,
  });
  final int goldLost, goldPercent;
  final String? weaponName;
  final int? weaponSerial;

  static DeathLoss apply(Progress progress, math.Random random) {
    final weapons = progress.inventory
        .where((gear) => gear.base.slot == GearSlot.weapon)
        .toList();
    final weapon = weapons.isEmpty
        ? null
        : weapons[random.nextInt(weapons.length)];
    final percent = random.nextInt(31);
    final goldLost = progress.gold * percent ~/ 100;
    progress.gold -= goldLost;
    if (weapon != null) {
      progress.inventory.removeWhere((item) => item.serial == weapon.serial);
      progress.unseenGear.remove(weapon.serial);
      if (progress.equipped[GearSlot.weapon]?.serial == weapon.serial) {
        progress.equipped.remove(GearSlot.weapon);
      }
      // Losing vitality or focus on a weapon never creates life or mana.
      progress.hp = math.min(progress.hp, progress.maxHp);
      progress.energy = math.min(progress.energy, progress.maxEnergy);
    }
    return DeathLoss(
      goldLost: goldLost,
      goldPercent: percent,
      weaponName: weapon?.name,
      weaponSerial: weapon?.serial,
    );
  }
}

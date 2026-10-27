/// Shared pacing values used by simulation, offers and their previews.
abstract final class CombatBalance {
  // Combine damage and rate: default sustained basic DPS becomes ~69.7%.
  static const heroDamageScale = .85;
  static const basicAttackRate = .82;
  static const basicRankTempoGrowth = .05;
  static const minimumBasicInterval = .16 / basicAttackRate;
  static const minimumStrikeInterval = .12 / basicAttackRate;
  static const physicalMasteryGrowth = .06;
  static const arcaneMasteryGrowth = .07;
  static const resourceGainScale = .7;
  static const rageOnDamage = 7 * resourceGainScale;
  static const levelRageGain = 10.0;
  static const levelManaFraction = .35;
  static const enemyDamageScale = 1.2;
  static const maxActiveEnemies = 28;
  static const potionBundleSize = 2;
  static const healingPotionPrice = 80;
  static const resourcePotionPrice = 72;
  static const potionHealing = 55.0;
  static const potionEnergy = 60.0;

  static double basicTempo(int rank) =>
      basicAttackRate * (1 + (rank.clamp(1, 5) - 1) * basicRankTempoGrowth);

  static int experienceForLevel(int level) =>
      ((55 + (level - 1) * 30) * 1.5).ceil();

  static int packSize({
    required bool initial,
    required int playerLevel,
    required int living,
  }) => initial
      ? 4
      : playerLevel < 3
      ? 6
      : living < 8
      ? 8
      : 7;
}

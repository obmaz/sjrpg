/// Shared pacing values used by simulation, offers and their previews.
abstract final class CombatBalance {
  // Apply the outgoing skill reduction once, after weapon/rank calculations.
  static const heroDamageScale = .85;
  static const skillDamageScale = .60;
  static const basicAttackRate = .30;
  static const basicRankTempoGrowth = .015;
  static const minimumBasicInterval = .16 / basicAttackRate;
  static const minimumStrikeInterval = .12 / basicAttackRate;
  static const physicalMasteryGrowth = .02;
  static const arcaneMasteryGrowth = .025;
  static const maximumMasteryMultiplier = 1.15;
  static const maximumSkillDamageMultiplier = 1.25;
  static const maximumAttackHaste = .15;
  static const normalMoveSpeed = 135.0;
  static const sprintMoveSpeed = 270.0;
  static const resourceGainScale = .7;
  static const rageOnDamage = 7 * resourceGainScale;
  static const levelRageGain = 10.0;
  static const levelManaFraction = .35;
  static const enemyDamageScale = 1.2;
  static const maxActiveEnemies = 30;
  static const enemyPopulationScale = 1.5;
  static const enemyExperienceScale = .60;
  static const revivalProtection = 3.0;
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
  }) {
    final baseSize = initial
        ? 3
        : playerLevel < 3
        ? 4
        : living < 9
        ? 5
        : 4;
    return (baseSize * enemyPopulationScale).round();
  }
}

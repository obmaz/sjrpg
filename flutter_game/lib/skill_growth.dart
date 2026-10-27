/// Shared rank scaling for simulation, previews and the HUD.
class SkillGrowth {
  static int level(int rank) => rank.clamp(1, 5);
  static double tempo(int rank) => .75 * (1 + (level(rank) - 1) * .035);
  static double cooldown(int rank) => 1 - (level(rank) - 1) * .02;
  static int tier(int rank) => rank >= 5
      ? 2
      : rank >= 3
      ? 1
      : 0;
  static int particles(int rank) => 8 + level(rank) * 4;
  static int layers(int rank) => 1 + (rank >= 2 ? 1 : 0) + (rank >= 4 ? 1 : 0);
}

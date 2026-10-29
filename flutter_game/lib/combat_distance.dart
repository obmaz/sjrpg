/// Player-facing world distance. One step is a hero-sized 40 world units;
/// zoom and device pixel density never change the displayed reach.
abstract final class CombatDistance {
  static const unitsPerStep = 40.0;
  static double steps(double worldUnits) => worldUnits / unitsPerStep;
  static String format(double worldUnits) =>
      '${steps(worldUnits).toStringAsFixed(1)}걸음';
  static const help = '1걸음 ≈ 캐릭터 한 명 너비';
}

import 'dart:math' as math;
import 'dart:ui';

/// One height-scaled fan, keeping the primary, four skills and dodge together.
/// Coordinates are offsets from the right/bottom viewport edges, not sprites.
class BattleControlLayout {
  BattleControlLayout(Size viewport, {double safeBottom = 0})
    : height = viewport.height,
      scale = (viewport.height / 720).clamp(
        viewport.height < 300 ? .5 : .6,
        1.1,
      ),
      inset = math.max(8, safeBottom);
  final double height, scale, inset;
  double get attackSize => 168 * scale;
  double get smallSize => math.max(44, 64 * scale);
  double get attackRight => 8 * scale + smallSize + 8 * scale;
  double get bottom =>
      math.max(inset + 8, 82 * scale - math.max(0, 350 - height) * .55);
  double get dodgeRight => 8 * scale;
  double get dodgeRise => (attackSize - smallSize) / 2;
  double get mobilityRise => dodgeRise - smallSize - 8 * scale;
  double get stickSize => 202 * scale;
  double get stickLeft => 70 * scale;
  double get stickBottom => math.max(inset + 8, 50 * scale);

  /// Four equal touch targets form a fan around the primary attack center.
  static List<(double, double, double)> fan({
    required double attackRight,
    required double attackSize,
    required double skillSize,
    required double gap,
  }) {
    // Place square touch areas against the primary's left and upper edges.
    // This keeps the illustrated circles close without overlapping hit boxes.
    final spacing = math.min(gap, 5.0);
    return [
      (
        attackRight + attackSize + spacing,
        (attackSize - skillSize) / 2,
        skillSize,
      ),
      (attackRight + attackSize + spacing, attackSize + spacing, skillSize),
      (
        attackRight + (attackSize - skillSize) / 2,
        attackSize + spacing,
        skillSize,
      ),
      (attackRight - skillSize - spacing, attackSize + spacing, skillSize),
    ];
  }

  List<(double, double, double)> get skills => fan(
    attackRight: attackRight,
    attackSize: attackSize,
    skillSize: smallSize,
    gap: 5 * scale,
  );
}

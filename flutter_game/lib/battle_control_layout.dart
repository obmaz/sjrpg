import 'dart:math' as math;
import 'dart:ui';

/// Fixed portrait-size buttons with anchors adapted to viewport height.
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
  double get attackSize => 76;
  double get smallSize => 48;
  double get dodgeSize => 44;
  double get mobilitySize => 48;
  double get attackRight => 60;
  double get bottom =>
      math.max(inset + 36, 82 * scale - math.max(0, 350 - height) * .55);
  double get dodgeRight => 8;
  double get dodgeRise => 20;
  double get mobilityRise => -36;
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
    final radius = math.max(
      (attackSize + skillSize) / 2 + math.max(6, gap),
      (skillSize + math.max(6, gap)) / (2 * math.sin(math.pi / 8)),
    );
    return [
      for (final angle in [math.pi, 3 * math.pi / 4, math.pi / 2, math.pi / 4])
        (
          attackRight +
              attackSize / 2 -
              math.cos(angle) * radius -
              skillSize / 2,
          attackSize / 2 + math.sin(angle) * radius - skillSize / 2,
          skillSize,
        ),
    ];
  }

  List<(double, double, double)> get skills => fan(
    attackRight: attackRight,
    attackSize: attackSize,
    skillSize: smallSize,
    gap: 5 * scale,
  );
}

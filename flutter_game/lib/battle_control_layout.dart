import 'dart:math' as math;
import 'dart:ui';

/// One height-scaled fan, keeping the primary, four skills and dodge together.
/// Coordinates are offsets from the right/bottom viewport edges, not sprites.
class BattleControlLayout {
  BattleControlLayout(Size viewport, {double safeBottom = 0})
    : scale = (viewport.height / 720).clamp(.6, 1.1),
      inset = math.max(8, safeBottom);
  final double scale, inset;
  double get attackSize => 168 * scale;
  double get smallSize => math.max(44, 64 * scale);
  double get attackRight => 8 * scale + smallSize + 8 * scale;
  double get bottom => math.max(inset + 8, 82 * scale);
  double get dodgeRight => 8 * scale;
  double get dodgeRise => (attackSize - smallSize) / 2;
  double get mobilityRise => dodgeRise - smallSize - 12 * scale;
  double get stickSize => 202 * scale;
  double get stickLeft => 70 * scale;
  double get stickBottom => math.max(inset + 8, 50 * scale);
  List<(double, double, double)> get skills => [
    for (final p in const [
      (-132.0, -18.0, 64.0),
      (-132.0, -112.0, 68.0),
      (-30.0, -134.0, 72.0),
      (72.0, -130.0, 66.0),
    ])
      (
        attackRight +
            attackSize / 2 -
            p.$1 * scale -
            math.max(44, p.$3 * scale) / 2,
        attackSize / 2 - p.$2 * scale - math.max(44, p.$3 * scale) / 2,
        math.max(44, p.$3 * scale),
      ),
  ];
}

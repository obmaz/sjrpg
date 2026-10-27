import 'dart:math' as math;
import 'dart:ui';

const crushingBlowRange = 185.0, crushingBlowHalfAngle = 1.05;

class SkillAim {
  SkillAim(this.slot, this.id, this.initialBearing);
  final int slot;
  final String id;
  final double initialBearing;
  Offset delta = Offset.zero;
  double heldFor = 0;
  bool get dragged => delta.distance >= 10;
  bool get cancelled => delta.distance > 156;
  double get angle => dragged ? math.atan2(delta.dy, delta.dx) : initialBearing;
  double get distance =>
      dragged ? (delta.distance / 74 * 450).clamp(64, 450) : 190;

  double distanceWithin(
    Size? viewport, {
    double cameraOffsetY = 0,
    Offset? screenOrigin,
  }) {
    if (viewport == null) return distance;
    final origin =
        screenOrigin ??
        Offset(viewport.width / 2, viewport.height / 2 - cameraOffsetY);
    final direction = Offset(math.cos(angle), math.sin(angle));
    final bounds = Rect.fromLTRB(
      24,
      math.min(144, viewport.height * .25),
      viewport.width - 24,
      viewport.height - 80,
    );
    var limit = distance;
    if (direction.dx.abs() > .001) {
      limit = math.min(
        limit,
        ((direction.dx > 0 ? bounds.right : bounds.left) - origin.dx) /
            direction.dx,
      );
    }
    if (direction.dy.abs() > .001) {
      limit = math.min(
        limit,
        ((direction.dy > 0 ? bounds.bottom : bounds.top) - origin.dy) /
            direction.dy,
      );
    }
    return math.max(0, limit);
  }
}

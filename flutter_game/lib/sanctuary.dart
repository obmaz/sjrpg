import 'dart:math' as math;
import 'dart:ui';

class Sanctuary {
  const Sanctuary(this.center, this.radius);
  final Offset center;
  final double radius;

  bool protects(Rect body) {
    final dx = center.dx - center.dx.clamp(body.left, body.right),
        dy = center.dy - center.dy.clamp(body.top, body.bottom);
    return dx * dx + dy * dy <= radius * radius;
  }

  bool blocksRay(Offset from, Offset to, {double padding = 0}) {
    final reach = radius + padding;
    if (math.max(from.dx, to.dx) < center.dx - reach ||
        math.min(from.dx, to.dx) > center.dx + reach ||
        math.max(from.dy, to.dy) < center.dy - reach ||
        math.min(from.dy, to.dy) > center.dy + reach) {
      return false;
    }
    final vx = to.dx - from.dx,
        vy = to.dy - from.dy,
        length = vx * vx + vy * vy;
    final fraction = length == 0
        ? 0.0
        : (((center.dx - from.dx) * vx + (center.dy - from.dy) * vy) / length)
              .clamp(0.0, 1.0);
    final dx = from.dx + vx * fraction - center.dx,
        dy = from.dy + vy * fraction - center.dy;
    return dx * dx + dy * dy <= reach * reach;
  }

  Offset outside(Offset topLeft, Size size) {
    final body = topLeft & size;
    if (!protects(body)) return topLeft;
    final offset = body.center - center;
    final direction = offset.distanceSquared == 0
        ? const Offset(1, 0)
        : offset / offset.distance;
    final clearance =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    return center +
        direction * (radius + clearance + 12) -
        Offset(size.width / 2, size.height / 2);
  }
}

class SanctuaryFenceSection {
  const SanctuaryFenceSection(this.start, this.end);
  final Offset start, end;
  Rect get bounds => Rect.fromPoints(start, end).inflate(28);
  Iterable<Rect> get collisionBodies sync* {
    final steps = math.max(1, ((end - start).distance / 9).ceil());
    for (var i = 0; i <= steps; i++) {
      yield Rect.fromCenter(
        center: Offset.lerp(start, end, i / steps)!,
        width: 12,
        height: 10,
      );
    }
  }
}

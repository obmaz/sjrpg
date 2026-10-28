import 'dart:math' as math;
import 'dart:ui';

class Sanctuary {
  const Sanctuary(this.center, this.radius);
  factory Sanctuary.polygon(List<Offset> points) {
    if (points.length < 3 ||
        points.any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
      throw ArgumentError('A sanctuary needs at least three finite vertices');
    }
    return _PolygonSanctuary(List<Offset>.unmodifiable(points));
  }
  Path get boundaryPath =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));
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

// The radius remains a broad-phase bound; gameplay uses the painted outline.
class _PolygonSanctuary extends Sanctuary {
  _PolygonSanctuary(List<Offset> points) : this._(points, _bounds(points));
  _PolygonSanctuary._(this.points, this.bounds)
    : super(
        bounds.center,
        points.map((p) => (p - bounds.center).distance).reduce(math.max),
      ) {
    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
        _path.moveTo(points[i].dx, points[i].dy);
      } else {
        _path.lineTo(points[i].dx, points[i].dy);
      }
    }
    _path.close();
  }
  final List<Offset> points;
  final Rect bounds;
  final Path _path = Path();
  @override
  Path get boundaryPath => _path;

  static Rect _bounds(List<Offset> p) => Rect.fromLTRB(
    p.map((p) => p.dx).reduce(math.min),
    p.map((p) => p.dy).reduce(math.min),
    p.map((p) => p.dx).reduce(math.max),
    p.map((p) => p.dy).reduce(math.max),
  );
  static double _pointDistance(Offset p, Offset a, Offset b) {
    final d = b - a;
    final t = d.distanceSquared == 0
        ? 0.0
        : (((p.dx - a.dx) * d.dx + (p.dy - a.dy) * d.dy) / d.distanceSquared)
              .clamp(0.0, 1.0);
    return (p - (a + d * t)).distanceSquared;
  }

  static double _cross(Offset a, Offset b, Offset p) =>
      (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
  static bool _touches(Offset a, Offset b, Offset p) =>
      _cross(a, b, p).abs() <= 1e-8 &&
      p.dx >= math.min(a.dx, b.dx) - 1e-9 &&
      p.dx <= math.max(a.dx, b.dx) + 1e-9 &&
      p.dy >= math.min(a.dy, b.dy) - 1e-9 &&
      p.dy <= math.max(a.dy, b.dy) + 1e-9;
  static bool _intersects(Offset a, Offset b, Offset c, Offset d) {
    final x = _cross(a, b, c),
        y = _cross(a, b, d),
        u = _cross(c, d, a),
        v = _cross(c, d, b);
    return (x * y < 0 && u * v < 0) ||
        _touches(a, b, c) ||
        _touches(a, b, d) ||
        _touches(c, d, a) ||
        _touches(c, d, b);
  }

  bool _contains(Offset p) {
    var inside = false;
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length];
      if (_touches(a, b, p)) return true;
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool _overlaps(Rect a, Rect b) =>
      a.left <= b.right &&
      a.right >= b.left &&
      a.top <= b.bottom &&
      a.bottom >= b.top;
  @override
  bool protects(Rect body) {
    if (!_overlaps(bounds, body)) return false;
    if (_contains(body.center)) return true;
    final corners = [
      body.topLeft,
      body.topRight,
      body.bottomRight,
      body.bottomLeft,
    ];
    if (corners.any(_contains)) return true;
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length];
      if (a.dx >= body.left &&
          a.dx <= body.right &&
          a.dy >= body.top &&
          a.dy <= body.bottom) {
        return true;
      }
      for (var j = 0; j < 4; j++) {
        if (_intersects(a, b, corners[j], corners[(j + 1) % 4])) return true;
      }
    }
    return false;
  }

  @override
  bool blocksRay(Offset from, Offset to, {double padding = 0}) {
    final sweep = Rect.fromPoints(from, to).inflate(padding);
    if (!_overlaps(bounds, sweep)) return false;
    if (_contains(from) || _contains(to)) return true;
    final squared = padding * padding;
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length];
      if (_intersects(from, to, a, b)) return true;
      if (padding > 0 &&
          math.min(
                math.min(
                  _pointDistance(a, from, to),
                  _pointDistance(b, from, to),
                ),
                math.min(_pointDistance(from, a, b), _pointDistance(to, a, b)),
              ) <=
              squared) {
        return true;
      }
    }
    return false;
  }

  @override
  Offset outside(Offset topLeft, Size size) {
    if (!protects(topLeft & size)) return topLeft;
    final center = (topLeft & size).center;
    var closest = points.first,
        normal = const Offset(0, -1),
        best = double.infinity;
    final area = List.generate(points.length, (i) {
      final a = points[i], b = points[(i + 1) % points.length];
      return a.dx * b.dy - b.dx * a.dy;
    }).fold(0.0, (a, b) => a + b);
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length], d = b - a;
      if (d.distanceSquared == 0) continue;
      final t =
          (((center.dx - a.dx) * d.dx + (center.dy - a.dy) * d.dy) /
                  d.distanceSquared)
              .clamp(0.0, 1.0);
      final at = a + d * t, distance = (center - at).distanceSquared;
      if (distance < best) {
        best = distance;
        closest = at;
        normal = Offset(d.dy, -d.dx) / d.distance * (area >= 0 ? 1 : -1);
      }
    }
    final half = Offset(size.width / 2, size.height / 2);
    var distance = normal.dx.abs() * half.dx + normal.dy.abs() * half.dy + 12;
    var candidate = closest + normal * distance - half;
    for (var i = 0; i < 32 && protects(candidate & size); i++) {
      distance += math.max(size.width, size.height) / 2 + 1;
      candidate = closest + normal * distance - half;
    }
    return protects(candidate & size)
        ? super.outside(topLeft, size)
        : candidate;
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

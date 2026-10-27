import 'dart:math' as math;
import 'dart:ui';

/// A local, immediately updated index for crowd steering between engine steps.
/// Bonfire's hitboxes still resolve physical contacts after component updates.
class EnemySpacing<T extends Object> {
  static const cellSize = 96.0;
  final _cells = <(int, int), Set<T>>{};
  final _bodies = <T, Rect>{};
  final _slots = <T, (int, int)>{};
  final _spaces = <T, Size>{};
  final _order = <T, int>{};
  int _nextOrder = 0;

  void clear() {
    _cells.clear();
    _bodies.clear();
    _slots.clear();
    _spaces.clear();
    _order.clear();
    _nextOrder = 0;
  }

  void update(T item, Rect body, {Size? personalSpace}) {
    _spaces[item] = personalSpace ?? body.size;
    _order.putIfAbsent(item, () => _nextOrder++);
    final center = body.center;
    final slot = (
      (center.dx / cellSize).floor(),
      (center.dy / cellSize).floor(),
    );
    final previous = _slots[item];
    if (previous != slot) {
      if (previous != null) {
        final bucket = _cells[previous]!;
        bucket.remove(item);
        if (bucket.isEmpty) _cells.remove(previous);
      }
      (_cells[slot] ??= <T>{}).add(item);
      _slots[item] = slot;
    }
    _bodies[item] = body;
  }

  void remove(T item) {
    final slot = _slots.remove(item);
    if (slot != null) {
      final bucket = _cells[slot]!;
      bucket.remove(item);
      if (bucket.isEmpty) _cells.remove(slot);
    }
    _bodies.remove(item);
    _spaces.remove(item);
    _order.remove(item);
  }

  bool contains(T item) => _bodies.containsKey(item);
  Rect bodyOf(T item) => _bodies[item]!;
  double preferredSide(T item) => _order[item]!.isEven ? 1 : -1;

  double _proximity(T item, Rect body, T other) {
    final difference = body.center - bodyOf(other).center;
    final a = _spaces[item]!, b = _spaces[other]!;
    final x = difference.dx / ((a.width + b.width) / 2);
    final y = difference.dy / ((a.height + b.height) / 2);
    return math.sqrt(x * x + y * y);
  }

  bool permitsPersonalSpace(T item, Rect from, Rect to, T other) {
    final after = _proximity(item, to, other);
    return after >= 1 || after >= _proximity(item, from, other) - .000001;
  }

  /// Soft illustration spacing never enlarges the physical terrain hitbox.
  Offset separation(T item, Rect body, Iterable<T> neighbors, double step) {
    var force = Offset.zero, pressure = 0.0;
    for (final other in neighbors) {
      final proximity = _proximity(item, body, other);
      if (proximity >= .97) continue;
      pressure = math.max(pressure, 1 - proximity);
      var away = body.center - bodyOf(other).center;
      if (away.distanceSquared < .001) {
        final a = _order[item]!, b = _order[other]!;
        final angle =
            ((math.min(a, b) * 31 + math.max(a, b) * 17) % 8) * math.pi / 4;
        away = Offset(math.cos(angle), math.sin(angle)) * (a < b ? -1 : 1);
      }
      force += away / away.distance * (1 - proximity);
    }
    if (pressure == 0) return Offset.zero;
    if (force.distanceSquared < .000001) {
      force = Offset(0, preferredSide(item));
    }
    return force / force.distance * step * math.min(1, pressure * 2.5);
  }

  Iterable<T> query(Rect bounds) sync* {
    for (
      var y = (bounds.top / cellSize).floor();
      y <= (bounds.bottom / cellSize).floor();
      y++
    ) {
      for (
        var x = (bounds.left / cellSize).floor();
        x <= (bounds.right / cellSize).floor();
        x++
      ) {
        final bucket = _cells[(x, y)];
        if (bucket == null) continue;
        for (final item in bucket) {
          if (bounds.contains(_bodies[item]!.center)) yield item;
        }
      }
    }
  }

  /// Gentle foot spacing; artwork width must not make narrow paths impassable.
  Offset steer(T item, Rect body, Offset delta, Iterable<T> neighbors) {
    final distance = delta.distance;
    if (distance < .001) return delta;
    final forward = delta / distance;
    final side = Offset(-forward.dy, forward.dx);
    var adjustment = Offset.zero;
    for (final other in neighbors) {
      final next = bodyOf(other);
      final difference = body.center - next.center;
      final a = _spaces[item]!, b = _spaces[other]!;
      final reachX = (a.width + b.width) / 2,
          reachY = (a.height + b.height) / 2;
      final dx = difference.dx / reachX, dy = difference.dy / reachY;
      final proximity = math.sqrt(dx * dx + dy * dy);
      if (proximity >= 1) continue;
      final weight = 1 - proximity;
      if (difference.distanceSquared > .001) {
        adjustment += difference / difference.distance * (distance * weight);
      }
      final ahead = -difference.dx * forward.dx - difference.dy * forward.dy;
      final lateral = difference.dx * side.dx + difference.dy * side.dy;
      if (ahead > 0 && lateral.abs() < 8) {
        final direction = lateral.abs() > .5
            ? lateral.sign
            : preferredSide(item);
        adjustment += side * (direction * distance * weight * .75);
      }
    }
    final result = delta + adjustment;
    return result.distance > distance
        ? result / result.distance * distance
        : result;
  }

  /// Existing overlaps may escape, but no step may deepen their penetration.
  /// A contained body may first move away from the center before its area drops.
  static bool permits(Rect from, Rect to, Rect obstacle) {
    if (!to.overlaps(obstacle)) return true;
    if (!from.overlaps(obstacle)) return false;
    final before = from.intersect(obstacle), after = to.intersect(obstacle);
    final beforeArea = before.width * before.height,
        afterArea = after.width * after.height;
    if (afterArea < beforeArea - .0001) return true;
    return (afterArea - beforeArea).abs() <= .0001 &&
        (to.center - obstacle.center).distanceSquared >
            (from.center - obstacle.center).distanceSquared + .0001;
  }
}

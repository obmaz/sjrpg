import 'dart:math' as math;
import 'dart:ui';

class _SpacingBody {
  _SpacingBody(this.body, this.space) : center = body.center;
  Rect body;
  Size space;
  Offset center;

  void update(Rect next, Size nextSpace) {
    body = next;
    center = next.center;
    space = nextSpace;
  }
}

/// A local, immediately updated index for crowd steering between engine steps.
/// Bonfire's hitboxes still resolve physical contacts after component updates.
class EnemySpacing<T extends Object> {
  static const cellSize = 96.0;
  final _cells = <(int, int), Set<T>>{};
  final _bodies = <T, _SpacingBody>{};
  final _slots = <T, (int, int)>{};
  final _order = <T, int>{};
  int _nextOrder = 0;

  void clear() {
    _cells.clear();
    _bodies.clear();
    _slots.clear();
    _order.clear();
    _nextOrder = 0;
  }

  void update(T item, Rect body, {Size? personalSpace}) {
    final entry = _bodies[item];
    final _SpacingBody current;
    if (entry == null) {
      current = _SpacingBody(body, personalSpace ?? body.size);
      _bodies[item] = current;
    } else {
      entry.update(body, personalSpace ?? body.size);
      current = entry;
    }
    _order.putIfAbsent(item, () => _nextOrder++);
    final center = current.center;
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
  }

  void remove(T item) {
    final slot = _slots.remove(item);
    if (slot != null) {
      final bucket = _cells[slot]!;
      bucket.remove(item);
      if (bucket.isEmpty) _cells.remove(slot);
    }
    _bodies.remove(item);
    _order.remove(item);
  }

  bool contains(T item) => _bodies.containsKey(item);
  Rect bodyOf(T item) => _bodies[item]!.body;
  double preferredSide(T item) => _order[item]!.isEven ? 1 : -1;

  double _proximitySquared(T item, Rect body, T other) {
    final otherBody = _bodies[other]!;
    final difference = body.center - otherBody.center;
    final a = _bodies[item]!.space, b = otherBody.space;
    final x = difference.dx / ((a.width + b.width) / 2);
    final y = difference.dy / ((a.height + b.height) / 2);
    return x * x + y * y;
  }

  bool permitsPersonalSpace(T item, Rect from, Rect to, T other) {
    final after = _proximitySquared(item, to, other);
    if (after >= 1) return true;
    final before = _proximitySquared(item, from, other);
    if (after >= before) return true;
    // Most probes are outside the illustration ellipse or move away from it.
    // Only an inward probe needs the original linear-distance tolerance.
    return math.sqrt(after) >= math.sqrt(before) - .000001;
  }

  /// Soft illustration spacing never enlarges the physical terrain hitbox.
  Offset separation(T item, Rect body, Iterable<T> neighbors, double step) {
    var force = Offset.zero, pressure = 0.0;
    final center = body.center;
    for (final other in neighbors) {
      final squared = _proximitySquared(item, body, other);
      if (squared >= .97 * .97) continue;
      final proximity = math.sqrt(squared);
      pressure = math.max(pressure, 1 - proximity);
      var away = center - _bodies[other]!.center;
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
    final center = body.center, space = _bodies[item]!.space;
    var adjustment = Offset.zero;
    for (final other in neighbors) {
      final next = _bodies[other]!;
      final difference = center - next.center;
      final reachX = (space.width + next.space.width) / 2,
          reachY = (space.height + next.space.height) / 2;
      final dx = difference.dx / reachX, dy = difference.dy / reachY;
      final squared = dx * dx + dy * dy;
      if (squared >= 1) continue;
      final proximity = math.sqrt(squared);
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

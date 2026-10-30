import 'dart:math' as math;
import 'dart:ui';

class MapMarker {
  const MapMarker(this.id, this.anchor, this.radius);
  final String id;
  final Offset anchor;

  /// Complete painted radius, including the outline and selection ring.
  final double radius;
}

class MapMarkerGroup {
  const MapMarkerGroup(this.items, this.center, this.radius);
  final List<MapMarker> items;
  final Offset center;
  final double radius;
}

/// Layout operates in map-canvas coordinates; unit is inverse map zoom.
/// Markers merge before painting rather than being pushed beyond the map edge.
class MapMarkerLayout {
  const MapMarkerLayout(this.bounds, {required this.round, this.unit = 1});
  final Rect bounds;
  final bool round;
  final double unit;

  Offset contain(Offset at, double radius) {
    final inset = radius + 4 * unit;
    if (round) {
      final delta = at - bounds.center;
      final edge = math.max(0.0, bounds.shortestSide / 2 - inset);
      return delta.distance <= edge || delta.distance == 0
          ? at
          : bounds.center + delta / delta.distance * edge;
    }
    final safe = bounds.deflate(inset);
    return Offset(
      at.dx.clamp(safe.left, safe.right),
      at.dy.clamp(safe.top, safe.bottom),
    );
  }

  List<MapMarkerGroup> layout(Iterable<MapMarker> markers, {Offset? hero}) {
    MapMarkerGroup group(List<MapMarker> items) {
      final radius = items.length == 1
          ? items.single.radius
          : (round ? 8.0 : 12.0) * unit;
      final mean =
          items
              .map((m) => contain(m.anchor, radius))
              .fold(Offset.zero, (a, b) => a + b) /
          items.length.toDouble();
      var center = contain(mean, radius);
      if (hero != null && items.length > 1) {
        var delta = center - hero;
        final separation = radius + (round ? 6 : 14) * unit;
        if (delta.distance < separation) {
          if (delta.distance < .01) delta = const Offset(1, -1);
          center = contain(hero + delta / delta.distance * separation, radius);
          // Clamping at a corner can pull the group back onto the player.
          // Prefer the nearest direction with enough room for both markers.
          if ((center - hero).distance < separation - .01) {
            var nearest = double.infinity;
            for (var step = 0; step < 16; step++) {
              final angle = step * math.pi / 8;
              final candidate = contain(
                hero + Offset(math.cos(angle), math.sin(angle)) * separation,
                radius,
              );
              if ((candidate - hero).distance < separation - .01) continue;
              final cost = (candidate - mean).distanceSquared;
              if (cost < nearest) {
                nearest = cost;
                center = candidate;
              }
            }
          }
        }
      }
      return MapMarkerGroup(List.unmodifiable(items), center, radius);
    }

    final groups = [
      for (final marker in markers) group([marker]),
    ];
    var merged = true;
    while (merged) {
      merged = false;
      for (var i = 0; i < groups.length && !merged; i++) {
        for (var j = i + 1; j < groups.length; j++) {
          if ((groups[i].center - groups[j].center).distance <
              groups[i].radius + groups[j].radius + 2 * unit) {
            groups[i] = group([...groups[i].items, ...groups[j].items]);
            groups.removeAt(j);
            merged = true;
            break;
          }
        }
      }
    }
    return groups;
  }
}

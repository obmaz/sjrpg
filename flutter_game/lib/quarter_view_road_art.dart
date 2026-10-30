import 'dart:math' as math;
import 'dart:ui';

import 'world_model.dart';

/// Low, oblique stone faces follow actual authored roads. This adds no roads or
/// collision: their exact path is shared with terrain and the adventure map.
abstract final class QuarterViewRoadArt {
  static void paint(Canvas canvas, Iterable<Trail> trails, Rect view) {
    final shade = Paint()..color = const Color(0x4d342c20);
    final stone = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6
      ..color = const Color(0x555d594a);
    for (final trail in trails) {
      if (!trail.bounds.inflate(trail.width).overlaps(view)) {
        continue;
      }
      final radius = math.max(6.0, trail.width / 2 - 10);
      final clip = Path();
      for (var i = 1; i < trail.points.length; i++) {
        final a = trail.points[i - 1], b = trail.points[i], delta = b - a;
        if (delta.distance < .01) {
          continue;
        }
        final side = Offset(-delta.dy, delta.dx) / delta.distance * radius;
        clip.addPolygon([a - side, b - side, b + side, a + side], true);
      }
      for (final at in trail.points) {
        clip.addOval(Rect.fromCircle(center: at, radius: radius));
      }
      canvas.save();
      canvas.clipPath(clip);
      var travelled = 0.0;
      for (var segment = 1; segment < trail.points.length; segment++) {
        final a = trail.points[segment - 1], b = trail.points[segment];
        final delta = b - a, length = delta.distance;
        if (length < .01) {
          continue;
        }
        final direction = delta / length;
        final side = Offset(-direction.dy, direction.dx);
        if (!Rect.fromPoints(a, b).inflate(trail.width).overlaps(view)) {
          travelled += length;
          continue;
        }
        final projections =
            [
              view.topLeft,
              view.topRight,
              view.bottomLeft,
              view.bottomRight,
            ].map(
              (p) =>
                  (p.dx - a.dx) * direction.dx + (p.dy - a.dy) * direction.dy,
            );
        final start = math.max(0.0, projections.reduce(math.min) - trail.width);
        final end = math.min(
          length,
          projections.reduce(math.max) + trail.width,
        );
        const step = 31.0;
        final first = ((travelled + start) / step).floor();
        final last = ((travelled + end) / step).ceil();
        for (var row = first; row <= last; row++) {
          final along = row * step - travelled;
          if (along < 0 || along > length) {
            continue;
          }
          for (var lane = -1; lane <= 1; lane++) {
            final variation = (row * 17 + lane * 29).abs();
            // Buried gaps and staggered stones avoid a tiled ribbon silhouette.
            if (variation % 7 == 0) {
              continue;
            }
            final at =
                a +
                direction * (along + lane * 5) +
                side * (lane * radius * .55);
            if (!view.inflate(20).contains(at)) {
              continue;
            }
            final width = 8.0 + variation % 5;
            final depth = 3.5 + variation % 3;
            final top = Path()
              ..moveTo(at.dx - width, at.dy - depth * .25)
              ..lineTo(at.dx + width * .42, at.dy - depth)
              ..lineTo(at.dx + width, at.dy + depth * .2)
              ..lineTo(at.dx - width * .35, at.dy + depth)
              ..close();
            canvas.drawPath(top.shift(const Offset(.8, 1.8)), shade);
            stone.color = Color.lerp(
              const Color(0x999b987f),
              const Color(0xaaaca48a),
              (variation % 5) / 4,
            )!;
            canvas.drawPath(top, stone);
            canvas.drawPath(top, edge);
          }
        }
        travelled += length;
      }
      canvas.restore();
    }
  }
}

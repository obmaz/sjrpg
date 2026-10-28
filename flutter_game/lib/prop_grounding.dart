import 'dart:math' as math;
import 'dart:ui' as ui;

import 'world_model.dart';

/// A restrained ground-plane cue, not a new platform or collision footprint.
/// All props share the same upper-left light; the short lower-right projection
/// and contact area are one silhouette, so overlapping pieces do not darken twice.
class PropGroundShadow {
  PropGroundShadow(WorldProp prop)
    : path = _silhouette(prop),
      color = ui.Color.fromARGB(prop.kind == 'tree' ? 32 : 38, 15, 24, 21);
  final ui.Path path;
  final ui.Color color;
  late final ui.Rect bounds = path.getBounds().inflate(1);

  static ui.Path _silhouette(WorldProp prop) {
    final path = ui.Path();
    final natural = prop.kind == 'tree' || prop.kind == 'cactus';
    if (natural) {
      final feet = prop.body.bottomCenter;
      final length = (prop.drawSize.height * .15).clamp(6.0, 32.0);
      final width = math.max(prop.body.width, prop.drawSize.width * .38);
      final center = feet + ui.Offset(length * .65, length * .32 - 2);
      path.addOval(
        ui.Rect.fromCenter(
          center: center,
          width: width + length,
          height: (width * .26).clamp(8.0, 24.0),
        ),
      );
      return path;
    }
    // The arch and open forge have several real supports. Keep the walkable
    // gap readable by grounding those supports, not an invented solid slab.
    for (final body in prop.collisionBodies) {
      final projection = (prop.drawSize.height * .065).clamp(3.0, 15.0);
      final back = body.bottom - (body.height * .2).clamp(3.0, 14.0);
      path.addPolygon([
        ui.Offset(body.left - 2, back),
        ui.Offset(body.right - 1, back),
        ui.Offset(body.right + projection, body.bottom + projection * .45),
        ui.Offset(body.left + projection * .45, body.bottom + projection * .4),
      ], true);
    }
    return path;
  }
}

/// Reuses the world's existing 256px prop buckets. Only nearby supports enter a
/// cached terrain sector: no global scan, new spatial index, blur or raster layer.
class PropGrounding {
  PropGrounding(this.buckets);
  final Map<String, List<WorldProp>> buckets;
  final _paint = ui.Paint();

  Set<WorldProp> _nearby(int col, int row) {
    final props = <WorldProp>{};
    // The existing index includes sprite extents; one extra bucket also covers
    // the short projected shadow from an adjacent support.
    for (var y = row * 2 - 1; y <= row * 2 + 2; y++) {
      for (var x = col * 2 - 1; x <= col * 2 + 2; x++) {
        props.addAll(buckets['$x:$y'] ?? const <WorldProp>[]);
      }
    }
    return props;
  }

  int candidates(int col, int row) => _nearby(col, row).length;

  void paintSector(ui.Canvas canvas, int col, int row) {
    final area = ui.Rect.fromLTWH(col * 512, row * 512, 512, 512);
    for (final prop in _nearby(col, row)) {
      final shadow = PropGroundShadow(prop);
      if (shadow.bounds.overlaps(area)) {
        canvas.drawPath(shadow.path, _paint..color = shadow.color);
      }
    }
  }
}

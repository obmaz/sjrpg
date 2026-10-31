import 'dart:ui';

import 'bridge_collision_frames.dart';

/// Native floor, rail and pier coordinates share the abbey's oblique projection.
/// The saved rectangle retains its ID/width; it is not the walkable silhouette.
abstract final class QuarterViewBridgeArt {
  static const stripWidth = 48.0;
  static const stripCount = 32;
  static const sourceSize = Size(1536, 1024);
  static const deckCenter = Offset(775, 435);
  static const deckHorizontalSpan = 950.0;
  static const axisStart = Offset(300, 660), axisEnd = Offset(1250, 210);
  static const slope = -450 / 950;
  static const deckPolygon = [
    Offset(155, 598),
    Offset(1105, 148),
    Offset(1395, 272),
    Offset(445, 722),
  ];
  static const _solids = [
    ...bridgeFrontPolygons,
    [Offset(125, 548), Offset(1090, 100), Offset(1105, 148), Offset(155, 598)],
    [Offset(390, 680), Offset(465, 700), Offset(490, 790), Offset(410, 760)],
  ];

  static double scale(Rect bridge) => bridge.width / deckHorizontalSpan;
  static Offset point(Rect bridge, Offset pixel) =>
      bridge.center + (pixel - deckCenter) * scale(bridge);
  static Offset axisPoint(Rect bridge, double t) =>
      point(bridge, axisStart + (axisEnd - axisStart) * t);
  static List<Offset> approach(Rect bridge, {double distance = 100}) => [
    axisPoint(bridge, 0) - Offset(distance, 0),
    axisPoint(bridge, 0),
    axisPoint(bridge, 1),
    axisPoint(bridge, 1) +
        Offset(distance, slope * (distance > 80 ? 80 : distance)),
  ];
  static List<Offset> walkablePolygon(Rect bridge) => [
    for (final p in deckPolygon) point(bridge, p),
  ];
  static Iterable<List<Offset>> solids(Rect bridge) sync* {
    for (final polygon in _solids) {
      yield [for (final p in polygon) point(bridge, p)];
    }
  }

  static bool contains(Rect bridge, Offset at) {
    final p = (at - bridge.center) / scale(bridge) + deckCenter;
    var sign = 0.0;
    for (var i = 0; i < deckPolygon.length; i++) {
      final a = deckPolygon[i], b = deckPolygon[(i + 1) % deckPolygon.length];
      final cross =
          (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
      if (cross.abs() < .001) continue;
      if (sign == 0) sign = cross;
      if (cross * sign < 0) return false;
    }
    return true;
  }

  static bool supports(Rect bridge, Rect body) => [
    body.topLeft,
    body.topRight,
    body.bottomLeft,
    body.bottomRight,
  ].every((p) => contains(bridge, p));
  static Rect visualBounds(Rect bridge) {
    final at = point(bridge, Offset.zero), k = scale(bridge);
    return Rect.fromLTWH(
      at.dx,
      at.dy,
      sourceSize.width * k,
      sourceSize.height * k,
    );
  }

  static Path floorPath(Rect bridge) =>
      Path()..addPolygon(walkablePolygon(bridge), true);

  static double railDepth(Rect bridge, double sourceX, {required bool front}) {
    final strip = (sourceX / stripWidth).floor().clamp(0, stripCount - 1);
    if (front) {
      return point(bridge, Offset(sourceX, bridgeFrontDepths[strip])).dy;
    }
    final x = strip * stripWidth;
    return point(bridge, Offset(x, 598 + (x - 155) * slope)).dy;
  }

  static Rect railBounds(Rect bridge, int strip, {required bool front}) {
    final k = scale(bridge), visual = visualBounds(bridge);
    final x = visual.left + strip * stripWidth * k;
    final floor = point(
      bridge,
      Offset(
        strip * stripWidth,
        front
            ? 722 + (strip * stripWidth - 445) * slope
            : 598 + (strip * stripWidth - 155) * slope,
      ),
    ).dy;
    final topReference = floor - (front ? 170 : 180) * k;
    final apronTop = point(bridge, const Offset(0, 710)).dy;
    final rawTop = front && strip * stripWidth < 445 && apronTop < topReference
        ? apronTop
        : topReference;
    final top = rawTop.clamp(visual.top, visual.bottom);
    final bottom =
        (front
                ? point(bridge, Offset(0, bridgeFrontDepths[strip])).dy + 8 * k
                : floor + 8 * k)
            .clamp(top, visual.bottom);
    return Rect.fromLTRB(x, top, x + stripWidth * k, bottom);
  }

  static final _backMask = Path()
    ..addPolygon([
      const Offset(0, -1000),
      const Offset(1536, -1000),
      Offset(1536, 598 + (1536 - 155) * slope),
      Offset(0, 598 - 155 * slope),
    ], true);
  static final _frontMask = () {
    final path = Path()
      ..addPolygon([
        Offset(0, 722 - 445 * slope - 55),
        Offset(1536, 722 + (1536 - 445) * slope - 55),
        const Offset(1536, 1024),
        const Offset(0, 1024),
      ], true);
    path.addRect(const Rect.fromLTRB(0, 710, 445, 1024));
    // Trace only the post silhouettes above the parapet. Rectangular crops
    // would also replay adjacent floorboards over a character standing there.
    for (final polygon in const [
      [
        Offset(425, 590),
        Offset(405, 619),
        Offset(389, 628),
        Offset(389, 638),
        Offset(395, 642),
        Offset(396, 686),
        Offset(454, 686),
        Offset(454, 644),
        Offset(462, 638),
        Offset(461, 629),
        Offset(446, 621),
      ],
      [
        Offset(790, 440),
        Offset(772, 469),
        Offset(758, 478),
        Offset(758, 485),
        Offset(765, 488),
        Offset(765, 524),
        Offset(819, 524),
        Offset(819, 489),
        Offset(826, 484),
        Offset(826, 477),
        Offset(808, 468),
      ],
      [
        Offset(1110, 290),
        Offset(1096, 314),
        Offset(1079, 321),
        Offset(1079, 330),
        Offset(1086, 334),
        Offset(1086, 375),
        Offset(1140, 375),
        Offset(1140, 335),
        Offset(1145, 330),
        Offset(1145, 322),
        Offset(1127, 314),
      ],
      [
        Offset(1430, 140),
        Offset(1412, 164),
        Offset(1398, 174),
        Offset(1398, 182),
        Offset(1405, 187),
        Offset(1405, 226),
        Offset(1458, 226),
        Offset(1458, 186),
        Offset(1461, 180),
        Offset(1461, 173),
        Offset(1448, 163),
      ],
    ]) {
      path.addPolygon(polygon.reversed.toList(), true);
    }
    return path;
  }();

  static void draw(Canvas canvas, Image image, Rect bridge) {
    canvas.drawImageRect(
      image,
      Offset.zero & sourceSize,
      visualBounds(bridge),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  static void drawRail(
    Canvas canvas,
    Image image,
    Rect bridge,
    int strip, {
    required bool front,
  }) {
    final origin = point(bridge, Offset.zero), k = scale(bridge);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(k);
    canvas.clipRect(
      Rect.fromLTWH(strip * stripWidth, 0, stripWidth, sourceSize.height),
      doAntiAlias: false,
    );
    canvas.clipPath(front ? _frontMask : _backMask, doAntiAlias: false);
    canvas.drawImage(
      image,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }
}

import 'dart:ui';

/// The generated deck remains horizontal in world coordinates; visible front
/// arches extend below its walkable plane rather than flattening into that plane.
abstract final class QuarterViewBridgeArt {
  static const sourceSize = Size(1544, 680);
  static const deckCenter = Offset(764, 259);
  static const deckHorizontalSpan = 1320.0;
  // Outer deck band, including low parapet bases; the front arches lie below.
  static const deckPolygon = [
    Offset(104, 83),
    Offset(1424, 83),
    Offset(1424, 435),
    Offset(104, 435),
  ];

  static Rect visualBounds(Rect walkway) {
    final scale = walkway.width / deckHorizontalSpan;
    return Rect.fromLTWH(
      walkway.center.dx - deckCenter.dx * scale,
      walkway.center.dy - deckCenter.dy * scale,
      sourceSize.width * scale,
      sourceSize.height * scale,
    );
  }

  static void draw(Canvas canvas, Image image, Rect walkway) {
    canvas.drawImageRect(
      image,
      Offset.zero & sourceSize,
      visualBounds(walkway),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

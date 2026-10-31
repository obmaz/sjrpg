import 'dart:math' as math;
import 'dart:ui';
import 'natural_object_frames.dart';

/// World props use measured roots and native aspect, never square atlas icons.
abstract final class NaturalObjectArt {
  static Rect bounds(
    int index,
    Offset feet,
    double height, {
    double? maxWidth,
  }) {
    final f = naturalObjectFrames[index];
    var scale = height / f.height;
    if (maxWidth != null) scale = math.min(scale, maxWidth / f.source.width);
    return Rect.fromLTWH(
      feet.dx - (f.foot.dx - f.source.left) * scale,
      feet.dy - (f.foot.dy - f.source.top) * scale,
      f.source.width * scale,
      f.source.height * scale,
    );
  }

  static void draw(
    Canvas canvas,
    Image image,
    int index,
    Offset feet,
    double height, {
    double? maxWidth,
    double opacity = 1,
  }) {
    canvas.drawImageRect(
      image,
      naturalObjectFrames[index].source,
      bounds(index, feet, height, maxWidth: maxWidth),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1).toDouble()),
    );
  }
}

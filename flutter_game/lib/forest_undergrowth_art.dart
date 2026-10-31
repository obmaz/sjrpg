import 'dart:ui';

import 'forest_undergrowth_frames.dart';

abstract final class ForestUndergrowthArt {
  static const prefix = 'forest-undergrowth-';
  static const frames = undergrowthFrames;
  static int? variantOf(String kind) => kind.startsWith(prefix)
      ? int.tryParse(kind.substring(prefix.length))
      : null;

  static Size drawSize(int variant, {double factor = 1}) {
    final f = frames[variant], height = f.height * factor;
    return Size(f.source.width / f.source.height * height, height);
  }

  static Rect bounds(Offset feet, int variant, double height) {
    final f = frames[variant], scale = height / f.source.height;
    return Rect.fromLTWH(
      feet.dx - (f.foot.dx - f.source.left) * scale,
      feet.dy - (f.foot.dy - f.source.top) * scale,
      f.source.width * scale,
      height,
    );
  }

  static void draw(
    Canvas canvas,
    Image atlas,
    Offset feet,
    int variant,
    double height,
  ) {
    canvas.drawImageRect(
      atlas,
      frames[variant].source,
      bounds(feet, variant, height),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

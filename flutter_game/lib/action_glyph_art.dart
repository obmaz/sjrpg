import 'dart:ui' as ui;

/// Legible generated silhouettes, fitted to measured alpha bounds.
abstract final class ActionGlyphArt {
  static const _bounds = <ui.Rect>[
    ui.Rect.fromLTRB(0.05143229, 0.06054688, 0.22721354, 0.32324219),
    ui.Rect.fromLTRB(0.27864583, 0.08203125, 0.47265625, 0.30566406),
    ui.Rect.fromLTRB(0.54427083, 0.07421875, 0.71940104, 0.31347656),
    ui.Rect.fromLTRB(0.78320312, 0.06054688, 0.95572917, 0.30468750),
    ui.Rect.fromLTRB(0.04427083, 0.40136719, 0.22135417, 0.62207031),
    ui.Rect.fromLTRB(0.30208333, 0.38476562, 0.46223958, 0.63281250),
    ui.Rect.fromLTRB(0.54296875, 0.39941406, 0.72460938, 0.62011719),
    ui.Rect.fromLTRB(0.78841146, 0.38867188, 0.96223958, 0.63183594),
    ui.Rect.fromLTRB(0.03841146, 0.69531250, 0.24348958, 0.91601562),
    ui.Rect.fromLTRB(0.30338542, 0.68457031, 0.46093750, 0.94042969),
    ui.Rect.fromLTRB(0.57161458, 0.68066406, 0.69726562, 0.94238281),
    ui.Rect.fromLTRB(0.78125000, 0.70117188, 0.97135417, 0.93261719),
  ];

  static bool draw(
    ui.Canvas canvas,
    ui.Image? image,
    int index,
    ui.Rect destination, {
    ui.Color? tint,
  }) {
    if (image == null ||
        index < 0 ||
        index >= _bounds.length ||
        destination.isEmpty) {
      return false;
    }
    final unit = _bounds[index];
    final source = ui.Rect.fromLTRB(
      unit.left * image.width,
      unit.top * image.height,
      unit.right * image.width,
      unit.bottom * image.height,
    );
    final scale =
        (destination.width / source.width < destination.height / source.height)
        ? destination.width / source.width
        : destination.height / source.height;
    final target = ui.Rect.fromCenter(
      center: destination.center,
      width: source.width * scale,
      height: source.height * scale,
    );
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    if (tint != null) {
      paint.colorFilter = ui.ColorFilter.mode(tint, ui.BlendMode.srcIn);
    }
    canvas.drawImageRect(image, source, target, paint);
    return true;
  }
}

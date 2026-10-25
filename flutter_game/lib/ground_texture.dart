import 'dart:ui' as ui;

// Blend periodic half-tile samples once at loading, keeping terrain frames layer-free.
void paintSeamlessGround(
  ui.Canvas canvas,
  ui.Image source,
  ui.Rect crop,
  double size,
) {
  final bounds = ui.Rect.fromLTWH(0, 0, size, size);
  const stops = [0.0, .25, .5, .75, 1.0];
  const weights = [
    [
      ui.Color(0x00ffffff),
      ui.Color(0x80ffffff),
      ui.Color(0xffffffff),
      ui.Color(0x80ffffff),
      ui.Color(0x00ffffff),
    ],
    [
      ui.Color(0xffffffff),
      ui.Color(0x80ffffff),
      ui.Color(0x00ffffff),
      ui.Color(0x80ffffff),
      ui.Color(0xffffffff),
    ],
  ];
  canvas.save();
  canvas.clipRect(bounds);
  for (var shiftY = 0; shiftY < 2; shiftY++) {
    for (var shiftX = 0; shiftX < 2; shiftX++) {
      canvas.saveLayer(bounds, ui.Paint()..blendMode = ui.BlendMode.plus);
      for (var y = 0; y <= shiftY; y++) {
        for (var x = 0; x <= shiftX; x++) {
          canvas.drawImageRect(
            source,
            crop,
            ui.Rect.fromLTWH(
              x * size - shiftX * size / 2,
              y * size - shiftY * size / 2,
              size,
              size,
            ),
            ui.Paint()..filterQuality = ui.FilterQuality.low,
          );
        }
      }
      canvas.drawRect(
        bounds,
        ui.Paint()
          ..blendMode = ui.BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            ui.Offset.zero,
            ui.Offset(size, 0),
            weights[shiftX],
            stops,
          ),
      );
      canvas.drawRect(
        bounds,
        ui.Paint()
          ..blendMode = ui.BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            ui.Offset.zero,
            ui.Offset(0, size),
            weights[shiftY],
            stops,
          ),
      );
      canvas.restore();
    }
  }
  canvas.restore();
}

import 'dart:ui' as ui;

// Blend periodic half-tile samples once at loading, keeping terrain frames layer-free.
void paintSeamlessGround(
  ui.Canvas canvas,
  ui.Image source,
  ui.Rect crop,
  double size, {
  bool preserveCenter = false,
}) {
  final bounds = ui.Rect.fromLTWH(0, 0, size, size);
  final stops = preserveCenter
      ? const [0.0, .075, .925, 1.0]
      : const [0.0, .25, .5, .75, 1.0];
  final weights = preserveCenter
      ? const [
          [
            ui.Color(0x80ffffff),
            ui.Color(0xffffffff),
            ui.Color(0xffffffff),
            ui.Color(0x80ffffff),
          ],
          [
            ui.Color(0x80ffffff),
            ui.Color(0x00ffffff),
            ui.Color(0x00ffffff),
            ui.Color(0x80ffffff),
          ],
        ]
      : const [
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
      if (preserveCenter) {
        canvas.save();
        canvas.translate(shiftX * size, shiftY * size);
        canvas.scale(shiftX == 0 ? 1 : -1, shiftY == 0 ? 1 : -1);
        canvas.drawImageRect(
          source,
          crop,
          bounds,
          ui.Paint()..filterQuality = ui.FilterQuality.low,
        );
        canvas.restore();
      } else {
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

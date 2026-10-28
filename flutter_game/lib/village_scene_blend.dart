import 'dart:ui' as ui;

/// Keeps the fountain and market at their collision-authored coordinates while
/// joining their ground to the courtyard. Baking once avoids runtime layers.
void paintVillageSceneBlend(
  ui.Canvas canvas,
  ui.Image village,
  ui.Rect target,
) {
  canvas.drawImageRect(
    village,
    ui.Rect.fromLTWH(0, 0, village.width.toDouble(), village.height.toDouble()),
    target,
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  canvas.saveLayer(target, ui.Paint()..blendMode = ui.BlendMode.dstIn);
  final x = target.left, y = target.top, w = target.width, h = target.height;
  // The right-hand market roof and posts must not turn into a translucent
  // straight strip. Ground at the southern approach has a broader soft join.
  final silhouette = ui.Path()
    ..moveTo(x + 32, y + 26)
    ..cubicTo(x + w * .3, y + 15, x + w * .6, y + 40, x + w - 32, y + 21)
    ..cubicTo(
      x + w - 48,
      y + h * .12,
      x + w - 10,
      y + h * .2,
      x + w - 12,
      y + h * .31,
    )
    ..cubicTo(
      x + w - 10,
      y + h * .4,
      x + w - 32,
      y + h * .46,
      x + w - 23,
      y + h * .57,
    )
    ..cubicTo(
      x + w - 12,
      y + h * .69,
      x + w - 45,
      y + h * .79,
      x + w - 27,
      y + h * .88,
    )
    ..cubicTo(
      x + w * .85,
      y + h - 65,
      x + w * .7,
      y + h - 115,
      x + w * .56,
      y + h - 80,
    )
    ..cubicTo(
      x + w * .37,
      y + h - 40,
      x + w * .19,
      y + h - 100,
      x + 27,
      y + h - 75,
    )
    ..cubicTo(x + 42, y + h * .72, x + 15, y + h * .63, x + 25, y + h * .51)
    ..cubicTo(x + 40, y + h * .4, x + 13, y + h * .3, x + 27, y + h * .2)
    ..cubicTo(x + 38, y + h * .12, x + 14, y + h * .08, x + 32, y + 26)
    ..close();
  canvas.drawPath(
    silhouette,
    ui.Paint()
      ..color = const ui.Color(0xffffffff)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12),
  );
  canvas.restore();
  // Guarantee a fully transparent outside edge, including the narrow market
  // side. This final 4px fringe cannot erase any mapped support or doorway.
  for (final edge in [
    (ui.Rect.fromLTWH(x, y, 4, h), ui.Offset(x, y), ui.Offset(x + 4, y)),
    (
      ui.Rect.fromLTWH(x + w - 4, y, 4, h),
      ui.Offset(x + w, y),
      ui.Offset(x + w - 4, y),
    ),
    (ui.Rect.fromLTWH(x, y, w, 4), ui.Offset(x, y), ui.Offset(x, y + 4)),
    (
      ui.Rect.fromLTWH(x, y + h - 4, w, 4),
      ui.Offset(x, y + h),
      ui.Offset(x, y + h - 4),
    ),
  ]) {
    canvas.drawRect(
      edge.$1,
      ui.Paint()
        ..blendMode = ui.BlendMode.dstIn
        ..shader = ui.Gradient.linear(edge.$2, edge.$3, const [
          ui.Color(0x00ffffff),
          ui.Color(0xffffffff),
        ]),
    );
  }
}

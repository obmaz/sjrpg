import 'dart:ui' as ui;

import 'world_model.dart';

/// Four shared stone silhouettes, grounded at the actual solid footprint.
abstract final class DesertTempleArt {
  static const imageKey = 'desert-temple';
  static final _paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
  static bool supports(String kind) => kind.startsWith('temple-');
  static ui.Rect destination(WorldProp prop) => ui.Rect.fromLTWH(
    prop.body.bottomCenter.dx - prop.drawSize.width / 2,
    prop.body.bottom - prop.drawSize.height * .9375,
    prop.drawSize.width,
    prop.drawSize.height,
  );
  static void draw(
    ui.Canvas canvas,
    ui.Image? image,
    WorldProp prop, {
    double opacity = 1,
  }) {
    if (image == null) return;
    final index = int.tryParse(prop.kind.substring(7));
    if (index == null || index < 0 || index > 3) return;
    final cell = image.width / 2;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(index % 2 * cell, index ~/ 2 * cell, cell, cell),
      destination(prop),
      _paint..color = ui.Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1)),
    );
  }
}

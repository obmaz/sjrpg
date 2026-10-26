import 'dart:ui' as ui;

import 'rpg_model.dart';

/// The inventory and ground drops use the same six-column equipment sheet.
abstract final class GearIconArt {
  static ui.Rect? source(ui.Image image, GearDef gear) {
    final index = gearCatalog.indexOf(gear);
    if (index < 0) return null;
    final cell = image.width / 6;
    return ui.Rect.fromLTWH(
      (index % 6) * cell,
      (index ~/ 6) * cell,
      cell,
      cell,
    );
  }
}

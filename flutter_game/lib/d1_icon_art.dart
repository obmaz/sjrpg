import 'dart:ui' as ui;

import 'barbarian_icon_art.dart';
import 'game_art.dart';
import 'sorceress_icon_art.dart';

/// Generated D1 symbols retain their skill colors at a restrained saturation.
abstract final class D1IconArt {
  static const interfaceKey = 'd1-interface';
  static const warriorKey = 'd1-warrior';
  static const mageKey = 'd1-mage';
  static int? effectIndex(int effect) =>
      BarbarianIconArt.containsEffect(effect) ||
          SorceressIconArt.containsEffect(effect)
      ? effect
      : switch (effect) {
          34 => 5,
          35 => 9,
          36 => 11,
          7 => 8,
          _ => null,
        };
  static bool hasEffect(GameArt art, int effect) =>
      effectIndex(effect) != null &&
      art.images.containsKey(
        BarbarianIconArt.containsEffect(effect)
            ? warriorKey
            : SorceressIconArt.containsEffect(effect)
            ? mageKey
            : interfaceKey,
      );
  static const _tone = ui.ColorFilter.matrix([
    .787,
    .179,
    .024,
    0,
    0,
    .053,
    .913,
    .024,
    0,
    0,
    .053,
    .179,
    .758,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
  static bool draw(
    ui.Canvas canvas,
    GameArt art,
    int index,
    ui.Rect target, {
    bool compact = false,
  }) {
    final (asset, local, columns, rows) = SorceressIconArt.containsEffect(index)
        ? (mageKey, index - SorceressIconArt.firstEffect, 6, 5)
        : BarbarianIconArt.containsEffect(index)
        ? (warriorKey, index - BarbarianIconArt.firstEffect, 6, 5)
        : (interfaceKey, index, 8, 4);
    if (local < 0 || local >= columns * rows || target.isEmpty) return false;
    canvas.save();
    canvas.clipPath(ui.Path()..addOval(target));
    // Keep one atlas grid for both battle faces and cropped status symbols.
    final destination = compact
        ? ui.Rect.fromCenter(
            center: target.center,
            width: target.width * 1.5,
            height: target.height * 1.5,
          )
        : target;
    final result = art.effects.draw(
      canvas,
      asset,
      local,
      destination,
      columns: columns,
      rows: rows,
      inset: 7,
      colorFilter: _tone,
    );
    canvas.restore();
    return result;
  }
}

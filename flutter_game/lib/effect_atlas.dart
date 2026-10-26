import 'dart:ui' as ui;

/// Shared image regions and paint state; animation clocks belong to each effect.
class EffectAtlas {
  EffectAtlas(this.images);
  final Map<String, ui.Image> images;
  final _grids = <String, _EffectGrid>{};
  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

  void warm() {
    for (final asset in [
      'fx-meteor',
      'fx-ice-nova',
      'fx-whirlwind',
      'fx-warcry',
    ]) {
      _grid(asset, 4, 4, 1);
    }
    _grid('fx-steel-whirlwind', 4, 9, 1);
    _grid('combat-fx', 4, 4, 0);
  }

  _EffectGrid? _grid(String asset, int columns, int rows, double inset) {
    final image = images[asset];
    if (image == null) return null;
    final cached = _grids[asset];
    if (cached != null &&
        identical(cached.image, image) &&
        cached.columns == columns &&
        cached.rows == rows &&
        cached.inset == inset) {
      return cached;
    }
    final grid = _EffectGrid(image, columns, rows, inset);
    _grids[asset] = grid;
    return grid;
  }

  ui.Rect? source(
    String asset,
    int frame, {
    int columns = 4,
    int rows = 4,
    double inset = 1,
  }) {
    final grid = _grid(asset, columns, rows, inset);
    return grid?.frames[frame.clamp(0, grid.frames.length - 1)];
  }

  bool draw(
    ui.Canvas canvas,
    String asset,
    int frame,
    ui.Rect destination, {
    int columns = 4,
    int rows = 4,
    double inset = 1,
    double opacity = 1,
  }) {
    final grid = _grid(asset, columns, rows, inset);
    if (grid == null) return false;
    _paint.color = ui.Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1));
    canvas.drawImageRect(
      grid.image,
      grid.frames[frame.clamp(0, grid.frames.length - 1)],
      destination,
      _paint,
    );
    return true;
  }
}

class _EffectGrid {
  _EffectGrid(this.image, this.columns, this.rows, this.inset)
    : frames = List.unmodifiable([
        for (var frame = 0; frame < columns * rows; frame++)
          ui.Rect.fromLTWH(
            frame % columns * image.width / columns + inset,
            frame ~/ columns * image.height / rows + inset,
            image.width / columns - inset * 2,
            image.height / rows - inset * 2,
          ),
      ]);
  final ui.Image image;
  final int columns, rows;
  final double inset;
  final List<ui.Rect> frames;
}

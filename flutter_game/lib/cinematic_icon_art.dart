import 'package:flutter/rendering.dart';

import 'game_art.dart';

abstract final class CinematicIconArt {
  static const imageKey = 'cinematic-interface';
  static bool draw(Canvas canvas, GameArt art, int index, Rect target) {
    canvas.save();
    canvas.clipPath(Path()..addOval(target));
    final result = art.effects.draw(
      canvas,
      imageKey,
      index,
      target,
      columns: 4,
      rows: 3,
      inset: 6,
    );
    canvas.restore();
    return result;
  }
}

class CinematicIconPainter extends CustomPainter {
  const CinematicIconPainter(this.art, this.index);
  final GameArt art;
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    CinematicIconArt.draw(canvas, art, index, Offset.zero & size);
  }

  @override
  bool shouldRepaint(covariant CinematicIconPainter old) =>
      old.art != art || old.index != index;
}

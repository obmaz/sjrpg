import 'dart:ui' as ui;

/// Native sprite boundaries and root contacts measured in the generated atlas.
class ForestTreeFrame {
  const ForestTreeFrame(this.source, this.foot, this.height);
  final ui.Rect source;
  final ui.Offset foot;
  final double height;

  double get scale => height / (foot.dy - source.top);
  ui.Rect bounds(ui.Offset at) => ui.Rect.fromLTWH(
    at.dx - (foot.dx - source.left) * scale,
    at.dy - height,
    source.width * scale,
    source.height * scale,
  );
}

/// Three generated species with three independently drawn height classes.
/// Composition follows the whole-stage concept, using real world masks.
abstract final class ForestTreeArt {
  static const atlasSide = 1440;
  static const speciesNames = ['oak', 'fir', 'willow'];
  static const frames = <ForestTreeFrame>[
    ForestTreeFrame(
      ui.Rect.fromLTWH(33, 5, 414, 470),
      ui.Offset(238.0096, 468.0297),
      200,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(505, 5, 429, 470),
      ui.Offset(739.8926, 469.7106),
      300,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(988, 5, 423, 470),
      ui.Offset(1221.0579, 470.9232),
      400,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(66, 485, 348, 470),
      ui.Offset(245.6585, 948.3936),
      200,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(548, 485, 343, 470),
      ui.Offset(718.8028, 950.1187),
      300,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(1031, 485, 337, 470),
      ui.Offset(1202.3130, 951.0646),
      400,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(24, 965, 431, 470),
      ui.Offset(242.4253, 1428.1743),
      200,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(491, 965, 458, 470),
      ui.Offset(742.0863, 1429.5799),
      300,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(998, 965, 403, 470),
      ui.Offset(1251.6463, 1431.0361),
      400,
    ),
  ];

  /// Inputs are measured from actual roads, groves and water, never frame RNG.
  /// Road and village edges remain low; tall trees belong to deep grove cores.
  static int variant({
    required ui.Offset at,
    required ui.Size worldSize,
    required bool nearWater,
    required bool roadEdge,
    required bool roadTransition,
    required double groveDepth,
    required double townDistance,
  }) {
    final x = at.dx / worldSize.width, y = at.dy / worldSize.height;
    final species = nearWater
        ? 2
        : x >= .56 && (y <= .45 || y >= .60)
        ? 1
        : 0;
    final age = townDistance < 1800 || roadEdge
        ? 0
        : !nearWater && groveDepth < .18
        ? 0
        : !roadTransition &&
              townDistance > 3000 &&
              (nearWater || groveDepth >= .55)
        ? 2
        : 1;
    return species * 3 + age;
  }

  static ui.Rect drawBounds(ui.Offset feet, int variant) =>
      frames[variant].bounds(feet);

  static ui.Size drawSize(int variant) =>
      drawBounds(ui.Offset.zero, variant).size;

  static void draw(
    ui.Canvas canvas,
    ui.Image image,
    ui.Offset feet,
    int variant, {
    double opacity = 1,
  }) {
    final frame = frames[variant];
    canvas.drawImageRect(
      image,
      frame.source,
      frame.bounds(feet),
      ui.Paint()
        ..filterQuality = ui.FilterQuality.medium
        ..color = ui.Color.fromRGBO(
          255,
          255,
          255,
          opacity.clamp(0.0, 1.0).toDouble(),
        ),
    );
  }
}

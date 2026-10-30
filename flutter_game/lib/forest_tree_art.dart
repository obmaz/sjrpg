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
      ui.Rect.fromLTWH(140, 278, 199, 194),
      ui.Offset(253, 467),
      140,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(562, 171, 315, 301),
      ui.Offset(718, 467),
      210,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(970, 78, 459, 394),
      ui.Offset(1209, 467),
      280,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(153, 739, 174, 213),
      ui.Offset(241, 947),
      140,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(590, 634, 260, 318),
      ui.Offset(709, 948),
      210,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(1047, 537, 305, 415),
      ui.Offset(1192, 947),
      280,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(129, 1219, 221, 213),
      ui.Offset(210, 1427),
      140,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(546, 1149, 347, 283),
      ui.Offset(721, 1427),
      210,
    ),
    ForestTreeFrame(
      ui.Rect.fromLTWH(987, 1105, 425, 327),
      ui.Offset(1188, 1427),
      280,
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

import 'dart:ui' as ui;

import 'world_model.dart';

/// Measured crops in the shared atlas, with the grounded plinth contact as the anchor.
class EncounterBeaconFrame {
  EncounterBeaconFrame(this.source, this.tip, double bodyHeight)
    : scale = 56 / bodyHeight,
      destination = ui.Rect.fromLTWH(
        -tip.dx * 56 / bodyHeight,
        -tip.dy * 56 / bodyHeight,
        source.width * 56 / bodyHeight,
        source.height * 56 / bodyHeight,
      );

  final ui.Rect source;
  final ui.Offset tip;
  final double scale;
  final ui.Rect destination;
}

/// Fixed, irregular source regions are shared by every solid encounter milestone.
abstract final class EncounterBeaconArt {
  static const hintTextOrigin = ui.Offset(-80, -84);
  static const hintBounds = ui.Rect.fromLTRB(-86, -86, 86, -66);
  static const visualBounds = ui.Rect.fromLTRB(-96, -92, 96, 16);
  static const shadowBounds = ui.Rect.fromLTWH(-20, -3, 40, 9);

  // Left is dormant, right is ready. Tip X is the mean alpha>32 position in
  // the last four body rows; Y is the exclusive bottom of that alpha bound.
  // Each pair shares a reference height so changing state never resizes it.
  static final _frames = <EncounterBeaconFrame>[
    EncounterBeaconFrame(
      const ui.Rect.fromLTWH(0, 0, 256, 256),
      const ui.Offset(151.79591837, 242),
      227.5,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTWH(256, 0, 256, 256),
      const ui.Offset(152.04347826, 241),
      227.5,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTWH(0, 256, 256, 256),
      const ui.Offset(145.20000000, 241),
      226.0,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTWH(256, 256, 256, 256),
      const ui.Offset(144.73239437, 242),
      226.0,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTWH(0, 512, 256, 256),
      const ui.Offset(152.26086957, 241),
      226.0,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTWH(256, 512, 256, 256),
      const ui.Offset(151.55384615, 241),
      226.0,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTWH(0, 768, 256, 256),
      const ui.Offset(144.87804878, 242),
      226.5,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTWH(256, 768, 256, 256),
      const ui.Offset(145.01960784, 241),
      226.5,
    ),
  ];

  static EncounterBeaconFrame frame(WorldStage stage, {required bool ready}) =>
      _frames[stage.visualStage.index * 2 + (ready ? 1 : 0)];

  static void draw(
    ui.Canvas canvas,
    ui.Image image,
    WorldStage stage, {
    required bool ready,
    required ui.Paint paint,
  }) {
    final region = frame(stage, ready: ready);
    paint
      ..color = ui.Color.fromRGBO(255, 255, 255, 1)
      ..filterQuality = ui.FilterQuality.medium;
    canvas.drawImageRect(image, region.source, region.destination, paint);
  }
}

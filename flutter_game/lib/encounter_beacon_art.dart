import 'dart:ui' as ui;

import 'world_model.dart';

/// Measured crops in the shared atlas, with the pointed body tip as the anchor.
class EncounterBeaconFrame {
  EncounterBeaconFrame(this.source, this.tip, double bodyHeight)
    : scale = 56 / bodyHeight,
      destination = ui.Rect.fromLTWH(
        -tip.dx * 56 / bodyHeight,
        -6 - tip.dy * 56 / bodyHeight,
        source.width * 56 / bodyHeight,
        source.height * 56 / bodyHeight,
      );

  final ui.Rect source;
  final ui.Offset tip;
  final double scale;
  final ui.Rect destination;
}

/// Fixed, irregular source regions are shared by every non-solid encounter mark.
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
      const ui.Rect.fromLTRB(295, 66, 442, 316),
      const ui.Offset(67.076923, 243),
      237,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTRB(832, 66, 984, 316),
      const ui.Offset(69.928571, 243),
      237,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTRB(278, 365, 452, 616),
      const ui.Offset(86.358974, 245),
      238,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTRB(818, 365, 993, 616),
      const ui.Offset(86.756757, 245),
      238,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTRB(286, 654, 443, 909),
      const ui.Offset(78.205882, 249),
      242.5,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTRB(826, 654, 985, 909),
      const ui.Offset(78.588235, 249),
      242.5,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTRB(284, 943, 446, 1188),
      const ui.Offset(79.358974, 238),
      231.5,
    ),
    EncounterBeaconFrame(
      const ui.Rect.fromLTRB(825, 943, 988, 1188),
      const ui.Offset(79.344828, 239),
      231.5,
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
      ..color = ui.Color.fromRGBO(255, 255, 255, ready ? .85 : .55)
      ..filterQuality = ui.FilterQuality.medium;
    canvas.drawImageRect(image, region.source, region.destination, paint);
  }
}

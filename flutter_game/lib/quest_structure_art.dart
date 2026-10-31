import 'dart:ui';

import 'landmark_terrace.dart';

/// Foot geometry is measured from the generated independent alpha silhouettes.
/// The apron and NPC approach stay separate from the solid building footprint.
abstract final class ForestQuestStructureArt {
  static _QuestStructureFrame _frame(String siteId) => switch (siteId) {
    'roots' => const _QuestStructureFrame(
      'forest-quest-chapel',
      Size(1305, 1221),
      Offset(654, 1124),
      Offset(504, 1104),
      1305 * 800 / 1221,
      [Offset(434, 724), Offset(904, 854), Offset(1274, 674), Offset(804, 544)],
    ),
    'moon' => const _QuestStructureFrame(
      'forest-quest-cottage',
      Size(575, 530),
      Offset(276, 490),
      Offset(142, 520),
      380,
      [Offset(121, 395), Offset(250, 459), Offset(517, 390), Offset(377, 330)],
    ),
    'sun' => const _QuestStructureFrame(
      'forest-quest-cave',
      Size(763, 563),
      Offset(388, 431),
      Offset(448, 504),
      300,
      [Offset(68, 315), Offset(405, 461), Offset(688, 353), Offset(369, 220)],
    ),
    _ => throw ArgumentError.value(siteId, 'siteId', 'Unknown forest quest'),
  };

  static String assetKey(String siteId) => _frame(siteId).key;

  static Offset artPoint(String siteId, Offset ground, Offset pixel) {
    final f = _frame(siteId);
    return ground + (pixel - f.ground) * (f.width / f.size.width);
  }

  static Offset npcPosition(String siteId, Offset ground) =>
      npcApproach(siteId, ground) + Offset(0, siteId == 'roots' ? 0 : 50);

  static Offset roadApproach(String siteId, Offset ground) => siteId == 'roots'
      ? ground + const Offset(0, 130)
      : npcPosition(siteId, ground);

  // One continuous walkable forecourt and stair opening; cliff faces prevent
  // falling while the common aerial traversal can cross their safe endpoints.
  static const chapelTerrace = LandmarkTerrace(
    [
      Offset(159, 947),
      Offset(374, 1011),
      Offset(439, 874),
      Offset(904, 949),
      Offset(904, 854),
      Offset(534, 754),
      Offset(369, 799),
      Offset(334, 839),
    ],
    0,
    faces: [
      [
        Offset(474, 854),
        Offset(904, 949),
        Offset(1074, 954),
        Offset(1064, 1079),
        Offset(774, 1154),
        Offset(654, 1109),
        Offset(604, 1054),
        Offset(404, 1004),
      ],
    ],
  );

  static List<Offset> chapelSteps(Offset ground) => [
    ground + const Offset(0, 130),
    for (final pixel in const [
      Offset(554, 1164),
      Offset(254, 1044),
      Offset(266.5, 979),
      Offset(386.5, 856.5),
      Offset(504, 819),
    ])
      artPoint('roots', ground, pixel),
  ];

  static Iterable<List<Offset>> ledges(String siteId, Offset ground) sync* {
    if (siteId != 'roots') return;
    for (final polygon in chapelTerrace.ledges) {
      yield [for (final p in polygon) artPoint(siteId, ground, p)];
    }
  }

  static List<Offset> terraceOutline(Offset ground) => [
    for (final p in chapelTerrace.outline) artPoint('roots', ground, p),
  ];

  static double depth(String siteId, Offset ground) => siteId == 'roots'
      ? terraceOutline(ground).map((p) => p.dy).reduce((a, b) => a < b ? a : b)
      : ground.dy;

  static Rect drawBounds(String siteId, Offset ground, {double? width}) {
    final frame = _frame(siteId);
    final scale = (width ?? frame.width) / frame.size.width;
    return Rect.fromLTWH(
      ground.dx - frame.ground.dx * scale,
      ground.dy - frame.ground.dy * scale,
      frame.size.width * scale,
      frame.size.height * scale,
    );
  }

  /// Caller may expand this approach with the actual NPC body clearance.
  static Offset npcApproach(String siteId, Offset ground, {double? width}) {
    final frame = _frame(siteId);
    final scale = (width ?? frame.width) / frame.size.width;
    return ground + (frame.approach - frame.ground) * scale;
  }

  static List<Offset> solidFootprint(
    String siteId,
    Offset ground, {
    double? width,
  }) {
    final frame = _frame(siteId);
    final scale = (width ?? frame.width) / frame.size.width;
    return [
      for (final point in frame.solid) ground + (point - frame.ground) * scale,
    ];
  }

  static void draw(
    Canvas canvas,
    Image image,
    String siteId,
    Offset ground, {
    double? width,
  }) {
    final frame = _frame(siteId);
    canvas.drawImageRect(
      image,
      Offset.zero & frame.size,
      drawBounds(siteId, ground, width: width),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

class _QuestStructureFrame {
  const _QuestStructureFrame(
    this.key,
    this.size,
    this.ground,
    this.approach,
    this.width,
    this.solid,
  );
  final String key;
  final Size size;
  final Offset ground, approach;
  final double width;
  final List<Offset> solid;
}

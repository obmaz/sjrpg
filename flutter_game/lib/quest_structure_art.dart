import 'dart:ui';

/// Foot geometry is measured from the generated independent alpha silhouettes.
/// The apron and NPC approach stay separate from the solid building footprint.
abstract final class ForestQuestStructureArt {
  static _QuestStructureFrame _frame(String siteId) => switch (siteId) {
    'roots' => const _QuestStructureFrame(
      'forest-quest-chapel',
      Size(655, 656),
      Offset(323, 536),
      Offset(253, 568),
      260,
      [Offset(163, 450), Offset(326, 516), Offset(491, 442), Offset(320, 376)],
    ),
    'moon' => const _QuestStructureFrame(
      'forest-quest-cottage',
      Size(697, 626),
      Offset(339, 497),
      Offset(198, 527),
      260,
      [Offset(108, 428), Offset(352, 528), Offset(577, 443), Offset(322, 346)],
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

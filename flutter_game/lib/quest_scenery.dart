import 'dart:ui' as ui;

import 'world_model.dart';

/// A large, flat landscape around a real quest site, never a collision object.
/// Trails blend through its organic alpha edges; bridges and props stay above.
class QuestGroundPatch {
  const QuestGroundPatch({
    required this.siteId,
    required this.center,
    required this.size,
    required this.cell,
    this.mirrored = false,
  });
  final String siteId;
  final ui.Offset center;
  final ui.Size size;
  final int cell;
  final bool mirrored;
  ui.Rect get bounds => ui.Rect.fromCenter(
    center: center,
    width: size.width,
    height: size.height,
  );
}

class QuestScenery {
  QuestScenery(AdventureWorld world)
    : patches = List<QuestGroundPatch>.unmodifiable([
        for (final (index, site) in world.sites.indexed)
          QuestGroundPatch(
            siteId: site.id,
            center: site.at,
            size: ui.Size(840 + index % 3 * 70, 820 + (index + 1) % 3 * 60),
            cell: _cell(world.stage, index),
            mirrored: index.isOdd,
          ),
      ]);
  final List<QuestGroundPatch> patches;

  static int _cell(WorldStage stage, int index) => switch (stage) {
    WorldStage.forest => index % 3,
    WorldStage.sands => 3,
    WorldStage.past => const [4, 2, 4][index % 3],
    WorldStage.future || WorldStage.foundry => 5,
    WorldStage.tombs => 4,
    WorldStage.convergence => const [0, 1, 4][index % 3],
  };

  void paint(ui.Canvas canvas, ui.Image atlas, ui.Rect view) {
    final cellWidth = atlas.width / 3, cellHeight = atlas.height / 2;
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    for (final patch in patches) {
      if (!patch.bounds.overlaps(view)) continue;
      final source = ui.Rect.fromLTWH(
        patch.cell % 3 * cellWidth + .5,
        patch.cell ~/ 3 * cellHeight + .5,
        cellWidth - 1,
        cellHeight - 1,
      );
      canvas.save();
      canvas.translate(patch.center.dx, patch.center.dy);
      if (patch.mirrored) canvas.scale(-1, 1);
      canvas.drawImageRect(
        atlas,
        source,
        ui.Rect.fromCenter(
          center: ui.Offset.zero,
          width: patch.size.width,
          height: patch.size.height,
        ),
        paint,
      );
      canvas.restore();
    }
  }
}

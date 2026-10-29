import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'authored_settlement.dart';
import 'game_art.dart';
import 'world_model.dart';

/// Generated gateway anchored to the existing southern wall opening.
/// The measured clear passage (source x=556..978) spans the collision gap.
class VillageGate extends GameComponent {
  VillageGate(this.art, AdventureWorld world) {
    final settlement = world.authoredSettlement;
    final scale = AuthoredSettlement.extent * .15 / 422;
    final anchor = settlement.point(const ui.Offset(.505, .85));
    position = Vector2(
      anchor.dx - (767 - 20) * scale,
      anchor.dy - (664 - 8) * scale,
    );
    size = Vector2(1497 * scale, 662 * scale);
    _depth = anchor.dy.floor();
  }
  final GameArt art;
  late final int _depth;
  @override
  int get priority => _depth;
  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final image = art.images['village-gateway'];
    if (image == null) return;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, size.x, size.y),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }
}

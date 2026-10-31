import 'dart:ui' as ui;
import 'package:bonfire/bonfire.dart';
import 'game_art.dart';
import 'village_gateway_art.dart';
import 'world_model.dart';

/// Generated quarter-view piers share their ground contacts with world collision.
class VillageGate extends GameComponent {
  VillageGate(this.art, AdventureWorld world, {this.right = false}) {
    final village = world.authoredSettlement,
        bounds = VillageGatewayArt.bounds(village);
    position = Vector2(bounds.left, bounds.top);
    size = Vector2(bounds.width, bounds.height);
    _depth = VillageGatewayArt.point(
      village,
      right ? const ui.Offset(1164, 1094) : const ui.Offset(454, 1204),
    ).dy.floor();
  }
  final GameArt art;
  final bool right;
  late final int _depth;
  @override
  int get priority => LayerPriority.getComponentPriority(
    _depth + (hasGameRef ? gameRef.map.renderPriorityOffsetY : 0).floor(),
  );
  @override
  void render(ui.Canvas canvas) {
    final image = art.images['village-gateway'];
    if (image == null) return;
    canvas.save();
    final split = VillageGatewayArt.ground.dx * VillageGatewayArt.scale;
    canvas.clipRect(
      ui.Rect.fromLTRB(right ? split : 0, 0, right ? size.x : split, size.y),
      doAntiAlias: false,
    );
    canvas.drawImageRect(
      image,
      ui.Offset.zero & VillageGatewayArt.nativeSize,
      ui.Rect.fromLTWH(0, 0, size.x, size.y),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    canvas.restore();
  }
}

import 'dart:ui' as ui;
import 'package:bonfire/bonfire.dart';
import 'adventure.dart';
import 'bridge_art.dart';
import 'effect_visibility.dart';

/// Each side section sorts at its actual ground contact, below the raised deck.
class BridgeRail extends GameComponent with EffectVisibility {
  BridgeRail(this.session, this.bridge, this.strip, {required this.front}) {
    final bounds = QuarterViewBridgeArt.railBounds(bridge, strip, front: front);
    position = Vector2(bounds.left, bounds.top);
    size = Vector2(bounds.width, bounds.height);
  }
  final Adventure session;
  final ui.Rect bridge;
  final int strip;
  final bool front;
  @override
  ui.Rect get effectBounds => position.toOffset() & ui.Size(size.x, size.y);
  @override
  int get priority => LayerPriority.getComponentPriority(
    (QuarterViewBridgeArt.railDepth(
              bridge,
              (strip + .5) * QuarterViewBridgeArt.stripWidth,
              front: front,
            ) +
            (hasGameRef ? gameRef.map.renderPriorityOffsetY : 0))
        .floor(),
  );
  @override
  void render(ui.Canvas canvas) {
    final image = session.art.images['landscape-bridge'];
    if (image == null || session.disposed) return;
    canvas.save();
    canvas.translate(-position.x, -position.y);
    QuarterViewBridgeArt.drawRail(canvas, image, bridge, strip, front: front);
    canvas.restore();
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'game_art.dart';
import 'quest_marker.dart';

/// A named person uses the same quarter-view villagers as the existing town.
/// The caller owns quest state and physics; tapping the whole figure talks.
class ForestQuestNpc extends GameComponent with TapGesture {
  ForestQuestNpc({
    required this.art,
    required this.name,
    required this.at,
    required this.heroAt,
    required this.onInteract,
    required this.enabled,
    required this.markerVisible,
    required this.color,
    this.actor = 'villager',
    this.healthRatio,
    this.flash,
  }) {
    position = Vector2(at.dx - 30, at.dy - 110);
    size = Vector2(60, 125);
  }
  final GameArt art;
  final String name, actor;
  final ui.Offset at;
  final ui.Offset Function() heroAt;
  final void Function() onInteract;
  final bool Function() enabled, markerVisible;
  final ui.Color color;
  final double? Function()? healthRatio;
  final double Function()? flash;
  @override
  int get priority => LayerPriority.getComponentPriority(
    (at.dy + (hasGameRef ? gameRef.map.renderPriorityOffsetY : 0)).floor(),
  );
  @override
  bool onTapDown(GestureEvent event) => enabled();
  @override
  void onTap() {
    if (enabled()) onInteract();
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    const feet = ui.Offset(30, 110);
    final delta = heroAt() - at;
    canvas.drawOval(
      const ui.Rect.fromLTWH(13, 104, 34, 12),
      ui.Paint()..color = const ui.Color(0x66071916),
    );
    if (art.images.containsKey('actors-villagers')) {
      art.actor(
        canvas,
        actor,
        feet,
        math.atan2(delta.dy, delta.dx),
        0,
        72,
        flash: flash?.call() ?? 0,
      );
    }
    art.text(
      canvas,
      name,
      const ui.Offset(30, -4),
      size: 11,
      color: const ui.Color(0xffffefd2),
      centered: true,
    );
    if (markerVisible()) {
      paintQuestMarker(canvas, const ui.Offset(30, 19), color: color);
    }
    final ratio = healthRatio?.call();
    if (ratio != null) {
      const bar = ui.Rect.fromLTWH(7, 39, 46, 5);
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(bar.inflate(1), const ui.Radius.circular(2)),
        ui.Paint()..color = const ui.Color(0xff142521),
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(
          bar.left,
          bar.top,
          bar.width * ratio.clamp(0, 1),
          bar.height,
        ),
        ui.Paint()..color = const ui.Color(0xffe85c4d),
      );
    }
  }
}

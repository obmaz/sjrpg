import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

/// The head and torso remain readable while surrounding effects keep their
/// original brightness. This is a small clip, not an offscreen opacity layer.
ui.RRect heroReadabilityCore(ui.Rect footprint) => ui.RRect.fromRectAndRadius(
  ui.Rect.fromCenter(
    center: footprint.bottomCenter - const ui.Offset(0, 36),
    width: 32,
    height: 42,
  ),
  const ui.Radius.circular(14),
);

/// Skip only drawing: offscreen projectiles still move, collide and expire.
mixin EffectVisibility on GameComponent {
  ui.Rect get effectBounds;

  /// World-space body of an actor underneath a foreground spell, if any.
  /// Ground effects and hostile telegraphs retain their normal rendering.
  ui.Rect? get protectedActorBody => null;

  /// Optional base-render bookkeeping, without the component's drawing/children.
  void renderCulled(ui.Canvas canvas) {}

  @override
  void renderTree(ui.Canvas canvas) {
    if (hasGameRef) {
      final viewport = gameRef.camera.visibleWorldRect;
      if (viewport.isFinite &&
          !viewport.isEmpty &&
          !viewport.overlaps(effectBounds)) {
        renderCulled(canvas);
        return;
      }
    }
    final protected = protectedActorBody;
    if (protected == null || !protected.isFinite || protected.isEmpty) {
      super.renderTree(canvas);
      return;
    }
    final core = heroReadabilityCore(protected);
    if (!effectBounds.overlaps(core.outerRect)) {
      super.renderTree(canvas);
      return;
    }
    canvas.save();
    try {
      canvas.clipPath(
        ui.Path()
          ..fillType = ui.PathFillType.evenOdd
          ..addRect(canvas.getLocalClipBounds())
          ..addRRect(core),
      );
      super.renderTree(canvas);
    } finally {
      canvas.restore();
    }
  }
}

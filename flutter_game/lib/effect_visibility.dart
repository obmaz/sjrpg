import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

/// Skip only drawing: offscreen projectiles still move, collide and expire.
mixin EffectVisibility on GameComponent {
  ui.Rect get effectBounds;

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
    super.renderTree(canvas);
  }
}

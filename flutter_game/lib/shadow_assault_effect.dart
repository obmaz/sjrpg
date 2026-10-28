import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'effect_visibility.dart';

/// A short copy of the actual warrior pose. It never owns hits or movement.
class ShadowAssaultEcho extends GameComponent with EffectVisibility {
  ShadowAssaultEcho(
    this.session,
    ui.Offset feet, {
    required this.bearing,
    required this.pose,
    required this.duration,
  }) : remaining = duration,
       revision = session.buildRevision {
    position = Vector2(feet.dx, feet.dy);
  }
  final Adventure session;
  final double bearing, duration;
  final int pose, revision;
  double remaining;
  @override
  int get priority => position.y.floor() - 1;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromLTWH(position.x - 60, position.y - 120, 120, 140);
  @override
  void update(double dt) {
    if (revision != session.buildRevision || session.disposed) {
      removeFromParent();
      return;
    }
    if (!session.active || dt <= 0) return;
    remaining -= dt;
    if (remaining <= 0) removeFromParent();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (remaining <= 0) return;
    session.art.actor(
      canvas,
      'hero',
      ui.Offset.zero,
      bearing,
      pose,
      60,
      attack: true,
      comboPose: pose,
      actionProgress: 1 - remaining / duration,
      opacity: .26 * (remaining / duration).clamp(0.0, 1.0),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'effect_visibility.dart';

/// The forge is a physical WorldProp; this component supplies its craftsman.
class BlacksmithWorkshop extends GameComponent with EffectVisibility {
  BlacksmithWorkshop(this.session) {
    final at = session.world.blacksmithAt;
    position = Vector2(at.dx - 14, at.dy - 12);
    size = Vector2(28, 24);
  }
  final Adventure session;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromLTWH(position.x - 35, position.y - 75, 98, 112);
  @override
  bool get isVisible => true;
  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final toward = session.hero.body.center - session.world.blacksmithAt;
    session.art.actor(
      canvas,
      'merchant',
      const ui.Offset(14, 24),
      math.atan2(toward.dy, toward.dx),
      0,
      68,
    );
    // A small hammer marks the craftsman without another floating text label.
    final paint = ui.Paint()
      ..color = const ui.Color(0xfff5d88f)
      ..strokeWidth = 3
      ..strokeCap = ui.StrokeCap.round;
    canvas.drawLine(const ui.Offset(8, -40), const ui.Offset(20, -55), paint);
    canvas.drawLine(
      const ui.Offset(12, -58),
      const ui.Offset(24, -48),
      paint..strokeWidth = 6,
    );
  }
}

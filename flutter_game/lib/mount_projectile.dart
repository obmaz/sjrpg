import 'dart:math' as math;
import 'dart:ui' as ui;

import 'battle_effects.dart';

/// A mechanical tracer shares the engine projectile's swept collision and
/// single target judgement, without reusing a wizard's spell-orb silhouette.
class MountedGunBolt extends ArcaneBolt {
  MountedGunBolt(
    super.session,
    super.at,
    super.angle,
    super.damage, {
    required super.rank,
    super.propOnly = false,
  }) : super(element: 'lightning', targetLimit: 1, maxRange: 520);
  @override
  void render(ui.Canvas canvas) {
    if (resolved) return;
    canvas.save();
    canvas.translate(0, -14);
    canvas.rotate(math.atan2(direction.dy, direction.dx));
    final line = ui.Paint()
      ..strokeCap = ui.StrokeCap.round
      ..strokeWidth = 4
      ..color = const ui.Color(0x55ffb654);
    canvas.drawLine(const ui.Offset(-23, 0), const ui.Offset(3, 0), line);
    canvas.drawLine(
      const ui.Offset(-14, 0),
      const ui.Offset(5, 0),
      line
        ..strokeWidth = 1.5
        ..color = const ui.Color(0xffffe2a0),
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(-4, -2, 10, 4),
        const ui.Radius.circular(2),
      ),
      ui.Paint()..color = const ui.Color(0xffe5c586),
    );
    canvas.restore();
  }
}

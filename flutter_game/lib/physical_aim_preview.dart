import 'dart:math' as math;
import 'dart:ui';

import 'skill_aim.dart';

/// Physical skills aim from the body, rather than at a remote circular area.
void paintPhysicalAimPreview(
  Canvas canvas,
  Offset origin,
  SkillAim aim, {
  double? bearing,
}) {
  final angle = bearing ?? aim.angle;
  final color = aim.cancelled
      ? const Color(0xffff817e)
      : const Color(0xff9deee4);
  final line = Paint()
    ..color = color.withValues(alpha: .85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  if (aim.id == 'crushingBlow') {
    final cone = Path()
      ..moveTo(origin.dx, origin.dy)
      ..arcTo(
        Rect.fromCircle(center: origin, radius: crushingBlowRange),
        angle - crushingBlowHalfAngle,
        crushingBlowHalfAngle * 2,
        false,
      )
      ..close();
    canvas.drawPath(cone, Paint()..color = color.withValues(alpha: .10));
    canvas.drawPath(cone, line);
    return;
  }
  // A short arrow communicates direction only: travel can stop on terrain or
  // after the skill's target cap, so this does not promise a landing position.
  final axis = Offset(math.cos(angle), math.sin(angle));
  final side = Offset(-axis.dy, axis.dx);
  final tip = origin + axis * 72;
  canvas.drawLine(origin, tip, line);
  canvas.drawPath(
    Path()
      ..moveTo((tip - axis * 12 + side * 7).dx, (tip - axis * 12 + side * 7).dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(
        (tip - axis * 12 - side * 7).dx,
        (tip - axis * 12 - side * 7).dy,
      ),
    line,
  );
}

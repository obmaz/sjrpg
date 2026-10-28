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

const barbarianDoubleThrowHalfSpread = .035;

bool isBarbarianPhysicalAim(String id) =>
    id == 'leap' || id == 'leapAttack' || id == 'doubleThrow';

/// Uses the controller's authoritative range and landing center. This guide
/// never promises a remote damage circle or a landing on blocked terrain.
void paintBarbarianAimPreview(
  Canvas canvas,
  Offset origin,
  SkillAim aim, {
  required double range,
  double? bearing,
  Offset? landing,
}) {
  if (!isBarbarianPhysicalAim(aim.id) || !range.isFinite || range <= 0) return;
  final angle = bearing ?? aim.angle;
  final valid = !aim.cancelled && (aim.id == 'doubleThrow' || landing != null);
  final color = valid ? const Color(0xffa8d8cf) : const Color(0xffff817e);
  final line = Paint()
    ..color = color.withValues(alpha: .85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  if (aim.id == 'doubleThrow') {
    for (final spread in [
      -barbarianDoubleThrowHalfSpread,
      barbarianDoubleThrowHalfSpread,
    ]) {
      final direction = Offset(
        math.cos(angle + spread),
        math.sin(angle + spread),
      );
      final tip = origin + direction * range;
      canvas.drawLine(origin + direction * 12, tip, line);
      final side = Offset(-direction.dy, direction.dx);
      canvas.drawPath(
        Path()
          ..moveTo(
            (tip - direction * 8 + side * 4).dx,
            (tip - direction * 8 + side * 4).dy,
          )
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(
            (tip - direction * 8 - side * 4).dx,
            (tip - direction * 8 - side * 4).dy,
          ),
        line,
      );
    }
    return;
  }
  final target =
      landing ??
      origin +
          Offset(math.cos(angle), math.sin(angle)) *
              math.min(range, aim.distance);
  final delta = target - origin, length = delta.distance;
  if (length > 1) {
    final direction = delta / length;
    // A restrained broken path remains visibly separate from a projectile.
    for (var distance = 12.0; distance < length - 16; distance += 14) {
      canvas.drawLine(
        origin + direction * distance,
        origin + direction * math.min(distance + 6, length - 16),
        line,
      );
    }
  }
  if (!valid) {
    canvas.drawLine(
      target - const Offset(7, 7),
      target + const Offset(7, 7),
      line,
    );
    canvas.drawLine(
      target + const Offset(7, -7),
      target + const Offset(-7, 7),
      line,
    );
    return;
  }
  final body = Rect.fromCenter(center: target, width: 28, height: 24);
  for (final corner in [
    body.topLeft,
    body.topRight,
    body.bottomLeft,
    body.bottomRight,
  ]) {
    final x = corner.dx < target.dx ? 1.0 : -1.0;
    final y = corner.dy < target.dy ? 1.0 : -1.0;
    canvas.drawLine(corner, corner + Offset(x * 7, 0), line);
    canvas.drawLine(corner, corner + Offset(0, y * 6), line);
  }
}

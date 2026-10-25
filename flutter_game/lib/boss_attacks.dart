import 'dart:math' as math;
import 'dart:ui' as ui;
import 'stage_content.dart';

enum BossDangerShape { circle, fan, beam }

class BossDanger {
  const BossDanger(
    this.shape,
    this.center, {
    this.radius = 0,
    this.angle = 0,
    this.halfAngle = 0,
    this.halfLength = 0,
    this.halfWidth = 0,
  });
  final BossDangerShape shape;
  final ui.Offset center;
  final double radius, angle, halfAngle, halfLength, halfWidth;
  bool contains(ui.Offset point) {
    final delta = point - center;
    if (shape == BossDangerShape.circle) return delta.distance <= radius;
    if (shape == BossDangerShape.fan) {
      if (delta.distance < .001) return true;
      final difference = math.atan2(
        math.sin(math.atan2(delta.dy, delta.dx) - angle),
        math.cos(math.atan2(delta.dy, delta.dx) - angle),
      );
      return delta.distance <= radius && difference.abs() <= halfAngle;
    }
    final along = delta.dx * math.cos(angle) + delta.dy * math.sin(angle);
    final across = -delta.dx * math.sin(angle) + delta.dy * math.cos(angle);
    return along.abs() <= halfLength && across.abs() <= halfWidth;
  }

  ui.Path get path {
    if (shape == BossDangerShape.circle) {
      return ui.Path()
        ..addOval(ui.Rect.fromCircle(center: center, radius: radius));
    }
    if (shape == BossDangerShape.fan) {
      return ui.Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          ui.Rect.fromCircle(center: center, radius: radius),
          angle - halfAngle,
          halfAngle * 2,
          false,
        )
        ..close();
    }
    final forward = ui.Offset(math.cos(angle), math.sin(angle)) * halfLength;
    final side = ui.Offset(-math.sin(angle), math.cos(angle)) * halfWidth;
    return ui.Path()..addPolygon([
      center - forward - side,
      center + forward - side,
      center + forward + side,
      center - forward + side,
    ], true);
  }
}

class BossAttack {
  BossAttack._(
    this.stage,
    this.origin,
    this.target,
    this.zones,
    this.warningTime,
    this.recovery,
    this.damage,
    this.color,
    this.enraged,
  );
  factory BossAttack.forStage(
    WorldStage stage,
    ui.Offset origin,
    ui.Offset target, {
    bool enraged = false,
  }) {
    final delta = target - origin, angle = math.atan2(delta.dy, delta.dx);
    final forward = ui.Offset(math.cos(angle), math.sin(angle)),
        side = ui.Offset(-forward.dy, forward.dx);
    final zones = <BossDanger>[];
    late double warning, recovery, damage;
    late ui.Color color;
    switch (stage) {
      case WorldStage.forest:
        zones.add(BossDanger(BossDangerShape.circle, target, radius: 105));
        warning = .85;
        recovery = 5.5;
        damage = 24;
        color = const ui.Color(0xffffad6b);
      case WorldStage.sands:
        for (final offset in [
          ui.Offset.zero,
          forward * 90,
          forward * -90,
          if (enraged) side * 90,
          if (enraged) side * -90,
        ]) {
          zones.add(
            BossDanger(
              BossDangerShape.circle,
              target + offset,
              radius: enraged ? 55 : 60,
            ),
          );
        }
        warning = .95;
        recovery = enraged ? 4.8 : 5.8;
        damage = 22;
        color = const ui.Color(0xffffd176);
      case WorldStage.past:
        zones.add(
          BossDanger(
            BossDangerShape.fan,
            origin,
            radius: enraged ? 280 : 260,
            angle: angle,
            halfAngle: enraged ? 1.05 : .8,
          ),
        );
        warning = 1.05;
        recovery = enraged ? 5 : 6.2;
        damage = 26;
        color = const ui.Color(0xffffdf87);
      case WorldStage.future:
        for (final bearing in [
          0.0,
          math.pi / 2,
          if (enraged) math.pi / 4,
          if (enraged) math.pi * 3 / 4,
        ]) {
          zones.add(
            BossDanger(
              BossDangerShape.beam,
              target,
              angle: bearing,
              halfLength: 180,
              halfWidth: enraged ? 15 : 20,
            ),
          );
        }
        warning = 1;
        recovery = enraged ? 4.4 : 5.5;
        damage = 24;
        color = const ui.Color(0xff7feafa);
    }
    return BossAttack._(
      stage,
      origin,
      target,
      List.unmodifiable(zones),
      warning,
      recovery,
      damage,
      color,
      enraged,
    );
  }
  final WorldStage stage;
  final ui.Offset origin, target;
  final List<BossDanger> zones;
  final double warningTime, recovery, damage;
  final ui.Color color;
  final bool enraged;
  void paintWarning(ui.Canvas canvas, double progress) {
    final t = progress.clamp(0.0, 1.0);
    for (final zone in zones) {
      canvas.drawPath(
        zone.path,
        ui.Paint()..color = color.withValues(alpha: .1 + t * .14),
      );
      canvas.drawPath(
        zone.path,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const ui.Color(0xffef8c78),
      );
      if (zone.shape == BossDangerShape.circle) {
        canvas.drawArc(
          ui.Rect.fromCircle(center: zone.center, radius: zone.radius),
          -math.pi / 2,
          math.pi * 2 * t,
          false,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = color,
        );
      } else if (zone.shape == BossDangerShape.beam) {
        final delta =
            ui.Offset(math.cos(zone.angle), math.sin(zone.angle)) *
            zone.halfLength *
            t;
        canvas.drawLine(
          zone.center - delta,
          zone.center + delta,
          ui.Paint()
            ..strokeWidth = 2 + t * 2
            ..color = color,
        );
      } else {
        for (var i = 0; i < 5; i++) {
          final angle =
              zone.angle - zone.halfAngle + zone.halfAngle * 2 * i / 4;
          canvas.drawLine(
            zone.center,
            zone.center +
                ui.Offset(math.cos(angle), math.sin(angle)) * zone.radius * t,
            ui.Paint()
              ..strokeWidth = 1.5
              ..color = color.withValues(alpha: .45),
          );
        }
      }
    }
  }

  void paintImpact(ui.Canvas canvas, double progress) {
    final t = progress.clamp(0.0, 1.0), fade = 1 - t;
    for (final zone in zones) {
      canvas.drawPath(
        zone.path,
        ui.Paint()..color = color.withValues(alpha: .25 * fade),
      );
      if (zone.shape == BossDangerShape.circle) {
        canvas.drawCircle(
          zone.center,
          zone.radius * (.55 + t * .55),
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 8 * fade + 1
            ..color = color.withValues(alpha: fade),
        );
        for (var i = 0; i < 10; i++) {
          final angle = i * math.pi / 5;
          final point =
              zone.center +
              ui.Offset(math.cos(angle), math.sin(angle)) * zone.radius * t;
          canvas.drawCircle(
            point,
            4 * fade + 1,
            ui.Paint()..color = color.withValues(alpha: fade),
          );
        }
      } else if (zone.shape == BossDangerShape.fan) {
        for (var i = 0; i < 9; i++) {
          final angle =
              zone.angle - zone.halfAngle + zone.halfAngle * 2 * i / 8;
          final direction = ui.Offset(math.cos(angle), math.sin(angle));
          canvas.drawLine(
            zone.center + direction * zone.radius * t,
            zone.center + direction * zone.radius * math.min(1, t + .3),
            ui.Paint()
              ..strokeWidth = 7 * fade + 1
              ..strokeCap = ui.StrokeCap.round
              ..color = color.withValues(alpha: fade),
          );
        }
      } else {
        final forward = ui.Offset(math.cos(zone.angle), math.sin(zone.angle)),
            side = ui.Offset(-forward.dy, forward.dx);
        final pulse = .75 + .25 * math.sin(t * 45);
        canvas.drawLine(
          zone.center - forward * zone.halfLength,
          zone.center + forward * zone.halfLength,
          ui.Paint()
            ..strokeWidth = zone.halfWidth * 2 * fade * pulse
            ..color = color.withValues(alpha: fade * .5),
        );
        final path = ui.Path();
        for (var i = 0; i <= 12; i++) {
          final point =
              zone.center +
              forward * zone.halfLength * (i / 6 - 1) +
              side * math.sin(i * 2.8 + t * 30) * 10 * fade;
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(
          path,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2 + 3 * fade
            ..color = const ui.Color(0xffefffff).withValues(alpha: fade),
        );
      }
    }
  }
}

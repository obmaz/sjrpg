import 'dart:math' as math;
import 'dart:ui' as ui;

import 'player_afflictions.dart';
import 'stage_content.dart';

enum BossPower { impact, root, dispel, freeze, attackSlow, moveSlow }

extension BossPowerInfo on BossPower {
  PlayerStatus? get status => switch (this) {
    BossPower.root => PlayerStatus.root,
    BossPower.freeze => PlayerStatus.freeze,
    BossPower.attackSlow => PlayerStatus.attackSlow,
    BossPower.moveSlow => PlayerStatus.moveSlow,
    _ => null,
  };
  String get label => switch (this) {
    BossPower.impact => '강타',
    BossPower.root => '구속 그물',
    BossPower.dispel => '강화 해제',
    BossPower.freeze => '빙결 파동',
    BossPower.attackSlow => '쇠약의 칼날',
    BossPower.moveSlow => '무거운 발걸음',
  };
}

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
    this.enraged, [
    this.power = BossPower.impact,
  ]);
  factory BossAttack.forStage(
    WorldStage stage,
    ui.Offset origin,
    ui.Offset target, {
    bool enraged = false,
    int sequence = 0,
  }) {
    final power = BossPower.values[sequence % BossPower.values.length];
    if (power != BossPower.impact) {
      return BossAttack._control(stage, origin, target, power, enraged);
    }
    final delta = target - origin, angle = math.atan2(delta.dy, delta.dx);
    final forward = ui.Offset(math.cos(angle), math.sin(angle)),
        side = ui.Offset(-forward.dy, forward.dx);
    final zones = <BossDanger>[];
    late double warning, recovery, damage;
    late ui.Color color;
    switch (stage) {
      case WorldStage.forest:
      case WorldStage.convergence:
        zones.add(BossDanger(BossDangerShape.circle, target, radius: 105));
        if (stage == WorldStage.convergence) {
          zones.addAll([
            BossDanger(BossDangerShape.circle, target + side * 150, radius: 70),
            BossDanger(BossDangerShape.circle, target - side * 150, radius: 70),
            if (enraged)
              BossDanger(
                BossDangerShape.fan,
                origin,
                radius: 230,
                angle: angle,
                halfAngle: .7,
              ),
          ]);
        }
        warning = stage == WorldStage.convergence ? 1.1 : .85;
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
      case WorldStage.tombs:
        zones.add(
          BossDanger(
            BossDangerShape.fan,
            origin,
            radius: enraged ? 280 : 260,
            angle: angle,
            halfAngle: enraged ? 1.05 : .8,
          ),
        );
        if (stage == WorldStage.tombs) {
          zones.add(
            BossDanger(
              BossDangerShape.circle,
              target + forward * 110,
              radius: enraged ? 100 : 75,
            ),
          );
        }
        warning = stage == WorldStage.tombs ? 1.15 : 1.05;
        recovery = enraged ? 5 : 6.2;
        damage = 26;
        color = const ui.Color(0xffffdf87);
      case WorldStage.future:
      case WorldStage.foundry:
        for (final bearing in [
          if (stage == WorldStage.foundry) ...[
            angle,
            angle + math.pi / 3,
            angle - math.pi / 3,
          ] else ...[
            0.0,
            math.pi / 2,
          ],
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
  static BossAttack _control(
    WorldStage stage,
    ui.Offset origin,
    ui.Offset target,
    BossPower power,
    bool enraged,
  ) {
    final delta = target - origin, angle = math.atan2(delta.dy, delta.dx);
    final side = ui.Offset(-math.sin(angle), math.cos(angle));
    final zones = <BossDanger>[];
    switch (power) {
      case BossPower.root:
        zones.add(BossDanger(BossDangerShape.circle, target, radius: 85));
        if (stage == WorldStage.sands || enraged) {
          for (final sign in [-1, 1]) {
            zones.add(
              BossDanger(
                BossDangerShape.circle,
                target + side * (130.0 * sign),
                radius: 52,
              ),
            );
          }
        }
      case BossPower.freeze:
        zones.add(
          BossDanger(
            BossDangerShape.beam,
            target,
            angle: angle,
            halfLength: 150,
            halfWidth: 25,
          ),
        );
        if (stage.usesCityArt && enraged) {
          zones.add(
            BossDanger(
              BossDangerShape.beam,
              target,
              angle: angle + math.pi / 2,
              halfLength: 150,
              halfWidth: 20,
            ),
          );
        }
      case BossPower.dispel:
        zones.add(BossDanger(BossDangerShape.circle, target, radius: 115));
      case BossPower.attackSlow:
        zones.add(
          BossDanger(
            BossDangerShape.fan,
            origin,
            radius: 630,
            angle: angle,
            halfAngle: enraged ? .37 : .28,
          ),
        );
      case BossPower.moveSlow:
        for (final bearing in [angle - .65, angle + .65]) {
          zones.add(
            BossDanger(
              BossDangerShape.beam,
              target,
              angle: bearing,
              halfLength: 155,
              halfWidth: 18,
            ),
          );
        }
      case BossPower.impact:
        throw StateError('The basic strike has its own stage pattern');
    }
    final warning = switch (power) {
      BossPower.freeze => 1.15,
      BossPower.dispel => 1.2,
      _ => 1.05,
    };
    final recovery = switch (power) {
      BossPower.dispel => 5.2,
      BossPower.freeze || BossPower.attackSlow => 5.0,
      _ => 4.6,
    };
    final tint = switch (stage.visualStage) {
      WorldStage.forest => const ui.Color(0xff9edb85),
      WorldStage.sands => const ui.Color(0xffe8bd7e),
      WorldStage.past => const ui.Color(0xffd7c0f0),
      _ => const ui.Color(0xff7feafa),
    };
    final color = switch (power) {
      BossPower.freeze => const ui.Color(0xffa2dfff),
      BossPower.dispel => const ui.Color(0xffef92d8),
      BossPower.attackSlow => const ui.Color(0xffc9a4ff),
      BossPower.moveSlow => const ui.Color(0xffe3bb74),
      _ => tint,
    };
    return BossAttack._(
      stage,
      origin,
      target,
      List.unmodifiable(zones),
      warning,
      recovery * (enraged ? .9 : 1),
      power == BossPower.dispel || power == BossPower.moveSlow ? 20 : 18,
      color,
      enraged,
      power,
    );
  }

  final BossPower power;
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
    if (power != BossPower.impact) _paintSymbol(canvas, target, .8 + .2 * t);
  }

  void _paintSymbol(
    ui.Canvas canvas,
    ui.Offset at,
    double scale, {
    double opacity = 1,
  }) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(scale);
    final stroke = ui.Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.5;
    switch (power) {
      case BossPower.root:
        for (var i = -2; i <= 2; i++) {
          canvas.drawLine(ui.Offset(i * 6, -17), ui.Offset(i * 6, 17), stroke);
          canvas.drawLine(ui.Offset(-17, i * 6), ui.Offset(17, i * 6), stroke);
        }
      case BossPower.freeze:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3, d = ui.Offset(math.cos(a), math.sin(a));
          canvas.drawLine(ui.Offset.zero, d * 22, stroke);
          for (final sign in [-1, 1]) {
            canvas.drawLine(
              d * 13,
              d * 18 + ui.Offset(-d.dy, d.dx) * (sign * 6),
              stroke,
            );
          }
        }
      case BossPower.dispel:
        canvas.drawArc(
          ui.Rect.fromCircle(center: ui.Offset.zero, radius: 20),
          .3,
          math.pi - .6,
          false,
          stroke,
        );
        canvas.drawArc(
          ui.Rect.fromCircle(center: ui.Offset.zero, radius: 20),
          math.pi + .3,
          math.pi - .6,
          false,
          stroke,
        );
        canvas.drawLine(
          const ui.Offset(-18, 18),
          const ui.Offset(18, -18),
          stroke,
        );
      case BossPower.attackSlow:
        canvas.drawCircle(ui.Offset.zero, 20, stroke);
        canvas.drawLine(const ui.Offset(0, -13), ui.Offset.zero, stroke);
        canvas.drawLine(ui.Offset.zero, const ui.Offset(11, 7), stroke);
      case BossPower.moveSlow:
        for (final y in [-8.0, 5.0]) {
          canvas.drawPath(
            ui.Path()
              ..moveTo(-14, y)
              ..lineTo(0, y + 11)
              ..lineTo(14, y),
            stroke,
          );
        }
      case BossPower.impact:
        break;
    }
    canvas.restore();
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
    if (power != BossPower.impact && t < .9) {
      _paintSymbol(
        canvas,
        target,
        power == BossPower.root ? 1 - t * .6 : 1 + t,
        opacity: fade,
      );
    }
  }
}

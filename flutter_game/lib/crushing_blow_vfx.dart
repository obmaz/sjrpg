import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'effect_visibility.dart';
import 'game_art.dart';
import 'skill_growth.dart';

/// A physical strike: the blade lands first, then the ground and debris respond.
/// Paths and brushes belong to the cast; the effect never applies damage.
class CrushingBlowVisual extends GameComponent with EffectVisibility {
  CrushingBlowVisual(
    this.session,
    ui.Offset origin, {
    required this.rank,
    required this.charge,
    required this.bearing,
    required this.tempo,
  }) : revision = session.buildRevision,
       art = CrushingBlowArt(
         session.art,
         rank: rank,
         charge: charge,
         bearing: bearing,
       ) {
    position = Vector2(origin.dx, origin.dy);
    size = Vector2.all(1);
  }

  final Adventure session;
  final int rank, revision;
  final double charge, bearing, tempo;
  final CrushingBlowArt art;
  double age = 0;
  bool finished = false;
  static const duration = .58;

  @override
  int get priority => 29;
  @override
  bool get isVisible => true;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromCircle(center: position.toOffset(), radius: 250);

  @override
  void update(double dt) {
    if (session.disposed || revision != session.buildRevision) {
      finished = true;
      removeFromParent();
      return;
    }
    if (!session.active) return;
    age += math.min(.05, dt) * tempo;
    if (age >= duration) {
      finished = true;
      removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    if (!finished && !session.disposed && revision == session.buildRevision) {
      art.paint(canvas, age / duration);
    }
  }
}

/// The first two painted frames anticipate contact; remaining frames begin at
/// the exact damaging impact. The world anchor is measured during preparation.
void paintCrushingFrame(
  GameArt art,
  ui.Canvas canvas,
  ui.Offset impact,
  int frame, {
  required int rank,
  required double charge,
  required double bearing,
  double opacity = 1,
}) {
  final side =
      220.0 + SkillGrowth.level(rank) * 3 + charge.clamp(0.0, 1.0) * 12;
  // Bring the painted blade from the hero's side for west-facing strikes.
  // Flip only X around contact: flying stones still fall down the screen.
  final mirror = math.cos(bearing) < -.000001;
  if (mirror) {
    canvas.save();
    canvas.translate(impact.dx, impact.dy);
    canvas.scale(-1, 1);
  }
  final at = mirror ? ui.Offset.zero : impact;
  art.effects.draw(
    canvas,
    'fx-crushing-blow',
    frame,
    ui.Rect.fromLTWH(at.dx - side / 2, at.dy - side * 180 / 256, side, side),
    opacity: opacity * .3,
  );
  if (mirror) canvas.restore();
}

class CrushingBlowWindup extends GameComponent with EffectVisibility {
  CrushingBlowWindup(
    this.session,
    this.hero, {
    required this.rank,
    required this.charge,
    required this.bearing,
    required this.duration,
  }) : revision = session.buildRevision {
    position = Vector2(hero.body.center.dx, hero.body.center.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final Guardian hero;
  final int rank, revision;
  final double charge, bearing, duration;
  bool finished = false;
  @override
  int get priority => 29;
  @override
  bool get isVisible => true;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromCircle(center: hero.body.center, radius: 250);
  @override
  void update(double dt) {
    if (session.disposed ||
        revision != session.buildRevision ||
        hero.heavyWindup <= 0) {
      finished = true;
      removeFromParent();
      return;
    }
    if (!session.active) return;
    position.setValues(hero.body.center.dx, hero.body.center.dy);
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    if (finished ||
        session.disposed ||
        revision != session.buildRevision ||
        hero.heavyWindup <= 0) {
      return;
    }
    final progress = 1 - hero.heavyWindup / duration;
    if (progress < .6) return;
    final phase = ((progress - .6) / .4).clamp(0.0, .999999);
    final impact =
        hero.body.center -
        position.toOffset() +
        ui.Offset(math.cos(bearing), math.sin(bearing)) * 80;
    paintCrushingFrame(
      session.art,
      canvas,
      impact,
      (phase * 2).floor(),
      rank: rank,
      charge: charge,
      bearing: bearing,
      opacity: .3 + phase * .7,
    );
  }
}

class CrushingBlowArt {
  static const _edgeColors = [
    ui.Color(0xffbb843d),
    ui.Color(0xffffd889),
    ui.Color(0xfffffff0),
  ];
  CrushingBlowArt(
    this.gameArt, {
    required int rank,
    required double charge,
    required this.bearing,
  }) : rank = SkillGrowth.level(rank),
       charge = charge.clamp(0.0, 1.0) {
    final r = this.rank, power = this.charge;
    final count = 4 + SkillGrowth.tier(r);
    for (var i = 0; i < count; i++) {
      final angle = bearing - .85 + i / (count - 1) * 1.7;
      shards.add((
        velocity:
            ui.Offset(math.cos(angle), math.sin(angle)) *
            (30 + i % 4 * 12 + power * 14),
        height: 15.0 + i % 3 * 8 + power * 12,
        width: 2.2 + i % 3 * .7,
      ));
    }
  }

  final GameArt gameArt;
  final int rank;
  final double charge, bearing;
  late final impact = ui.Offset(math.cos(bearing), math.sin(bearing)) * 80;
  final shards = <({ui.Offset velocity, double height, double width})>[];
  static final _rockShapes = [
    ui.Path()
      ..moveTo(-.6, -.3)
      ..lineTo(-.2, -.9)
      ..lineTo(.5, -.5)
      ..lineTo(.7, .4)
      ..lineTo(-.3, .7)
      ..close(),
    ui.Path()
      ..moveTo(-.7, 0)
      ..lineTo(0, -.7)
      ..lineTo(.8, -.2)
      ..lineTo(.3, .6)
      ..lineTo(-.4, .5)
      ..close(),
  ];
  final _fill = ui.Paint();
  final _line = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;

  void paint(ui.Canvas canvas, double phase) {
    final t = phase.clamp(0.0, 1.0);
    if (t >= 1) return;
    final fade = 1 - t, power = .65 + charge * .35;
    // A travelling edge, not a static stamp: broad steel, gold edge, white core.
    final cut = (t / .48).clamp(0.0, 1.0);
    if (cut < 1) {
      final arc = ui.Rect.fromCircle(
        center: ui.Offset.zero,
        radius: 100 + rank * 3,
      );
      final start = bearing - 1.0 + cut * 1.7;
      for (var layer = 0; layer < 2; layer++) {
        canvas.drawArc(
          arc,
          start - .65,
          .7,
          false,
          _line
            ..strokeWidth = (layer == 0 ? 8 : 2) * (1 - cut) * power + 1
            ..color = _edgeColors[layer == 0 ? 0 : 2].withValues(
              alpha: (1 - cut) * .85,
            ),
        );
      }
    }
    // The impact is directional and remains in front of the hero's feet.
    canvas.save();
    canvas.translate(impact.dx, impact.dy);
    final spread = 13 + math.sqrt(t) * (45 + rank * 2 + charge * 10);
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: spread * 2,
        height: spread,
      ),
      _fill..color = const ui.Color(0xffa78555).withValues(alpha: fade * .18),
    );
    canvas.restore();
    for (var i = 0; i < shards.length; i++) {
      final shard = shards[i];
      final flight = (t * 1.3 - i % 3 * .025).clamp(0.0, 1.0);
      final at =
          impact +
          shard.velocity * flight -
          ui.Offset(0, math.sin(flight * math.pi) * shard.height);
      final ground = impact + shard.velocity * flight;
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: ground + const ui.Offset(0, 3),
          width: shard.width * 2.3,
          height: shard.width * .75,
        ),
        _fill..color = const ui.Color(0xff30291c).withValues(alpha: fade * .16),
      );
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(bearing + i * .9 + flight * (i.isEven ? 5 : -5));
      final width = shard.width;
      final stone = _rockShapes[i % _rockShapes.length];
      canvas.scale(width);
      canvas.drawPath(
        stone,
        _fill..color = const ui.Color(0xff5a4430).withValues(alpha: fade),
      );
      canvas.translate(0, -.2);
      canvas.scale(.72);
      canvas.drawPath(
        stone,
        _fill
          ..color =
              (i % 3 == 0 && rank >= 3
                      ? const ui.Color(0xffdfc48c)
                      : const ui.Color(0xffad8c60))
                  .withValues(alpha: fade),
      );
      canvas.restore();
    }
    if (t < .2) {
      final flash = 1 - t / .2;
      for (var i = 0; i < 3 + rank ~/ 2; i++) {
        final angle = bearing + i * 2.4;
        final direction = ui.Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          impact - direction * 5 * flash,
          impact + direction * (22 + charge * 13) * flash,
          _line
            ..strokeWidth = 2 * flash + .5
            ..color = const ui.Color(0xfffff6c9).withValues(alpha: flash),
        );
      }
    }
  }
}

/// Small converging flecks follow the raised weapon while the player charges.
class CrushingChargeArt {
  final _line = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;

  void paint(
    ui.Canvas canvas,
    ui.Offset center, {
    required double bearing,
    required double charge,
    required double time,
    required int rank,
  }) {
    final power = charge.clamp(0.0, 1.0), r = SkillGrowth.level(rank);
    final axis = ui.Offset(math.cos(bearing), math.sin(bearing));
    final tip = center + axis * (26 + power * 12) - const ui.Offset(0, 9);
    for (var i = 0; i < 4 + r; i++) {
      final phase = (time * 1.8 + i * .173) % 1;
      final angle = i * 2.39996;
      final direction = ui.Offset(math.cos(angle), math.sin(angle) * .6);
      final distance = (1 - phase) * (14 + power * 18);
      canvas.drawLine(
        tip + direction * distance,
        tip + direction * (distance + 3 + power * 4),
        _line
          ..strokeWidth = .9 + power * .8
          ..color = const ui.Color(
            0xffffe4aa,
          ).withValues(alpha: math.sin(phase * math.pi) * (.3 + power * .6)),
      );
    }
    canvas.drawArc(
      ui.Rect.fromCircle(center: tip, radius: 5 + power * 5),
      -math.pi / 2,
      math.pi * 2 * power,
      false,
      _line
        ..strokeWidth = 1.5
        ..color = const ui.Color(0xfffff3c9).withValues(alpha: .4 + power * .5),
    );
  }
}

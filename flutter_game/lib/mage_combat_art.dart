import 'dart:math' as math;
import 'dart:ui' as ui;

import 'fire_plume.dart';
import 'skill_growth.dart';

enum MageElement {
  fire,
  ice,
  lightning;

  static MageElement fromStyle(String style) => switch (style) {
    'ice' => ice,
    'lightning' => lightning,
    _ => fire,
  };

  ui.Color get color => switch (this) {
    fire => const ui.Color(0xffffa64c),
    ice => const ui.Color(0xff9eefff),
    lightning => const ui.Color(0xff69cfff),
  };
}

/// Continuous, bounded geometry shared by the small shots and large spells.
/// All clocks are supplied by simulation components; this painter never hits.
class MageCombatArt {
  static final _glows = {
    for (final element in MageElement.values)
      element: ui.Gradient.radial(
        ui.Offset.zero,
        1,
        [
          element.color.withValues(alpha: .6),
          element.color.withValues(alpha: .22),
          element.color.withValues(alpha: 0),
        ],
        [0, .32, 1],
      ),
  };
  final _paint = ui.Paint();
  final _path = ui.Path();
  final _flame = FirePlume();
  final _arc = ElectricArcArt();

  void _glow(ui.Canvas c, ui.Offset at, double radius, MageElement element) {
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(radius);
    _paint
      ..style = ui.PaintingStyle.fill
      ..color = const ui.Color(0xffffffff)
      ..shader = _glows[element];
    c.drawCircle(ui.Offset.zero, 1, _paint);
    _paint.shader = null;
    c.restore();
  }

  void _stroke(ui.Canvas c, ui.Path path, ui.Color color, double width) {
    _paint
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..strokeWidth = width
      ..color = color;
    c.drawPath(path, _paint);
  }

  void _fill(ui.Canvas c, ui.Path path, ui.Color color) {
    _paint
      ..style = ui.PaintingStyle.fill
      ..color = color;
    c.drawPath(path, _paint);
  }

  void charge(
    ui.Canvas c,
    ui.Offset at,
    MageElement element,
    double phase,
    int rank,
  ) {
    final t = phase.clamp(0.0, 1.0), r = SkillGrowth.level(rank);
    final radius = 5 + t * (8 + r);
    _glow(c, at, radius * 2.2, element);
    _paint.style = ui.PaintingStyle.fill;
    _paint.color = const ui.Color(0xfff1fbff).withValues(alpha: .3 + .6 * t);
    c.drawCircle(at, radius * .4, _paint);
    for (var i = 0; i < 3 + r; i++) {
      final a = i * 2.39996 + t * 1.8;
      final tip = at + ui.Offset(math.cos(a), math.sin(a)) * radius;
      final tail =
          at + ui.Offset(math.cos(a), math.sin(a)) * (radius + 12 * (1 - t));
      _path
        ..reset()
        ..moveTo(tail.dx, tail.dy)
        ..lineTo(tip.dx, tip.dy);
      _stroke(c, _path, element.color.withValues(alpha: .75), 1.5);
    }
  }

  void projectile(
    ui.Canvas c,
    ui.Offset at,
    double bearing,
    double time,
    MageElement element,
    int rank,
  ) {
    final r = SkillGrowth.level(rank);
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(bearing);
    final length = 54.0 + r * 7;
    if (element == MageElement.lightning) {
      _arc.paint(
        c,
        ui.Offset(-length, 0),
        const ui.Offset(12, 0),
        time,
        rank: r,
        opacity: 1,
        seed: 3,
        branches: 1 + r ~/ 2,
      );
      _paint
        ..style = ui.PaintingStyle.fill
        ..color = const ui.Color(0xffeffcff);
      _glow(c, const ui.Offset(9, 0), 15 + r.toDouble(), element);
      _paint.color = const ui.Color(0xffeffcff);
      c.drawOval(const ui.Rect.fromLTWH(3, -1.5, 10, 3), _paint);
    } else if (element == MageElement.fire) {
      _flame.flight(c, ui.Offset.zero, 0, time, radius: 35 + r * 2);
      for (var layer = 0; layer < 3; layer++) {
        final width = 10.0 - layer * 2.3;
        final wave = math.sin(time * 31 + layer * 1.6) * 5;
        _path
          ..reset()
          ..moveTo(4, -width)
          ..cubicTo(
            -length * .3,
            -width + wave,
            -length * .6,
            wave,
            -length,
            -wave,
          )
          ..cubicTo(-length * .6, wave + width, -length * .3, width, 4, width)
          ..close();
        _fill(
          c,
          _path,
          [
            const ui.Color(0xaae05020),
            const ui.Color(0xddffb23e),
            const ui.Color(0xffffedac),
          ][layer],
        );
      }
      _glow(c, const ui.Offset(3, 0), 22 + r * 1.5, element);
      _paint.color = const ui.Color(0xffffe29c);
      c.drawOval(
        ui.Rect.fromCenter(
          center: const ui.Offset(2, 0),
          width: 24 + r * 1.5,
          height: 19 + math.sin(time * 24) * 2,
        ),
        _paint,
      );
      _paint.color = const ui.Color(0xfffff8d4);
      c.drawOval(const ui.Rect.fromLTWH(-2, -5, 15, 10), _paint);
      for (var i = 0; i < 3 + r; i++) {
        final p = (time * 2.7 + i * .173) % 1;
        _paint.color = element.color.withValues(alpha: (1 - p) * .85);
        c.drawCircle(
          ui.Offset(
            -20 - p * length,
            math.sin(i * 2.1 + time * 24) * (4 + p * 12),
          ),
          1 + (1 - p) * 1.5,
          _paint,
        );
      }
    } else {
      // A faceted lance remains solid while its wake sheds independent shards.
      _glow(c, const ui.Offset(-1, 0), 22 + r.toDouble(), element);
      _path
        ..reset()
        ..moveTo(21, 0)
        ..lineTo(-8, -9 - r * .45)
        ..lineTo(-22, 0)
        ..lineTo(-8, 9 + r * .45)
        ..close();
      _fill(c, _path, const ui.Color(0xff4da2cc));
      _path
        ..reset()
        ..moveTo(21, 0)
        ..lineTo(-8, -9 - r * .45)
        ..lineTo(-12, 0)
        ..close();
      _fill(c, _path, const ui.Color(0xffe1fcff));
      _path
        ..reset()
        ..moveTo(-17, 0)
        ..lineTo(17, 0);
      _stroke(c, _path, const ui.Color(0xffffffff), 1.5);
      for (var i = 0; i < 4 + r; i++) {
        final p = (time * 2.6 + i * .157) % 1;
        final x = -20 - p * length,
            y = math.sin(i * 2.4 + time * 15) * (4 + p * 10);
        _path
          ..reset()
          ..moveTo(x + 5 * (1 - p), y)
          ..lineTo(x - 3, y - 2.5)
          ..lineTo(x - 4, y + 2.5)
          ..close();
        _fill(c, _path, element.color.withValues(alpha: (1 - p) * .85));
      }
    }
    c.restore();
  }

  static ui.Rect impactBounds(ui.Offset at, double radius) =>
      ui.Rect.fromCircle(center: at, radius: radius * 1.6 + 32);

  void impact(
    ui.Canvas c,
    ui.Offset at,
    double phase,
    double radius,
    MageElement element,
    int rank,
  ) {
    final t = phase.clamp(0.0, 1.0), r = SkillGrowth.level(rank);
    if (t >= 1) return;
    final fade = (1 - t) * (1 - t), spread = radius * (1 - math.pow(1 - t, 4));
    c.save();
    c.translate(at.dx, at.dy);
    // A low, dark contact patch and widening pressure front give the flash mass.
    _paint
      ..style = ui.PaintingStyle.fill
      ..color = const ui.Color(0xff142025).withValues(alpha: (1 - t) * .44);
    c.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: radius * (1.1 + t * .65),
        height: radius * (.35 + t * .25),
      ),
      _paint,
    );
    _paint
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = element == MageElement.lightning
          ? 1.2 + fade
          : 2 + (1 - t) * (3 + r * .3)
      ..color = element.color.withValues(alpha: fade * .9);
    final wave = ui.Rect.fromCenter(
      center: ui.Offset.zero,
      width: spread * 2,
      height: spread * 1.05,
    );
    if (element == MageElement.lightning) {
      for (var i = 0; i < 3; i++) {
        c.drawArc(wave, i * math.pi * 2 / 3 + t * .4, 1.35, false, _paint);
      }
      _glow(c, const ui.Offset(0, -6), radius * .65 * (1 - t) + 3, element);
    } else {
      c.drawOval(wave, _paint);
    }
    if (t < .22) {
      _paint
        ..style = ui.PaintingStyle.fill
        ..color = const ui.Color(
          0xfffffff2,
        ).withValues(alpha: (1 - t / .22) * .95);
      c.drawOval(
        ui.Rect.fromCenter(
          center: ui.Offset(0, -radius * .12),
          width: radius * (.32 + r * .035),
          height: radius * .3,
        ),
        _paint,
      );
    }
    if (element == MageElement.fire) {
      _flame.impact(c, ui.Offset.zero, t, radius);
    }
    final particles = 6 + r * 2;
    if (element == MageElement.lightning) _path.reset();
    for (var i = 0; i < particles; i++) {
      final a = i * 2.39996;
      final speed = radius * (.45 + i % 4 * .15);
      final p = ui.Offset(
        math.cos(a) * speed * t,
        math.sin(a) * speed * t * .48 -
            math.sin(t * math.pi) * radius * (.22 + i % 3 * .1),
      );
      if (element == MageElement.lightning) {
        if (i >= 3 + r) continue;
        final endpoint = ui.Offset(
          math.cos(a) * spread,
          math.sin(a) * spread * .6 - 12 * (1 - t),
        );
        final side = ui.Offset(-math.sin(a), math.cos(a));
        final bend =
            endpoint * .53 +
            side * math.sin((t * 24).floor() * 3.1 + i * 7.7) * (5.0 + r);
        _path
          ..moveTo(0, -6)
          ..lineTo(bend.dx, bend.dy)
          ..lineTo(endpoint.dx, endpoint.dy);
      } else if (element == MageElement.ice) {
        final height =
            radius *
            (.12 + i % 3 * .035) *
            math.sin(math.min(1, t * 4) * math.pi / 2);
        _path
          ..reset()
          ..moveTo(p.dx - height * .22, p.dy)
          ..lineTo(p.dx + math.cos(a) * height * .25, p.dy - height)
          ..lineTo(p.dx + height * .24, p.dy)
          ..close();
        _fill(
          c,
          _path,
          const ui.Color(0xffbfefff).withValues(alpha: (1 - t) * .85),
        );
        _path
          ..reset()
          ..moveTo(p.dx, p.dy)
          ..lineTo(p.dx + math.cos(a) * height * .25, p.dy - height);
        _stroke(
          c,
          _path,
          const ui.Color(0xfff1feff).withValues(alpha: fade),
          1 + r * .12,
        );
      } else {
        _path
          ..reset()
          ..moveTo(p.dx, p.dy)
          ..lineTo(
            p.dx - math.cos(a) * (3 + r),
            p.dy - math.sin(a) * (3 + r) - 3,
          );
        _stroke(
          c,
          _path,
          element.color.withValues(alpha: fade * .95),
          2 + r * .25,
        );
      }
    }
    if (element == MageElement.lightning) {
      _stroke(
        c,
        _path,
        element.color.withValues(alpha: fade * .8),
        2.1 + r * .18,
      );
      _stroke(
        c,
        _path,
        const ui.Color(0xfff0fcff).withValues(alpha: fade),
        .9 + r * .07,
      );
    }
    c.restore();
  }

  void meteorPressure(ui.Canvas c, ui.Offset at, double phase, int rank) {
    final t = phase.clamp(0.0, 1.0);
    _paint
      ..style = ui.PaintingStyle.fill
      ..color = const ui.Color(0xff211818).withValues(alpha: .08 + t * t * .35);
    c.drawOval(
      ui.Rect.fromCenter(center: at, width: 30 + t * 115, height: 12 + t * 52),
      _paint,
    );
    for (var i = 0; i < 2 + rank ~/ 2; i++) {
      _paint
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.3 + t
        ..color = const ui.Color(
          0xffffb875,
        ).withValues(alpha: (.12 + t * .35) / (i + 1));
      c.drawArc(
        ui.Rect.fromCenter(
          center: at,
          width: 100 + i * 33 + t * 50,
          height: 45 + i * 14 + t * 20,
        ),
        t * 1.5 + i * 2.2,
        math.pi * .7,
        false,
        _paint,
      );
    }
  }
}

/// A forked discharge, with sharp leaders instead of a slowly waving line.
/// Geometry changes at most24times/sec; reusable paths avoid particle objects.
class ElectricArcArt {
  final _paint = ui.Paint();
  final _main = ui.Path(), _forks = ui.Path(), _afterimage = ui.Path();
  int? _tick;
  ui.Offset? _from, _to;
  int? _seed, _rank, _branches;

  void paint(
    ui.Canvas c,
    ui.Offset from,
    ui.Offset to,
    double time, {
    int rank = 1,
    double opacity = 1,
    int seed = 0,
    int branches = 2,
  }) {
    final r = SkillGrowth.level(rank), tick = (time * 24).floor();
    if (_tick != tick ||
        _from != from ||
        _to != to ||
        _seed != seed ||
        _rank != r ||
        _branches != branches) {
      _afterimage.reset();
      if (_from == from && _to == to && _seed == seed) {
        _afterimage.addPath(_main, ui.Offset.zero);
      }
      _main.reset();
      _forks.reset();
      final d = to - from, length = d.distance;
      final side = length == 0
          ? const ui.Offset(0, 1)
          : ui.Offset(-d.dy, d.dx) / length;
      final steps = (length / 14).ceil().clamp(6, 28);
      final amplitude = math.min(15 + r * .7, length * .16);
      _main.moveTo(from.dx, from.dy);
      var forks = 0;
      for (var i = 1; i <= steps; i++) {
        final jitter = i == steps
            ? 0.0
            : math.sin(i * 3.91 + tick * 4.17 + seed * 7.3) * amplitude;
        final at = ui.Offset.lerp(from, to, i / steps)! + side * jitter;
        _main.lineTo(at.dx, at.dy);
        if (i < steps &&
            i % math.max(1, steps ~/ (branches + 1)) == 0 &&
            forks < branches) {
          final end =
              at +
              d / math.max(1, length) * (8 + r * 2) +
              side * ((i.isEven ? 1 : -1) * (14 + r * 3));
          final bend = ui.Offset.lerp(at, end, .55)! - side * 7;
          _forks
            ..moveTo(at.dx, at.dy)
            ..lineTo(bend.dx, bend.dy)
            ..lineTo(end.dx, end.dy);
          forks++;
        }
      }
      _tick = tick;
      _from = from;
      _to = to;
      _seed = seed;
      _rank = r;
      _branches = branches;
    }
    final alpha = opacity.clamp(0.0, 1.0);
    _paint
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.butt
      ..strokeJoin = ui.StrokeJoin.bevel;
    _paint
      ..color = const ui.Color(0xff4679b7).withValues(alpha: alpha * .18)
      ..strokeWidth = 6 + r * .4;
    c.drawPath(_afterimage, _paint);
    _paint
      ..color = const ui.Color(0xff247bcc).withValues(alpha: alpha * .2)
      ..strokeWidth = 7 + r * .8;
    c.drawPath(_main, _paint);
    _paint
      ..color = const ui.Color(0xff73d6ff).withValues(alpha: alpha * .85)
      ..strokeWidth = 2.3 + r * .2;
    c.drawPath(_main, _paint);
    c.drawPath(_forks, _paint);
    _paint
      ..color = const ui.Color(0xfff4fcff).withValues(alpha: alpha)
      ..strokeWidth = 1.05 + r * .1;
    c.drawPath(_main, _paint);
    c.drawPath(_forks, _paint);
  }
}

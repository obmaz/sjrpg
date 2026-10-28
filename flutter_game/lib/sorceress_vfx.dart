import 'dart:math' as math;
import 'dart:ui';

/// Presentation only. Flame components own positions, collision and lifetime.
/// `time` is simulation seconds; finite progress in [0, 1) is alive. The hollow
/// cast/buff centers, short ribbons and bounded particles keep the hero visible.
abstract final class SorceressVfx {
  static const skills = <String>[
    'iceBolt',
    'frozenArmor',
    'frostNova',
    'iceBlast',
    'shiverArmor',
    'glacialSpike',
    'blizzard',
    'chillingArmor',
    'frozenOrb',
    'coldMastery',
    'chargedBolt',
    'staticField',
    'telekinesis',
    'nova',
    'lightning',
    'chainLightning',
    'blink',
    'thunderStorm',
    'energyShield',
    'lightningMastery',
    'firebolt',
    'warmth',
    'inferno',
    'blaze',
    'fireball',
    'firewall',
    'enchant',
    'meteor',
    'hydra',
    'fireMastery',
  ];
  static const _cold = <String>{
    'iceBolt',
    'frozenArmor',
    'frostNova',
    'iceBlast',
    'shiverArmor',
    'glacialSpike',
    'blizzard',
    'chillingArmor',
    'frozenOrb',
    'coldMastery',
  };
  static const _electric = <String>{
    'chargedBolt',
    'staticField',
    'telekinesis',
    'nova',
    'lightning',
    'chainLightning',
    'blink',
    'thunderStorm',
    'energyShield',
    'lightningMastery',
  };
  static ({Color main, Color core, Color shade}) _colors(String id) =>
      _cold.contains(id)
      ? (
          main: const Color(0xff83caff),
          core: const Color(0xfff2fbff),
          shade: const Color(0xff3b6eb8),
        )
      : _electric.contains(id)
      ? (
          main: const Color(0xff8ab8ff),
          core: const Color(0xfff5f3d7),
          shade: const Color(0xff5e69ce),
        )
      : (
          main: const Color(0xffff6a20),
          core: const Color(0xffffe8a4),
          shade: const Color(0xffa52e16),
        );
  static int _rank(int rank) => rank.clamp(1, 20);
  static bool _valid(
    Offset at,
    double radius,
    double progress,
    double time,
    double bearing,
  ) =>
      at.dx.isFinite &&
      at.dy.isFinite &&
      radius.isFinite &&
      radius > 0 &&
      progress.isFinite &&
      progress >= 0 &&
      progress < 1 &&
      time.isFinite &&
      time >= 0 &&
      bearing.isFinite;
  static Color _alpha(Color c, double alpha) =>
      c.withValues(alpha: alpha.clamp(0, 1));
  static Offset _direction(double angle) =>
      Offset(math.cos(angle), math.sin(angle));
  static double _noise(double value) => math.sin(value * 12.9898 + 78.233);

  static void projectile(
    Canvas canvas,
    String skillId,
    Offset center, {
    double bearing = 0,
    double time = 0,
    int rank = 1,
    double radius = 12,
    int seed = 0,
    double progress = 0,
  }) {
    if (!_valid(center, radius, progress, time, bearing)) return;
    final colors = _colors(skillId), level = _rank(rank);
    canvas.save();
    try {
      canvas.translate(center.dx, center.dy);
      canvas.rotate(bearing);
      final fade = 1 - progress;
      if (skillId == 'chargedBolt') {
        final path = Path()..moveTo(-radius * 2.2, 0);
        for (var i = 1; i <= 6; i++) {
          path.lineTo(
            -radius * 2.2 + radius * 2.4 * i / 6,
            math.sin(time * 23 + seed + i * 2.1) * radius * .32,
          );
        }
        _stroke(canvas, path, colors.shade, 5, fade * .35);
        _stroke(canvas, path, colors.main, 2.3, fade);
        _stroke(canvas, path, colors.core, .85, fade);
      } else if (_cold.contains(skillId)) {
        final path = Path();
        for (var i = 0; i < 4 + level ~/ 6; i++) {
          final t = (time * 1.8 + i * .19) % 1;
          _shard(
            canvas,
            path,
            Offset(
              -radius * (1 + t * 1.8),
              math.sin(i * 3.1 + seed) * radius * .5,
            ),
            radius * (.12 + .12 * (1 - t)),
            time * 2 + i,
            colors.main,
            fade * (1 - t) * .75,
          );
        }
        if (skillId == 'frozenOrb') {
          canvas.drawCircle(
            Offset.zero,
            radius * .8,
            Paint()..color = _alpha(colors.shade, fade * .7),
          );
          canvas.drawCircle(
            const Offset(-1, -1),
            radius * .55,
            Paint()..color = _alpha(colors.main, fade),
          );
          canvas.drawArc(
            Rect.fromCircle(center: Offset.zero, radius: radius * .72),
            time * 4,
            3.8,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = _alpha(colors.core, fade),
          );
          for (var i = 0; i < 6; i++) {
            final angle = i * math.pi / 3 + time * 1.7;
            _shard(
              canvas,
              path,
              _direction(angle) * radius * .9,
              radius * .18,
              angle,
              colors.core,
              fade,
            );
          }
        } else if (skillId == 'iceBlast') {
          canvas.drawCircle(
            Offset.zero,
            radius * .78,
            Paint()..color = _alpha(colors.shade, fade),
          );
          canvas.drawCircle(
            Offset(-radius * .10, -radius * .12),
            radius * .55,
            Paint()..color = _alpha(colors.main, fade),
          );
          canvas.drawArc(
            Rect.fromCircle(center: Offset.zero, radius: radius * .62),
            -math.pi * .85,
            1.8,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.3
              ..color = _alpha(colors.core, fade),
          );
          for (var i = 0; i < 5; i++) {
            final angle = i * math.pi * 2 / 5 + time;
            _shard(
              canvas,
              path,
              _direction(angle) * radius * .82,
              radius * .24,
              angle,
              colors.core,
              fade * .8,
            );
          }
        } else {
          final long = skillId == 'glacialSpike'
              ? 1.7
              : skillId == 'iceBlast'
              ? 1.15
              : 1.4;
          path.reset();
          path.moveTo(radius * long, 0);
          path.lineTo(-radius * .35, -radius * .55);
          path.lineTo(-radius, 0);
          path.lineTo(-radius * .35, radius * .55);
          path.close();
          canvas.drawPath(path, Paint()..color = _alpha(colors.shade, fade));
          path.reset();
          path.moveTo(radius * long, 0);
          path.lineTo(-radius * .35, -radius * .4);
          path.lineTo(-radius * .55, 0);
          path.close();
          canvas.drawPath(path, Paint()..color = _alpha(colors.main, fade));
          canvas.drawLine(
            Offset(-radius * .5, 0),
            Offset(radius * long, 0),
            Paint()
              ..strokeWidth = 1.2
              ..color = _alpha(colors.core, fade),
          );
        }
      } else if (_electric.contains(skillId)) {
        _electricOrb(canvas, radius, time + seed, fade);
      } else {
        _fireball(
          canvas,
          radius,
          time,
          level,
          seed,
          fade,
          large: skillId == 'fireball' || skillId == 'meteor',
        );
      }
    } finally {
      canvas.restore();
    }
  }

  static void ground(
    Canvas canvas,
    String skillId,
    Offset center, {
    double progress = 0,
    double time = 0,
    int rank = 1,
    double radius = 80,
    double bearing = 0,
    int seed = 0,
  }) {
    if (!_valid(center, radius, progress, time, bearing)) return;
    final level = _rank(rank), fade = math.min(1.0, (1 - progress) * 4);
    canvas.save();
    try {
      canvas.translate(center.dx, center.dy);
      switch (skillId) {
        case 'inferno':
          canvas.rotate(bearing);
          final path = Path();
          final count = 10 + level ~/ 5;
          for (var i = 0; i < count; i++) {
            final t = (time * 1.7 + i / count) % 1;
            final distance = 20 + math.max(0, radius - 20) * t;
            final spread = distance * .28 * math.sin(i * 2.4 + seed);
            _flame(
              canvas,
              path,
              Offset(distance, spread),
              8 + t * 12 + level * .12,
              time * 11 + i,
              fade * (1 - t * .65),
              angle: math.pi / 2,
            );
          }
        case 'firewall':
          canvas.rotate(bearing);
          _fireLine(canvas, radius, time, level, seed, fade);
        case 'blaze' ||
            'warmth' ||
            'enchant' ||
            'fireMastery' ||
            'meteorResidual':
          final path = Path();
          final count = 6 + level ~/ 5;
          for (var i = 0; i < count; i++) {
            final a = i * math.pi * 2 / count + seed;
            final at =
                _direction(a) *
                radius *
                (.25 + .35 * (.5 + .5 * math.sin(i * 2.7)));
            _flame(
              canvas,
              path,
              at,
              math.min(30, radius * .65),
              time * 8 + i * 1.7,
              fade * .85,
            );
          }
        case 'blizzard':
          final path = Path();
          final count = 9 + level ~/ 4;
          for (var i = 0; i < count; i++) {
            final a = i * 2.39996 + seed,
                d = radius * math.sqrt((i + .5) / count) * .83;
            final target = _direction(a) * d;
            final drop = (time * 1.55 + i * .21) % 1;
            final ice =
                target + Offset(-14 * (1 - drop), -radius * .9 * (1 - drop));
            _shard(
              canvas,
              path,
              ice,
              4 + level * .10,
              1.2,
              const Color(0xffd9f4ff),
              fade * (.25 + drop * .7),
            );
            if (drop > .72) {
              canvas.drawOval(
                Rect.fromCenter(
                  center: target,
                  width: 16 * drop,
                  height: 7 * drop,
                ),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1
                  ..color = _alpha(
                    const Color(0xffa0ddff),
                    fade * (1 - drop) * 2,
                  ),
              );
            }
          }
        case 'hydra':
          _hydra(canvas, radius, time, level, bearing, fade);
        case 'frozenOrb':
          projectile(
            canvas,
            'frozenOrb',
            Offset.zero,
            time: time,
            radius: math.min(18, radius * .2),
            rank: level,
          );
          final path = Path();
          for (var i = 0; i < 16; i++) {
            final a = i * math.pi / 8 + time * .18 + seed;
            final t = (time * .9 + i * .137) % 1;
            _shard(
              canvas,
              path,
              _direction(a) * radius * t,
              3 + (1 - t) * 2.5,
              a,
              const Color(0xffd8f5ff),
              fade * (1 - t),
            );
          }
        case 'meteorMarker':
          _ring(
            canvas,
            radius * .92,
            const Color(0xffe58136),
            1,
            fade * (.45 + .12 * math.sin(time * 6)),
          );
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final angle = i * math.pi / 2;
            _shard(
              canvas,
              path,
              _direction(angle) * radius * .92,
              3.5,
              angle,
              const Color(0xffffc271),
              fade * .65,
            );
          }
        case 'meteor':
          if (progress < .45) {
            final t = progress / .45;
            _fireballAt(
              canvas,
              Offset(-radius * .45 * (1 - t), -radius * 2.2 * (1 - t)),
              math.min(27, radius * .32),
              time,
              level,
              seed,
              1,
            );
            _ring(
              canvas,
              radius * .68,
              const Color(0xffcf6b2d),
              .7 + .5 * math.sin(time * 7),
              .5,
            );
          } else if (progress < .70) {
            _burst(
              canvas,
              'meteor',
              radius,
              (progress - .45) / .25,
              level,
              seed,
            );
          } else {
            _fireLine(canvas, radius * .65, time, level, seed, fade * .65);
          }
        case 'frostNova' || 'nova' || 'staticField':
          _nova(canvas, skillId, radius, progress, time, level, seed);
        case 'blink':
          _teleport(canvas, radius, progress, seed);
        case 'telekinesis':
          _ring(canvas, radius * .45, const Color(0xffe8d5a3), 1.3, fade * .7);
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final a = time * 4 + i * math.pi / 2;
            _shard(
              canvas,
              path,
              _direction(a) * radius * .6,
              4,
              a,
              const Color(0xffc8dbff),
              fade,
            );
          }
        case 'thunderStorm':
          final points = <Offset>[
            Offset(-radius * .15, -radius),
            const Offset(-6, -30),
            Offset.zero,
          ];
          beam(
            canvas,
            'lightning',
            points,
            time: time,
            rank: level,
            progress: progress,
          );
          _ring(canvas, radius * .33, const Color(0xff8298e9), 1.1, fade * .6);
        default:
          _burst(canvas, skillId, radius, progress, level, seed);
      }
    } finally {
      canvas.restore();
    }
  }

  static void cast(
    Canvas canvas,
    String skillId,
    Offset center, {
    double progress = 0,
    int rank = 1,
    double radius = 60,
    double bearing = 0,
    int seed = 0,
  }) {
    if (!_valid(center, radius, progress, 0, bearing)) return;
    canvas.save();
    try {
      canvas.translate(center.dx, center.dy);
      if (skillId == 'blink') {
        _teleport(canvas, radius, progress, seed);
      } else {
        final colors = _colors(skillId),
            r = math.max(17.0, radius * (.28 + progress * .35));
        final path = Path(), count = _cold.contains(skillId) ? 6 : 5;
        for (var i = 0; i < count; i++) {
          final angle = i * math.pi * 2 / count + progress * 2 + bearing;
          final at = _direction(angle) * r;
          _shard(
            canvas,
            path,
            at,
            2.5 + _rank(rank) * .06,
            angle + progress,
            colors.core,
            (1 - progress) * .85,
          );
        }
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r),
          bearing + progress * 3,
          math.pi * 1.4,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = _alpha(colors.main, (1 - progress) * .6),
        );
      }
    } finally {
      canvas.restore();
    }
  }

  static void impact(
    Canvas canvas,
    String skillId,
    Offset center, {
    double progress = 0,
    int rank = 1,
    double radius = 60,
    double bearing = 0,
    int seed = 0,
  }) {
    if (!_valid(center, radius, progress, 0, bearing)) return;
    canvas.save();
    try {
      canvas.translate(center.dx, center.dy);
      if (skillId == 'blink') {
        _teleport(canvas, radius, progress, seed);
      } else {
        _burst(canvas, skillId, radius, progress, _rank(rank), seed);
      }
    } finally {
      canvas.restore();
    }
  }

  static void buff(
    Canvas canvas,
    String skillId,
    Offset center, {
    double time = 0,
    int rank = 1,
    double radius = 30,
  }) {
    if (!_valid(center, radius, 0, time, 0)) return;
    canvas.save();
    try {
      canvas.translate(center.dx, center.dy);
      if (skillId == 'energyShield') {
        // Diablo-style overhead golden orb rather than an opaque body bubble.
        final orb = Offset(0, -radius * 2.9), r = radius * .28;
        canvas.drawCircle(
          orb,
          r + 1.5,
          Paint()..color = const Color(0x40795324),
        );
        canvas.drawCircle(orb, r, Paint()..color = const Color(0xff806027));
        canvas.drawCircle(
          orb + Offset(-r * .12, -r * .10),
          r * .78,
          Paint()..color = const Color(0xffd5b65c),
        );
        canvas.drawCircle(
          orb + Offset(-r * .23, -r * .30),
          r * .30,
          Paint()..color = const Color(0xfffff0b9),
        );
        final edge = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = const Color(0xfff4dfa1);
        canvas.drawArc(
          Rect.fromCenter(center: orb, width: r * 2.8, height: r * 1.7),
          time * 1.6,
          3.6,
          false,
          edge,
        );
        canvas.drawArc(
          Rect.fromCircle(center: orb, radius: r * .63),
          -time * 2.1,
          2.4,
          false,
          edge..color = const Color(0xff856032),
        );
        _star(
          canvas,
          orb + _direction(time * 1.4) * r * 1.35,
          2.2,
          const Color(0xffffe4a0),
          .8,
        );
      } else if (_cold.contains(skillId)) {
        final count = skillId == 'frozenArmor'
            ? 3
            : skillId == 'shiverArmor'
            ? 6
            : skillId == 'chillingArmor'
            ? 4
            : 5;
        final path = Path();
        for (var i = 0; i < count; i++) {
          final a =
              i * math.pi * 2 / count +
              time * (skillId == 'shiverArmor' ? -.55 : .45);
          final at = Offset(math.cos(a) * radius, math.sin(a) * radius * .7);
          _shard(
            canvas,
            path,
            at,
            skillId == 'chillingArmor' ? 7 : 4.8,
            skillId == 'frozenArmor' ? a : a + time,
            const Color(0xffb2e4ff),
            .68,
          );
        }
        if (skillId == 'shiverArmor') {
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset.zero,
              width: radius * 2.1,
              height: radius * 1.5,
            ),
            time,
            3.2,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = .8
              ..color = const Color(0xff5b9cd0),
          );
        }
      } else if (_electric.contains(skillId)) {
        final path = Path();
        for (var i = 0; i < 3; i++) {
          final a = time + i * math.pi * 2 / 3;
          final at = _direction(a) * radius;
          path.reset();
          path.moveTo(at.dx - 4, at.dy - 5);
          path.lineTo(at.dx + 2, at.dy);
          path.lineTo(at.dx - 1, at.dy + 2);
          path.lineTo(at.dx + 5, at.dy + 6);
          _stroke(canvas, path, const Color(0xffd6e7ff), 1, .75);
        }
      } else {
        final path = Path();
        for (var i = 0; i < 4; i++) {
          _flame(
            canvas,
            path,
            Offset((i - 1.5) * radius * .4, radius * .65),
            radius * .42,
            time * 8 + i * 1.8,
            .72,
          );
        }
      }
      for (var i = 0; i < _rank(rank) ~/ 5; i++) {
        final angle = time * .8 + i * 2.4;
        _star(
          canvas,
          _direction(angle) * radius * 1.1,
          1.7,
          skillId == 'energyShield'
              ? const Color(0xffffe6a0)
              : _colors(skillId).core,
          .6,
        );
      }
    } finally {
      canvas.restore();
    }
  }

  static void beam(
    Canvas canvas,
    String skillId,
    List<Offset> points, {
    double time = 0,
    int rank = 1,
    double progress = 0,
  }) {
    if (points.length < 2 ||
        !progress.isFinite ||
        progress < 0 ||
        progress >= 1 ||
        !time.isFinite ||
        time < 0 ||
        points.any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
      return;
    }
    final colors = _colors(skillId), fade = 1 - progress;
    final path = Path(), branch = Path();
    canvas.save();
    try {
      for (var segment = 1; segment < math.min(points.length, 33); segment++) {
        final a = points[segment - 1], b = points[segment], delta = b - a;
        if (delta.distanceSquared < .001) continue;
        final normal = Offset(-delta.dy, delta.dx) / delta.distance;
        final steps = (delta.distance / 18).ceil().clamp(2, 24);
        path.reset();
        path.moveTo(a.dx, a.dy);
        for (var i = 1; i <= steps; i++) {
          final t = i / steps;
          final bend = i == steps
              ? 0.0
              : _noise(i * 2.31 + segment * 4 + (time * 20).floor()) *
                    math.min(6, delta.distance * .045);
          final at = a + delta * t + normal * bend;
          path.lineTo(at.dx, at.dy);
          if (i == steps ~/ 2 && _electric.contains(skillId)) {
            final tip =
                at +
                normal * (9 + _rank(rank) * .15) -
                delta / delta.distance * 7;
            branch.reset();
            branch.moveTo(at.dx, at.dy);
            branch.lineTo(tip.dx, tip.dy);
            _stroke(canvas, branch, colors.main, .8, fade * .65);
          }
        }
        _stroke(canvas, path, colors.shade, 5 + _rank(rank) * .05, fade * .3);
        _stroke(canvas, path, colors.main, 2.3, fade * .95);
        _stroke(canvas, path, colors.core, .9, fade);
      }
    } finally {
      canvas.restore();
    }
  }

  /// Runtime can use these same three mouth positions for Hydra projectiles.
  static List<Offset> hydraHeads(
    Offset center, {
    double time = 0,
    double radius = 80,
  }) => List.generate(
    3,
    (i) =>
        center +
        Offset(
          (i - 1) * radius * .43 + math.sin(time * 1.8 + i) * 3,
          -radius * (.35 + (i == 1 ? .13 : 0)) +
              math.sin(time * 2.4 + i * 1.7) * 3,
        ),
  );

  static void _stroke(
    Canvas c,
    Path p,
    Color color,
    double width,
    double alpha,
  ) => c.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = _alpha(color, alpha),
  );
  static void _ring(
    Canvas c,
    double radius,
    Color color,
    double width,
    double alpha,
  ) {
    if (radius <= 0) return;
    c.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = _alpha(color, alpha),
    );
  }

  static void _shard(
    Canvas c,
    Path path,
    Offset at,
    double size,
    double angle,
    Color color,
    double alpha,
  ) {
    final forward = _direction(angle) * size,
        side = _direction(angle + math.pi / 2) * size * .44;
    path.reset();
    path.moveTo(at.dx + forward.dx, at.dy + forward.dy);
    path.lineTo(at.dx + side.dx, at.dy + side.dy);
    path.lineTo(at.dx - forward.dx, at.dy - forward.dy);
    path.lineTo(at.dx - side.dx, at.dy - side.dy);
    path.close();
    c.drawPath(path, Paint()..color = _alpha(color, alpha));
  }

  static void _flame(
    Canvas c,
    Path path,
    Offset at,
    double size,
    double phase,
    double alpha, {
    double angle = 0,
  }) {
    final sway = math.sin(phase) * size * .25;
    Offset point(double x, double y) =>
        at +
        Offset(
          x * math.cos(angle) - y * math.sin(angle),
          x * math.sin(angle) + y * math.cos(angle),
        );
    final left = point(-size * .22, 0),
        tip = point(sway, -size),
        right = point(size * .23, 0),
        waist = point(-sway * .5, -size * .38);
    path.reset();
    path.moveTo(left.dx, left.dy);
    path.quadraticBezierTo(waist.dx - size * .17, waist.dy, tip.dx, tip.dy);
    path.quadraticBezierTo(waist.dx + size * .35, waist.dy, right.dx, right.dy);
    path.close();
    c.drawPath(path, Paint()..color = _alpha(const Color(0xffd83e14), alpha));
    final innerTip = point(sway * .6, -size * .68),
        bottom = point(0, size * .03);
    path.reset();
    path.moveTo(left.dx * .5 + at.dx * .5, left.dy * .5 + at.dy * .5);
    path.quadraticBezierTo(at.dx, at.dy - size * .3, innerTip.dx, innerTip.dy);
    path.lineTo(bottom.dx, bottom.dy);
    path.close();
    c.drawPath(path, Paint()..color = _alpha(const Color(0xffffa137), alpha));
    c.drawCircle(
      point(0, -size * .13),
      math.max(.6, size * .09),
      Paint()..color = _alpha(const Color(0xffffe9a8), alpha),
    );
  }

  static void _fireball(
    Canvas c,
    double r,
    double time,
    int rank,
    int seed,
    double fade, {
    bool large = false,
  }) {
    final path = Path(), count = 5 + rank ~/ 5;
    for (var i = 0; i < count; i++) {
      final t = (time * 2.4 + i / count) % 1;
      _flame(
        c,
        path,
        Offset(-r * (.5 + t * 2.5), math.sin(i * 2.3 + seed) * r * .35),
        r * (.5 + .7 * (1 - t)),
        time * 12 + i,
        fade * (1 - t),
        angle: -math.pi / 2,
      );
    }
    c.drawCircle(
      Offset.zero,
      r * (large ? .85 : .55),
      Paint()..color = _alpha(const Color(0xffb53115), fade),
    );
    c.drawCircle(
      Offset(-r * .15, -r * .1),
      r * (large ? .60 : .4),
      Paint()..color = _alpha(const Color(0xffff8e29), fade),
    );
    c.drawCircle(
      Offset(r * .1, -r * .12),
      r * .27,
      Paint()..color = _alpha(const Color(0xffffedb0), fade),
    );
  }

  static void _fireballAt(
    Canvas c,
    Offset at,
    double r,
    double time,
    int rank,
    int seed,
    double fade,
  ) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(math.pi / 2);
    _fireball(c, r, time, rank, seed, fade, large: true);
    c.restore();
  }

  static void _electricOrb(Canvas c, double r, double time, double fade) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + time * 2;
      final at = _direction(a) * r;
      path.reset();
      path.moveTo(-at.dx, -at.dy);
      path.lineTo(at.dy * .4, at.dx * .4);
      path.lineTo(at.dx, at.dy);
      _stroke(c, path, const Color(0xff617bdd), 3, fade * .35);
      _stroke(c, path, const Color(0xffe6edff), 1, fade);
    }
  }

  static void _fireLine(
    Canvas c,
    double radius,
    double time,
    int rank,
    int seed,
    double fade,
  ) {
    final path = Path(), count = 7 + rank ~/ 4;
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radius * 1.9, height: 12),
      Paint()..color = _alpha(const Color(0xff762d1a), fade * .27),
    );
    for (var i = 0; i < count; i++) {
      _flame(
        c,
        path,
        Offset(
          -radius * .82 + radius * 1.64 * i / math.max(1, count - 1),
          math.sin(i + seed) * 3,
        ),
        18 + rank * .25 + 7 * math.sin(time * 7 + i * 2.1),
        time * 9 + i,
        fade,
      );
    }
  }

  static void _nova(
    Canvas c,
    String id,
    double radius,
    double p,
    double time,
    int rank,
    int seed,
  ) {
    final colors = _colors(id), r = radius * (.18 + .82 * p), fade = 1 - p;
    _ring(c, r, colors.shade, 6, fade * .28);
    _ring(c, r, colors.main, 2.5, fade);
    _ring(c, math.max(1, r - 3), colors.core, .8, fade * .8);
    final path = Path(), count = 8 + rank ~/ 4;
    if (id == 'nova') {
      for (var i = 0; i <= 24; i++) {
        final angle = i * math.pi / 12;
        final point =
            _direction(angle) * (r * (1 + .06 * math.sin(i * 3.7 + time * 20)));
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      _stroke(c, path, colors.core, 1.15, fade);
    }
    for (var i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count + seed + p * .3;
      if (id == 'frostNova') {
        _shard(
          c,
          path,
          _direction(a) * r,
          3 + 5 * (1 - p),
          a + .3,
          colors.core,
          fade,
        );
      } else {
        final at = _direction(a) * r,
            out = _direction(a + .025 * math.sin(time * 13 + i)) * (r + 7);
        path.reset();
        path.moveTo(at.dx, at.dy);
        path.lineTo(out.dx, out.dy);
        _stroke(
          c,
          path,
          id == 'staticField' ? const Color(0xffffe5a1) : colors.core,
          1.1,
          fade,
        );
      }
    }
  }

  static void _teleport(Canvas c, double radius, double p, int seed) {
    final fade = 1 - p, r = radius * (.25 + p * .6), path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + seed + p * 2;
      final at = Offset(math.cos(a) * r, math.sin(a) * r * .65);
      path.reset();
      path.moveTo(at.dx, at.dy - 12 * fade);
      path.quadraticBezierTo(
        at.dx + 4 * math.sin(p * 9 + i),
        at.dy,
        at.dx,
        at.dy + 10 * fade,
      );
      _stroke(c, path, const Color(0xff9cc6ff), 1.5, fade * .9);
      _star(c, at, 2 + fade * 2, const Color(0xffe3eeff), fade);
    }
  }

  static void _burst(
    Canvas c,
    String id,
    double radius,
    double p,
    int rank,
    int seed,
  ) {
    final colors = _colors(id), fade = 1 - p;
    final path = Path(), count = 8 + rank ~/ 4;
    final ring = radius * (.22 + .75 * p);
    _ring(c, ring, colors.shade, 5, fade * .25);
    _ring(c, ring, colors.main, 1.6, fade * .75);
    for (var i = 0; i < count; i++) {
      final a = i * 2.39996 + seed;
      final distance =
          radius * (.15 + .75 * p) * (.55 + .45 * math.sin(i * 1.7).abs());
      final at = _direction(a) * distance;
      if (_cold.contains(id)) {
        _shard(
          c,
          path,
          at,
          (3 + rank * .1) * fade + .5,
          a + p * 3,
          colors.core,
          fade,
        );
      } else {
        final tail = at - _direction(a) * (5 + 14 * fade);
        c.drawLine(
          tail,
          at,
          Paint()
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = _alpha(colors.main, fade),
        );
        c.drawCircle(
          at,
          1.2 + fade,
          Paint()..color = _alpha(colors.core, fade),
        );
      }
    }
  }

  static void _star(
    Canvas c,
    Offset at,
    double size,
    Color color,
    double alpha,
  ) {
    final paint = Paint()
      ..strokeWidth = 1
      ..color = _alpha(color, alpha);
    c.drawLine(at - Offset(size, 0), at + Offset(size, 0), paint);
    c.drawLine(at - Offset(0, size), at + Offset(0, size), paint);
  }

  static void _hydra(
    Canvas c,
    double radius,
    double time,
    int rank,
    double bearing,
    double fade,
  ) {
    final heads = hydraHeads(Offset.zero, time: time, radius: radius);
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final head = heads[i], base = Offset((i - 1) * radius * .3, radius * .2);
      path.reset();
      path.moveTo(base.dx, base.dy);
      path.cubicTo(
        base.dx - 10,
        -radius * .10,
        head.dx + 9,
        head.dy + 12,
        head.dx,
        head.dy,
      );
      _stroke(c, path, const Color(0xff7f2314), 8, fade);
      _stroke(c, path, const Color(0xffd45e21), 4, fade);
      final forward = _direction(bearing),
          side = _direction(bearing + math.pi / 2);
      path.reset();
      path.moveTo(head.dx - side.dx * 5, head.dy - side.dy * 5);
      final nose = head + forward * 10;
      path.lineTo(nose.dx, nose.dy);
      path.lineTo(head.dx + side.dx * 5, head.dy + side.dy * 5);
      path.close();
      c.drawPath(path, Paint()..color = _alpha(const Color(0xffe17d2d), fade));
      c.drawCircle(
        head + forward * 2 - side * 2,
        1.4,
        Paint()..color = _alpha(const Color(0xffffe298), fade),
      );
      final breath = .5 + .5 * math.sin(time * 5 + i * 2);
      if (breath > .3) {
        _flame(
          c,
          path,
          nose + forward * 9,
          13 + breath * 10 + rank * .15,
          time * 11 + i,
          fade * breath,
          angle: bearing + math.pi / 2,
        );
      }
    }
  }
}

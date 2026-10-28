import 'dart:math' as math;
import 'dart:ui' as ui;
import 'steel_pressure_vfx.dart';

/// Presentation only: callers own movement, hit timing, targets and simulation.
enum BarbarianVfxKind {
  bash,
  howl,
  taunt,
  shout,
  battleCry,
  battleOrders,
  battleCommand,
  warCry,
  leap,
  leapAttack,
  doubleSwing,
  stun,
  concentrate,
  berserk,
  doubleThrow,
  frenzy,
  whirlwind,
  findPotion,
  findItem,
  grimWard,
}

/// Offset the painted actor only; the collision footprint stays on the ground.
double barbarianAirborneHeight(BarbarianVfxKind kind, double progress) {
  if (kind != BarbarianVfxKind.leap && kind != BarbarianVfxKind.leapAttack) {
    return 0;
  }
  if (!progress.isFinite || progress <= 0 || progress >= 1) return 0;
  return math.sin(progress * math.pi) *
      (kind == BarbarianVfxKind.leapAttack ? 62 : 44);
}

/// Reuse one painter per active cast. There are no textures, blur, random
/// particles, saveLayers or unbounded emitters; debris is capped at six pieces.
class BarbarianVfxArt {
  BarbarianVfxArt(this.kind);

  final BarbarianVfxKind kind;
  static const _steel = ui.Color(0xffe4ece6);
  static const _gold = ui.Color(0xffe8bc62);
  static const _dust = ui.Color(0xffb69a72);
  static const _red = ui.Color(0xffe75d45);
  static const _white = ui.Color(0xfffff3cd);
  static final _core = ui.RRect.fromRectAndRadius(
    const ui.Rect.fromLTWH(-14, -54, 28, 44),
    const ui.Radius.circular(10),
  );
  static final _star = ui.Path()
    ..moveTo(0, -4)
    ..lineTo(1.3, -1.3)
    ..lineTo(4, 0)
    ..lineTo(1.3, 1.3)
    ..lineTo(0, 4)
    ..lineTo(-1.3, 1.3)
    ..lineTo(-4, 0)
    ..lineTo(-1.3, -1.3)
    ..close();
  static final _axeHead = ui.Path()
    ..moveTo(-3, -7)
    ..quadraticBezierTo(8, -13, 12, -4)
    ..lineTo(5, 2)
    ..lineTo(-3, 0)
    ..close();
  final _line = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  final _fill = ui.Paint();
  final _path = ui.Path();
  final _clip = ui.Path()..fillType = ui.PathFillType.evenOdd;

  double _radius(double radius) =>
      radius.isFinite ? radius.clamp(24.0, 240.0) : 72;

  /// Includes overhead status marks, axes and the outermost dust fragment.
  ui.Rect bounds(ui.Offset center, double radius) => ui.Rect.fromLTRB(
    center.dx - _radius(radius) - 32,
    center.dy - math.max(100, _radius(radius) + 32),
    center.dx + _radius(radius) + 32,
    center.dy + _radius(radius) + 32,
  );

  void _stroke(ui.Canvas c, ui.Color color, double alpha, double width) {
    c.drawPath(
      _path,
      _line
        ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..strokeWidth = width,
    );
  }

  void _segment(
    ui.Canvas c,
    ui.Offset a,
    ui.Offset b,
    ui.Color color,
    double alpha,
    double width,
  ) {
    c.drawLine(
      a,
      b,
      _line
        ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..strokeWidth = width,
    );
  }

  void _arc(
    ui.Canvas c,
    double radius,
    double start,
    double sweep,
    ui.Color color,
    double alpha,
    double width, {
    double flatten = .65,
  }) {
    c.drawArc(
      ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: radius * 2,
        height: radius * 2 * flatten,
      ),
      start,
      sweep,
      false,
      _line
        ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..strokeWidth = width,
    );
  }

  final _pressure = SteelPressureArt();

  void paint(
    ui.Canvas canvas, {
    required double progress,
    ui.Offset center = ui.Offset.zero,
    double bearing = 0,
    double radius = 72,
    int rank = 1,
    bool protectBody = true,
  }) {
    if (!progress.isFinite || progress < 0 || progress >= 1) return;
    if (!center.dx.isFinite || !center.dy.isFinite || !bearing.isFinite) return;
    final t = progress, r = _radius(radius), fade = 1 - t;
    final weight = 1 + rank.clamp(1, 20) * .025;
    canvas.save();
    try {
      canvas.translate(center.dx, center.dy);
      if (protectBody) {
        _clip
          ..reset()
          ..fillType = ui.PathFillType.evenOdd
          ..addRect(canvas.getLocalClipBounds())
          ..addRRect(_core);
        canvas.clipPath(_clip);
      }
      switch (kind) {
        case BarbarianVfxKind.howl:
        case BarbarianVfxKind.taunt:
        case BarbarianVfxKind.shout:
        case BarbarianVfxKind.battleCry:
        case BarbarianVfxKind.battleOrders:
        case BarbarianVfxKind.battleCommand:
        case BarbarianVfxKind.warCry:
          _pressure.paintWave(
            canvas,
            progress: t,
            radius: r,
            bearing: bearing,
            rank: rank,
            waves: kind == BarbarianVfxKind.taunt ? 1 : 2,
            directed: kind == BarbarianVfxKind.taunt,
          );
          _voice(canvas, t, r, weight, bearing);
        case BarbarianVfxKind.leap:
        case BarbarianVfxKind.leapAttack:
          // The airborne body is rendered by the actor. Dust belongs to the
          // takeoff/landing footprint, never a second floating character.
          if (t < .22) {
            _landing(canvas, t / .22, r * .42, false);
          } else if (t > .72) {
            _landing(
              canvas,
              (t - .72) / .28,
              r,
              kind == BarbarianVfxKind.leapAttack,
            );
          }
        case BarbarianVfxKind.stun:
          _stars(canvas, t, fade);
        case BarbarianVfxKind.doubleThrow:
          canvas.rotate(bearing);
          for (final side in [-1.0, 1.0]) {
            final at = ui.Offset(r * (.25 + t * .65), side * (12 + t * 8));
            _segment(
              canvas,
              at - ui.Offset(19 * fade, side * 3),
              at,
              _dust,
              fade * .6,
              1.6,
            );
            paintThrownAxe(canvas, at, t * 9 + side, t, rank: rank);
          }
        case BarbarianVfxKind.whirlwind:
          _pressure.paintWhirlwind(
            canvas,
            progress: t,
            radius: r,
            bearing: bearing,
            rank: rank,
          );
        case BarbarianVfxKind.findPotion:
        case BarbarianVfxKind.findItem:
        case BarbarianVfxKind.grimWard:
          _recovery(canvas, t, r);
        default:
          canvas.rotate(bearing);
          if ({
            BarbarianVfxKind.bash,
            BarbarianVfxKind.concentrate,
            BarbarianVfxKind.berserk,
            BarbarianVfxKind.frenzy,
            BarbarianVfxKind.doubleSwing,
          }.contains(kind)) {
            _blades(canvas, t, r, weight);
            _pressure.paintStrike(
              canvas,
              progress: t,
              radius: r,
              rank: rank,
              heavy:
                  kind == BarbarianVfxKind.bash ||
                  kind == BarbarianVfxKind.concentrate,
              fierce: kind == BarbarianVfxKind.berserk,
              dual:
                  kind == BarbarianVfxKind.frenzy ||
                  kind == BarbarianVfxKind.doubleSwing,
            );
          } else {
            _blades(canvas, t, r, weight);
          }
      }
    } finally {
      canvas.restore();
    }
  }

  void _voice(ui.Canvas c, double t, double r, double weight, double bearing) {
    final (color, waves) = switch (kind) {
      BarbarianVfxKind.howl => (const ui.Color(0xffd9bf89), 2),
      BarbarianVfxKind.taunt => (const ui.Color(0xffeaa071), 1),
      BarbarianVfxKind.shout => (const ui.Color(0xffa7bac8), 2),
      BarbarianVfxKind.battleCry => (_red, 2),
      BarbarianVfxKind.battleOrders => (const ui.Color(0xffcf774d), 3),
      BarbarianVfxKind.battleCommand => (_gold, 3),
      _ => (const ui.Color(0xffeee2ba), 3),
    };
    final directed = kind == BarbarianVfxKind.taunt;
    for (var i = 0; i < waves; i++) {
      final p = t * 1.25 - i * .15;
      if (p < 0 || p >= 1) continue;
      final reach = r * (.2 + .8 * p);
      _arc(
        c,
        reach,
        directed ? bearing - .65 : .12 + i * .16,
        directed ? 1.3 : math.pi * 1.78,
        color,
        (1 - p) * .72,
        1.8 * weight,
      );
    }
    if (kind == BarbarianVfxKind.warCry || kind == BarbarianVfxKind.howl) {
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + .3,
            d = ui.Offset(math.cos(a), math.sin(a) * .65);
        _segment(
          c,
          d * (r * (.3 + t * .55)),
          d * (r * (.39 + t * .55)),
          color,
          (1 - t) * .65,
          1.5,
        );
      }
    }
  }

  void _blades(ui.Canvas c, double t, double r, double weight) {
    final fade = 1 - t;
    if (kind == BarbarianVfxKind.doubleSwing ||
        kind == BarbarianVfxKind.frenzy) {
      final rapid = kind == BarbarianVfxKind.frenzy;
      for (final side in [-1.0, 1.0]) {
        final start = ui.Offset(r * .18, side * r * .5);
        final end = ui.Offset(r * (.73 + .17 * t), -side * r * .38);
        _path
          ..reset()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(r * .9, side * r * .28, end.dx, end.dy);
        _stroke(c, side < 0 ? _steel : _gold, fade * .85, 3 * weight);
        if (rapid) {
          _segment(
            c,
            start - const ui.Offset(12, 0),
            start + const ui.Offset(7, 0),
            _steel,
            fade * .4,
            1.2,
          );
        }
      }
      return;
    }
    final color = kind == BarbarianVfxKind.berserk
        ? _red
        : kind == BarbarianVfxKind.concentrate
        ? _gold
        : _steel;
    if (kind == BarbarianVfxKind.bash) {
      final hit = ui.Offset(r * (.55 + .25 * t), 0);
      _segment(c, ui.Offset(r * .18, 0), hit, _steel, fade, 4 * weight);
      for (var i = -1; i <= 1; i++) {
        final axis = ui.Offset(math.cos(i * .6), math.sin(i * .6));
        _segment(
          c,
          hit + axis * 5,
          hit + axis * (11 + t * 10),
          _gold,
          fade,
          1.5,
        );
      }
      return;
    }
    // Concentrate is one deliberate edge; berserk adds one blood-red outer
    // edge to a still-recognizable physical blade, without an opaque aura.
    _arc(
      c,
      r * .78,
      -.95 + t * .5,
      1.45,
      color,
      fade * .9,
      3 * weight,
      flatten: .9,
    );
    _arc(c, r * .72, -.9 + t * .5, 1.25, _white, fade * .75, 1.1, flatten: .9);
    if (kind == BarbarianVfxKind.concentrate) {
      _segment(
        c,
        ui.Offset(r * .48, -5),
        ui.Offset(r * .95, 0),
        _gold,
        fade * .6,
        1.4,
      );
    }
  }

  void _stars(ui.Canvas c, double t, double fade) {
    for (var i = 0; i < 3; i++) {
      final angle = t * math.pi * 2 + i * math.pi * 2 / 3;
      c.save();
      c.translate(math.cos(angle) * 21, -71 + math.sin(angle) * 6);
      c.rotate(angle * .4);
      c.drawPath(_star, _fill..color = _gold.withValues(alpha: fade * .9));
      c.restore();
    }
  }

  void _landing(ui.Canvas c, double t, double r, bool heavy) {
    final fade = 1 - t;
    _arc(
      c,
      r * (.22 + .7 * t),
      .08,
      math.pi * 1.88,
      _dust,
      fade * .65,
      heavy ? 2.5 : 1.5,
    );
    for (var i = 0; i < 6; i++) {
      final angle = i * 2.39996;
      final distance = r * (.16 + t * .7) * (.7 + i % 3 * .1);
      final at = ui.Offset(
        math.cos(angle) * distance,
        math.sin(angle) * distance * .55 -
            math.sin(t * math.pi) * (7 + i % 3 * 4),
      );
      _segment(
        c,
        at,
        at + ui.Offset(3 + i % 2, -2),
        _dust,
        fade * .8,
        heavy ? 2.5 : 1.8,
      );
    }
  }

  /// Use at confirmed ground contact, so landing dust begins on the impact
  /// frame rather than replaying the takeoff part of a whole leap preview.
  void paintLanding(
    ui.Canvas canvas, {
    required double progress,
    ui.Offset center = ui.Offset.zero,
    double radius = 72,
    bool heavy = false,
  }) {
    if (!progress.isFinite || progress < 0 || progress >= 1) return;
    canvas.save();
    try {
      canvas.translate(center.dx, center.dy);
      _landing(canvas, progress, _radius(radius), heavy);
    } finally {
      canvas.restore();
    }
  }

  void _recovery(ui.Canvas c, double t, double r) {
    final color = kind == BarbarianVfxKind.findPotion
        ? const ui.Color(0xffbf6654)
        : _gold;
    if (kind == BarbarianVfxKind.grimWard) {
      _arc(c, r * (.3 + t * .5), .1, math.pi * 1.8, _dust, (1 - t) * .6, 1.5);
      _segment(
        c,
        const ui.Offset(0, 7),
        const ui.Offset(0, -37),
        _dust,
        1 - t,
        3,
      );
      _segment(
        c,
        const ui.Offset(-8, -29),
        const ui.Offset(8, -29),
        _white,
        1 - t,
        2,
      );
      return;
    }
    for (var i = 0; i < 3; i++) {
      final at = ui.Offset((i - 1) * 17.0, -8 - t * (22 + i * 5));
      _segment(c, at, at - const ui.Offset(0, 6), color, (1 - t) * .8, 2);
    }
  }

  /// Draw this at each actual projectile position; [progress] rotates the axe,
  /// but never moves it or applies damage. No extra projectile is spawned.
  void paintJavelin(ui.Canvas canvas, ui.Offset center, double bearing) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(bearing);
    canvas.drawLine(
      const ui.Offset(-22, 0),
      const ui.Offset(16, 0),
      _line
        ..color = const ui.Color(0xffb88b51)
        ..strokeWidth = 3,
    );
    final tip = ui.Path()
      ..moveTo(25, 0)
      ..lineTo(12, -4)
      ..lineTo(15, 0)
      ..lineTo(12, 4)
      ..close();
    canvas.drawPath(tip, ui.Paint()..color = const ui.Color(0xffe9f4ef));
    canvas.drawLine(
      const ui.Offset(-13, -1),
      const ui.Offset(9, -1),
      _line
        ..color = const ui.Color(0xfff1c990)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  void paintThrownAxe(
    ui.Canvas canvas,
    ui.Offset center,
    double bearing,
    double progress, {
    int rank = 1,
  }) {
    if (!progress.isFinite || !bearing.isFinite) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(bearing + progress * math.pi * 4);
    _segment(
      canvas,
      const ui.Offset(0, 9),
      const ui.Offset(0, -9),
      _dust,
      .95,
      2.5,
    );
    canvas.drawPath(_axeHead, _fill..color = _steel);
    _segment(
      canvas,
      const ui.Offset(10, -6),
      const ui.Offset(5, 0),
      _white,
      .9,
      1,
    );
    canvas.restore();
  }

  /// A short physical contact at the projectile's resolved hit position.
  /// Four splinters replace an explosion; callers emit this only on a real hit.
  void paintAxeImpact(
    ui.Canvas canvas,
    ui.Offset center,
    double bearing,
    double progress,
  ) {
    if (!progress.isFinite ||
        progress < 0 ||
        progress >= 1 ||
        !bearing.isFinite) {
      return;
    }
    final fade = 1 - progress;
    for (var i = 0; i < 4; i++) {
      final angle = bearing - 1.1 + i * .7;
      final axis = ui.Offset(math.cos(angle), math.sin(angle));
      final at = center + axis * (5 + progress * (17 + i % 2 * 7));
      _segment(
        canvas,
        at,
        at + axis * (3 + fade * 4),
        i.isEven ? _steel : _dust,
        fade * .85,
        1.5,
      );
    }
  }

  /// Paint beneath the airborne actor, at the unchanged ground footprint.
  void paintAirborneShadow(
    ui.Canvas canvas,
    ui.Offset ground,
    double progress,
  ) {
    final height = barbarianAirborneHeight(kind, progress);
    final scale = 1 - height / 180;
    canvas.drawOval(
      ui.Rect.fromCenter(center: ground, width: 34 * scale, height: 12 * scale),
      _fill
        ..color = const ui.Color(
          0xff1d201a,
        ).withValues(alpha: .27 - height / 700),
    );
  }
}

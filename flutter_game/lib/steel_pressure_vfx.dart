import 'dart:math' as math;
import 'dart:ui' as ui;

/// Bounded, geometry-only weapon light. Reuse an instance for a cast: paths and
/// paints are reset, while animation comes solely from simulation progress.
class SteelPressureArt {
  static const _gold = ui.Color(0xffffbd54);
  static const _white = ui.Color(0xfffff2cc);
  static const _steel = ui.Color(0xffb8d4dc);
  static const _ember = ui.Color(0xffe36b26);
  static final _torso = ui.RRect.fromRectAndRadius(
    const ui.Rect.fromLTRB(-14, -54, 14, -10),
    const ui.Radius.circular(10),
  );
  final _fill = ui.Paint();
  final _line = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  final _ribbonPath = ui.Path(), _edge = ui.Path(), _clip = ui.Path();

  double _radius(double radius) =>
      radius.isFinite ? radius.clamp(24.0, 240.0) : 72;

  ui.Rect bounds(ui.Offset center, double radius) =>
      ui.Rect.fromCircle(center: center, radius: _radius(radius) + 32);

  bool _valid(double progress, ui.Offset center, double bearing) =>
      progress.isFinite &&
      progress >= 0 &&
      progress < 1 &&
      center.dx.isFinite &&
      center.dy.isFinite &&
      bearing.isFinite;

  void _begin(ui.Canvas canvas, ui.Offset center, double radius) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    _clip
      ..reset()
      ..fillType = ui.PathFillType.evenOdd
      ..addRect(ui.Rect.fromCircle(center: ui.Offset.zero, radius: radius + 32))
      ..addRRect(_torso);
    canvas.clipPath(_clip);
  }

  ui.Offset _ellipse(double radius, double angle, [double flat = .66]) =>
      ui.Offset(math.cos(angle) * radius, math.sin(angle) * radius * flat);

  /// Tapered swept metal, rather than a constant-width line or filled disc.
  void _ribbon(
    ui.Canvas canvas,
    double radius,
    double head,
    double sweep,
    double width,
    double alpha,
    ui.Color color, {
    double flat = .66,
  }) {
    const steps = 24;
    _ribbonPath.reset();
    _edge.reset();
    for (var i = 0; i <= steps; i++) {
      final p = i / steps;
      final w = width * math.sqrt(math.max(0, math.sin(p * math.pi)));
      final at = _ellipse(radius + w / 2, head - sweep + sweep * p, flat);
      if (i == 0) {
        _ribbonPath.moveTo(at.dx, at.dy);
        _edge.moveTo(at.dx, at.dy);
      } else {
        _ribbonPath.lineTo(at.dx, at.dy);
        _edge.lineTo(at.dx, at.dy);
      }
    }
    for (var i = steps; i >= 0; i--) {
      final p = i / steps;
      final w = width * math.sqrt(math.max(0, math.sin(p * math.pi)));
      final at = _ellipse(radius - w / 2, head - sweep + sweep * p, flat);
      _ribbonPath.lineTo(at.dx, at.dy);
    }
    _ribbonPath.close();
    final tail = _ellipse(radius, head - sweep, flat),
        tip = _ellipse(radius, head, flat);
    _fill
      ..shader = ui.Gradient.linear(
        tail,
        tip,
        [
          _ember.withValues(alpha: alpha * .10),
          color.withValues(alpha: alpha * .76),
          _white.withValues(alpha: alpha),
        ],
        const [0, .66, 1],
      )
      ..color = const ui.Color(0xffffffff);
    canvas.drawPath(_ribbonPath, _fill);
    _fill.shader = null;
    canvas.drawPath(
      _edge,
      _line
        ..color = _white.withValues(alpha: alpha * .88)
        ..strokeWidth = 1.1 + width * .075,
    );
  }

  void _sparks(
    ui.Canvas canvas,
    ui.Offset at,
    double direction,
    double t,
    double alpha,
    int count, {
    ui.Color color = _gold,
  }) {
    for (var i = 0; i < count.clamp(0, 12); i++) {
      final age = (t * 1.35 + i * .137) % 1;
      final angle = direction + math.sin(i * 2.399963) * .9;
      final axis = ui.Offset(math.cos(angle), math.sin(angle) * .7);
      final point = at + axis * (3 + age * 18);
      canvas.drawLine(
        point - axis * (3 + age * 4),
        point,
        _line
          ..color = color.withValues(alpha: alpha * (1 - age))
          ..strokeWidth = i.isEven ? 1.7 : 1.1,
      );
      if (i % 3 == 0) {
        canvas.drawCircle(
          point,
          1.2,
          _fill
            ..shader = null
            ..color = _white.withValues(alpha: alpha * (1 - age)),
        );
      }
    }
  }

  void paintWhirlwind(
    ui.Canvas canvas, {
    required double progress,
    ui.Offset center = ui.Offset.zero,
    double radius = 72,
    double bearing = 0,
    int rank = 1,
  }) {
    if (!_valid(progress, center, bearing)) return;
    final r = _radius(radius), t = progress;
    final strength = 1 + rank.clamp(1, 20) * .018;
    final alpha = math.pow(1 - t, .38).toDouble();
    final head = bearing + t * math.pi * 4 - .5;
    _begin(canvas, center, r);
    try {
      // Separate illuminated blade planes leave the middle open and readable.
      _ribbon(canvas, r * .88, head, 2.45, r * .15 * strength, alpha, _gold);
      _ribbon(
        canvas,
        r * .72,
        head + math.pi,
        2.2,
        r * .095 * strength,
        alpha * .65,
        _steel,
      );
      _ribbon(canvas, r * .97, head - .3, 1.8, r * .045, alpha * .72, _ember);
      final contact = _ellipse(r * .88, head);
      _sparks(
        canvas,
        contact,
        head + math.pi / 2,
        t,
        alpha,
        5 + rank.clamp(1, 20) ~/ 4,
      );
    } finally {
      canvas.restore();
    }
  }

  void paintStrike(
    ui.Canvas canvas, {
    required double progress,
    ui.Offset center = ui.Offset.zero,
    double radius = 72,
    double bearing = 0,
    int rank = 1,
    bool heavy = false,
    bool fierce = false,
    bool dual = false,
  }) {
    if (!_valid(progress, center, bearing)) return;
    final r = _radius(radius), t = progress;
    final weight = 1 + rank.clamp(1, 20) * .016;
    final alpha = math.pow(1 - t, .5).toDouble();
    final color = fierce ? const ui.Color(0xffff8650) : _gold;
    final head = bearing - .85 + t * 1.8;
    _begin(canvas, center, r);
    try {
      _ribbon(
        canvas,
        r * .78,
        head,
        heavy ? 2.2 : 1.8,
        r * (heavy ? .17 : .11) * weight,
        alpha,
        color,
        flat: .8,
      );
      if (dual) {
        _ribbon(
          canvas,
          r * .61,
          bearing + .85 - t * 1.8,
          -1.6,
          r * .10 * weight,
          alpha * .85,
          _steel,
          flat: .8,
        );
      }
      final at = _ellipse(r * .78, head, .8);
      _sparks(
        canvas,
        at,
        bearing,
        t,
        alpha,
        4 + rank.clamp(1, 20) ~/ 4,
        color: color,
      );
      if (heavy) {
        final axis = ui.Offset(math.cos(bearing), math.sin(bearing));
        final impact = axis * (r * .82);
        canvas.drawLine(
          impact - axis * (r * .14),
          impact + axis * 7,
          _line
            ..color = _white.withValues(alpha: alpha)
            ..strokeWidth = 3.2 * weight * (1 - t),
        );
      }
    } finally {
      canvas.restore();
    }
  }

  void paintWave(
    ui.Canvas canvas, {
    required double progress,
    ui.Offset center = ui.Offset.zero,
    double radius = 100,
    double bearing = 0,
    int rank = 1,
    ui.Color color = _gold,
    int waves = 2,
    bool directed = false,
  }) {
    if (!_valid(progress, center, bearing)) return;
    final r = _radius(radius), t = progress;
    _begin(canvas, center, r);
    try {
      for (var i = 0; i < waves.clamp(1, 3); i++) {
        final p = t * 1.3 - i * .16;
        if (p < 0 || p >= 1) continue;
        final reach = r * (.14 + .86 * (1 - math.pow(1 - p, 2)));
        final width = (3 + rank.clamp(1, 20) * .16) * (1 - p);
        final alpha = (1 - p) * .62;
        _ribbon(
          canvas,
          reach,
          directed ? bearing + .7 : math.pi * 1.94,
          directed ? 1.4 : math.pi * 1.82,
          width,
          alpha,
          color,
          flat: .64,
        );
      }
      // Short pressure cuts carry motion without turning the wave into fog.
      final count = directed ? 3 : 6;
      for (var i = 0; i < count; i++) {
        final a = directed ? bearing - .45 + i * .45 : i * math.pi / 3 + .2;
        final axis = ui.Offset(math.cos(a), math.sin(a) * .64);
        final at = axis * (r * (.26 + t * .64));
        canvas.drawLine(
          at - axis * (8 * (1 - t)),
          at,
          _line
            ..color = color.withValues(alpha: (1 - t) * .55)
            ..strokeWidth = 1.7,
        );
      }
    } finally {
      canvas.restore();
    }
  }
}

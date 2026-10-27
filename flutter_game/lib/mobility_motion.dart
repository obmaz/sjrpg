import 'dart:math' as math;
import 'dart:ui';

import 'package:bonfire/bonfire.dart'
    show GameComponent, Vector2, Vector2Extension;

import 'adventure.dart';
import 'effect_visibility.dart';
import 'world_model.dart';

/// Walks the static body corridor before selecting a free teleport landing.
/// Living enemies may occupy the corridor, but never the returned endpoint.
Offset? blinkLanding(
  AdventureWorld world,
  Offset from,
  Size body,
  double bearing,
  double range, {
  required bool Function(Rect) occupied,
}) {
  if (!bearing.isFinite ||
      !range.isFinite ||
      range <= 0 ||
      world.blocked(from & body)) {
    return null;
  }
  final direction = Offset(math.cos(bearing), math.sin(bearing));
  final steps = (range / 6).ceil();
  var previous = from;
  Offset? landing;
  for (var i = 1; i <= steps; i++) {
    final next = from + direction * math.min(range, i * 6.0);
    final stored = Vector2(next.dx, next.dy).toOffset();
    if (world.blocked(stored & body) ||
        !world.clearLine(previous, stored, body)) {
      break;
    }
    previous = stored;
    if (!occupied(stored & body)) landing = stored;
  }
  return landing != null && (landing - from).distanceSquared > 1
      ? landing
      : null;
}

/// Procedural cast rings and a short sampled wake, without moving a bitmap.
class MobilityVisual extends GameComponent with EffectVisibility {
  MobilityVisual(this.session, this.from, this.to, {this.sprinting = false})
    : revision = session.buildRevision {
    position = Vector2(from.dx, from.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final Offset from, to;
  final bool sprinting;
  final int revision;
  final _trail = <Offset>[];
  final _paint = Paint();
  double age = 0, _sampleTime = 0;
  bool finished = false;
  @override
  int get priority => 9999;
  @override
  Rect get effectBounds => sprinting
      ? Rect.fromPoints(
          _trail.isEmpty ? session.hero.body.center : _trail.first,
          session.hero.body.center,
        ).inflate(55)
      : Rect.fromPoints(from, to).inflate(70);
  @override
  void update(double dt) {
    if (finished) return;
    if (session.disposed ||
        session.defeated ||
        revision != session.buildRevision ||
        sprinting && session.hero.sprintTime <= 0) {
      finished = true;
      removeFromParent();
      return;
    }
    if (!session.active || dt <= 0) return;
    dt = math.min(.05, dt);
    age += dt;
    if (sprinting) {
      _sampleTime += dt;
      if (_sampleTime >= 1 / 30) {
        _sampleTime %= 1 / 30;
        _trail.add(session.hero.body.center);
        if (_trail.length > 12) _trail.removeAt(0);
      }
    } else if (age >= .48) {
      finished = true;
      removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (finished) return;
    super.render(canvas);
    if (sprinting) {
      for (var i = 1; i < _trail.length; i++) {
        final a = _trail[i - 1] - from, b = _trail[i] - from;
        if ((b - a).distanceSquared < 1) continue;
        _paint
          ..color = const Color(
            0xffffe39b,
          ).withValues(alpha: .2 * i / _trail.length)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + i / _trail.length;
        canvas.drawLine(
          a + const Offset(0, -4),
          b + const Offset(0, -4),
          _paint,
        );
        canvas.drawLine(a + const Offset(0, 4), b + const Offset(0, 4), _paint);
      }
      return;
    }
    final p = (age / .48).clamp(0.0, 1.0), end = to - from;
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 + (1 - p) * 2;
    for (final center in [Offset.zero, end]) {
      _paint.color = const Color(0xff9deaff).withValues(alpha: (1 - p) * .8);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: 25 + p * 70,
          height: 12 + p * 30,
        ),
        _paint,
      );
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3 + p * 2;
        final radial = Offset(math.cos(angle), math.sin(angle) * .55);
        canvas.drawLine(
          center + radial * (16 + p * 22),
          center + radial * (22 + p * 30),
          _paint,
        );
      }
    }
    _paint.style = PaintingStyle.fill;
    for (var i = 0; i < 14; i++) {
      final t = (i / 14 + p * .9).clamp(0.0, 1.0);
      final wobble = math.sin(i * 2.3 + p * 8) * (1 - p) * 8;
      final point = end * t + Offset(0, wobble);
      _paint.color = const Color(0xff87dfff).withValues(alpha: (1 - p) * .45);
      canvas.drawCircle(point, 1 + math.sin(t * math.pi) * (1 - p) * 2, _paint);
    }
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

/// Continuous flame geometry fills the time between the authored atlas frames.
/// No interpolated image layers or per-frame particle components are needed.
class FirePlume {
  static const _flightColors = [ui.Color(0xa6ed6b2c), ui.Color(0xe6ffe0a1)];
  final _paint = ui.Paint();
  final _path = ui.Path();

  void flight(
    ui.Canvas canvas,
    ui.Offset at,
    double bearing,
    double time, {
    double radius = 30,
  }) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(bearing);
    for (var i = 0; i < 2; i++) {
      final wave = math.sin(time * 25 + i * 2.1);
      final length = radius * (1.25 - i * .28 + wave * .09);
      final width = radius * (.15 - i * .045);
      final bend = math.sin(time * 32 + i * 1.9) * radius * .16;
      _path
        ..reset()
        ..moveTo(radius * .2, 0)
        ..quadraticBezierTo(-length * .45, -width + bend, -length, bend)
        ..quadraticBezierTo(-length * .5, width + bend, radius * .2, 0)
        ..close();
      _paint.color = _flightColors[i];
      canvas.drawPath(_path, _paint);
    }
    canvas.restore();
  }

  void impact(ui.Canvas canvas, ui.Offset at, double phase, double radius) {
    final t = phase.clamp(0.0, 1.0);
    final fade = (1 - t) * (1 - t);
    if (fade <= 0) return;
    final spread = radius * (.12 + .58 * (1 - math.pow(1 - t, 3)));
    for (var i = 0; i < 3; i++) {
      final angle = i * math.pi * 2 / 3 + .2;
      final pulse = math.sin(t * 21 + i * 1.7);
      final x = at.dx + math.cos(angle) * spread * .65;
      final y = at.dy + math.sin(angle) * spread * .25;
      final width = spread * (.3 + pulse * .04);
      final rise = radius * math.sin(t * math.pi) * (.16 + i % 2 * .05);
      _path
        ..reset()
        ..moveTo(x - width, y)
        ..cubicTo(
          x - width * .7,
          y - rise * .9,
          x - width * .25,
          y - rise * .3,
          x + pulse * width * .25,
          y - rise - width * .7,
        )
        ..cubicTo(
          x + width * .25,
          y - rise * .6,
          x + width,
          y - rise * .5,
          x + width,
          y,
        )
        ..close();
      _paint.color = ui.Color.fromRGBO(255, 130 + i * 15, 55, fade * .55);
      canvas.drawPath(_path, _paint);
    }
    _paint.color = ui.Color.fromRGBO(255, 230, 153, fade * .55);
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: at - ui.Offset(0, radius * t * .13),
        width: spread * .5,
        height: spread * .2,
      ),
      _paint,
    );
  }
}

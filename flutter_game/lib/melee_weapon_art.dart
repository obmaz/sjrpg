import 'dart:math' as math;
import 'dart:ui' as ui;

import 'weapon_profiles.dart';

/// Weapon trails are presentation only. Neither the timing model nor damage
/// reads these shapes, and the upright hero silhouette stays unobstructed.
void paintMeleeWeaponSwing(
  ui.Canvas canvas,
  ui.Offset center,
  WeaponComboProfile profile, {
  required double phase,
  required double bearing,
  required double reach,
  required int pose,
  required int rank,
}) {
  final t = phase.clamp(0.0, 1.0), fade = 1 - phase.clamp(0.0, 1.0);
  if (fade <= 0 || !reach.isFinite || reach <= 0) return;
  final radius = reach * .58;
  final silver = const ui.Color(0xffc9edf2),
      amber = const ui.Color(0xffffce83),
      white = const ui.Color(0xfffff5d8);
  canvas.save();
  final protection = ui.Path()
    ..fillType = ui.PathFillType.evenOdd
    ..addRect(ui.Rect.fromCircle(center: center, radius: reach + 90))
    ..addRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(center.dx - 13, center.dy - 53, 26, 43),
        const ui.Radius.circular(10),
      ),
    );
  canvas.clipPath(protection);
  canvas.translate(center.dx, center.dy);
  canvas.rotate(bearing);
  final line = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  void stroke(ui.Path path, ui.Color color, double width) {
    canvas.drawPath(
      path,
      line
        ..color = color.withValues(alpha: fade * .88)
        ..strokeWidth = width * (.3 + fade * .7),
    );
  }

  void segment(ui.Offset a, ui.Offset b, ui.Color color, double width) =>
      stroke(
        ui.Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy),
        color,
        width,
      );
  void arc(
    double r,
    double start,
    double sweep,
    ui.Color color,
    double width,
  ) => stroke(
    ui.Path()..addArc(
      ui.Rect.fromCircle(center: ui.Offset.zero, radius: r),
      start,
      sweep,
    ),
    color,
    width,
  );
  void diamond(ui.Offset p, double size, ui.Color color) => stroke(
    ui.Path()
      ..moveTo(p.dx + size, p.dy)
      ..lineTo(p.dx, p.dy + size * .6)
      ..lineTo(p.dx - size, p.dy)
      ..lineTo(p.dx, p.dy - size * .6)
      ..close(),
    color,
    1.4,
  );
  final start = pose.isOdd ? .9 - t * 1.5 : -.9 + t * .7;
  final impact = ui.Offset(reach * (.48 + t * .22), 0);
  switch (profile.effect) {
    case 'crescent':
      arc(radius, start, 1.35, silver, 5 + math.min(rank, 6) * .45);
      arc(radius - 5, start + .05, 1.05, white, 1.5);
    case 'silver-cross':
      arc(radius, start - .25, 1.8, silver, 4.5);
      arc(radius * .72, -start - 1, 1.4, white, 2);
      segment(
        ui.Offset(radius * .45, -14),
        ui.Offset(radius * 1.1, 14),
        silver,
        1.5,
      );
    case 'amber-cleave':
      for (var i = 0; i < 3; i++) {
        arc(
          radius - i * 7,
          start - .35,
          1.85 - i * .12,
          amber,
          5 - i.toDouble(),
        );
      }
    case 'iron-star':
      arc(13 + t * 27, 0, math.pi * 2, silver, 3.5);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final d = ui.Offset(math.cos(a), math.sin(a));
        segment(
          impact + d * 8,
          impact + d * (15 + t * 20),
          white,
          i.isEven ? 3 : 1.3,
        );
      }
    case 'broad-edge':
      arc(radius * 1.06, start - .45, 2.15, silver, 9);
      arc(radius * .96, start - .4, 1.9, white, 2.4);
    case 'crossed-axes':
      arc(radius, -1.3 + t * .6, 1.5, amber, 5);
      arc(radius * .78, -.2 - t * .5, 1.5, const ui.Color(0xfffff1b9), 4);
    case 'needle-thrust':
      segment(const ui.Offset(17, 0), impact * 1.6, silver, 3.5);
      diamond(impact * 1.6, 7 + t * 4, white);
    case 'rune-arc':
      arc(radius, start - .2, 1.65, const ui.Color(0xffb3caff), 4);
      for (var i = 0; i < 3; i++) {
        final a = -.65 + i * .65;
        diamond(ui.Offset(math.cos(a), math.sin(a)) * radius, 4, white);
      }
    case 'twin-moons':
      arc(radius, -1.4 + t * .65, 1.6, silver, 3.6);
      arc(radius * .8, -.15 - t * .65, 1.6, amber, 3.6);
      diamond(impact * 1.15, 4, white);
    case 'silver-lance':
      for (var i = -1; i <= 1; i++) {
        segment(
          ui.Offset(20, i * 5.0),
          ui.Offset(reach * (.68 + t * .3), i * 9.0),
          i == 0 ? white : silver,
          i == 0 ? 2.4 : 1.2,
        );
      }
    case 'draw-cut':
      stroke(
        ui.Path()
          ..moveTo(19, -radius * .72)
          ..quadraticBezierTo(reach * .92, -5, reach * .61, radius * .82),
        white,
        3.5,
      );
      arc(radius * .96, -.75 + t * .2, 1.1, silver, 1.2);
    case 'poleaxe-hook':
      segment(const ui.Offset(18, 0), impact * 1.45, amber, 2.5);
      stroke(
        ui.Path()
          ..moveTo(impact.dx * 1.45, -22)
          ..quadraticBezierTo(impact.dx * 1.8, 8, impact.dx * 1.1, 27),
        silver,
        5,
      );
    case 'earth-crack':
      for (var i = -1; i <= 1; i++) {
        stroke(
          ui.Path()
            ..moveTo(impact.dx - 9, 0)
            ..lineTo(impact.dx + 6, i * 8.0)
            ..lineTo(impact.dx + 17, i * 5.0)
            ..lineTo(impact.dx + 34 + t * 10, i * 17.0),
          amber,
          3.5,
        );
      }
      arc(radius * .6, -.65, 1.3, white, 2);
    case 'chain-orbit':
      final tip = ui.Offset(math.cos(start), math.sin(start)) * radius;
      for (var i = 1; i <= 7; i++) {
        canvas.drawCircle(
          tip * (i / 7),
          i == 7 ? 6 : 1.7,
          ui.Paint()..color = silver.withValues(alpha: fade),
        );
      }
      arc(radius, start - .4, .8, amber, 3);
    case 'jade-sweep':
      arc(radius, start - .5, 2, const ui.Color(0xffb6e2c2), 4.5);
      arc(radius * .87, start - .4, 1.75, silver, 2.3);
      arc(radius * .75, start - .25, 1.4, white, 1);
    case 'sun-hook':
      stroke(
        ui.Path()
          ..moveTo(radius * .5, -radius * .8)
          ..cubicTo(
            radius * 1.35,
            -radius * .6,
            radius * 1.25,
            radius * .8,
            radius * .25,
            radius * .8,
          ),
        amber,
        5,
      );
      arc(radius * .88, start, 1.25, white, 1.5);
  }
  canvas.restore();
}

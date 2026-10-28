import 'dart:math' as math;
import 'dart:ui' as ui;

import 'rpg_model.dart';

/// The inventory and ground drops use the same six-column equipment sheet.
abstract final class GearIconArt {
  static ui.Rect? source(ui.Image image, GearDef gear) {
    final index = gearCatalog.indexOf(gear);
    // The original sheet contains exactly 24 cells. New silhouettes are drawn
    // by paintExpanded, never sampled from a row outside the source image.
    if (index < 0 || index >= 24) return null;
    final cell = image.width / 6;
    return ui.Rect.fromLTWH(
      (index % 6) * cell,
      (index ~/ 6) * cell,
      cell,
      cell,
    );
  }

  static bool paintExpanded(ui.Canvas canvas, ui.Rect bounds, GearDef gear) {
    if (!const {
      'dualblades',
      'rapier',
      'katana',
      'halberd',
      'warhammer',
      'flail',
      'glaive',
      'falchion',
    }.contains(gear.id)) {
      return false;
    }
    final side = math.min(bounds.width, bounds.height);
    canvas.save();
    canvas.translate(bounds.center.dx, bounds.center.dy);
    canvas.scale(side / 100);
    canvas.rotate(-math.pi / 4);
    final metal = ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(-15, -35),
        const ui.Offset(15, 25),
        const [
          ui.Color(0xff4e6670),
          ui.Color(0xffeef4e9),
          ui.Color(0xffa7c8ca),
          ui.Color(0xff526970),
        ],
        const [0, .38, .53, 1],
      );
    final outline = ui.Paint()
      ..color = const ui.Color(0xff182b2c)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeJoin = ui.StrokeJoin.round;
    final gold = ui.Paint()..color = const ui.Color(0xffd1a65c);
    final shaft = ui.Paint()
      ..color = const ui.Color(0xff725039)
      ..strokeWidth = 5
      ..strokeCap = ui.StrokeCap.round;
    void shape(ui.Path path) {
      canvas.drawPath(path, outline);
      canvas.drawPath(path, metal);
    }

    void hilt({double x = 0, double y = 15, double length = 22}) {
      canvas.drawLine(ui.Offset(x, y), ui.Offset(x, y + length), shaft);
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(x - 11, y - 3, 22, 5),
          const ui.Radius.circular(2),
        ),
        gold,
      );
      canvas.drawCircle(ui.Offset(x, y + length), 4, gold);
    }

    try {
      switch (gear.id) {
        case 'dualblades':
          for (final x in [-13.0, 13.0]) {
            canvas.save();
            canvas.translate(x, x < 0 ? 3 : -3);
            canvas.rotate(x < 0 ? -.22 : .22);
            shape(
              ui.Path()
                ..moveTo(0, -37)
                ..lineTo(7, -20)
                ..lineTo(5, 12)
                ..lineTo(-5, 12)
                ..lineTo(-7, -20)
                ..close(),
            );
            hilt(y: 14, length: 17);
            canvas.restore();
          }
        case 'rapier':
          shape(
            ui.Path()
              ..moveTo(0, -43)
              ..lineTo(3, 17)
              ..lineTo(-3, 17)
              ..close(),
          );
          hilt(y: 18, length: 18);
          canvas.drawOval(
            const ui.Rect.fromLTWH(-10, 14, 20, 15),
            ui.Paint()
              ..color = const ui.Color(0xffd1a65c)
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 2.8,
          );
        case 'katana':
          shape(
            ui.Path()
              ..moveTo(8, -43)
              ..quadraticBezierTo(-7, -27, -5, 15)
              ..lineTo(2, 15)
              ..quadraticBezierTo(-1, -17, 8, -43)
              ..close(),
          );
          hilt(x: -1, y: 17, length: 24);
        case 'halberd':
          canvas.drawLine(
            const ui.Offset(0, -36),
            const ui.Offset(0, 41),
            shaft,
          );
          shape(
            ui.Path()
              ..moveTo(0, -45)
              ..lineTo(5, -25)
              ..lineTo(21, -35)
              ..quadraticBezierTo(29, -19, 13, -8)
              ..lineTo(5, -18)
              ..lineTo(-13, -13)
              ..lineTo(-5, -26)
              ..close(),
          );
        case 'warhammer':
          hilt(y: -2, length: 42);
          final head = ui.Path()
            ..addRRect(
              ui.RRect.fromRectAndRadius(
                const ui.Rect.fromLTWH(-23, -33, 46, 27),
                const ui.Radius.circular(4),
              ),
            );
          shape(head);
          canvas.drawRect(const ui.Rect.fromLTWH(-4, -32, 8, 25), gold);
        case 'flail':
          hilt(x: -3, y: 9, length: 31);
          final chain = ui.Paint()
            ..color = const ui.Color(0xff9eaead)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2;
          for (var i = 0; i < 5; i++) {
            canvas.drawOval(
              ui.Rect.fromCenter(
                center: ui.Offset(-3 + i * 3.0, 6 - i * 5.0),
                width: 6,
                height: 8,
              ),
              chain,
            );
          }
          final ball = ui.Path();
          for (var i = 0; i < 16; i++) {
            final a = i * math.pi / 8, r = i.isEven ? 18.0 : 11.0;
            final x = 11 + math.cos(a) * r, y = -29 + math.sin(a) * r;
            i == 0 ? ball.moveTo(x, y) : ball.lineTo(x, y);
          }
          shape(ball..close());
        case 'glaive':
          canvas.drawLine(
            const ui.Offset(0, -18),
            const ui.Offset(0, 42),
            shaft,
          );
          shape(
            ui.Path()
              ..moveTo(2, -45)
              ..quadraticBezierTo(30, -31, 8, -6)
              ..lineTo(-3, -11)
              ..quadraticBezierTo(10, -23, 2, -45)
              ..close(),
          );
          canvas.drawLine(
            const ui.Offset(-9, -5),
            const ui.Offset(10, -5),
            shaft
              ..color = const ui.Color(0xffd1a65c)
              ..strokeWidth = 3,
          );
        case 'falchion':
          shape(
            ui.Path()
              ..moveTo(12, -43)
              ..quadraticBezierTo(25, -14, 7, 14)
              ..lineTo(-5, 14)
              ..quadraticBezierTo(8, -12, 12, -43)
              ..close(),
          );
          hilt(y: 17, length: 21);
      }
    } finally {
      metal.shader?.dispose();
      canvas.restore();
    }
    return true;
  }
}

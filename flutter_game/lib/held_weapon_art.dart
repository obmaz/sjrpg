import 'dart:math' as math;
import 'dart:ui';

import 'rpg_model.dart';

/// Equipment is attached to the hand in world space; it is never a HUD glyph.
class HeldWeaponArt {
  static void paint(
    Canvas canvas,
    Offset feet,
    GearDef weapon,
    double bearing, {
    double? attackProgress,
    double stride = 0,
    bool offhand = false,
  }) {
    final side = math.cos(bearing) < 0 ? -1.0 : 1.0;
    final swinging = attackProgress != null;
    final hand =
        feet +
        Offset((offhand ? -side : side) * 12, -37 + math.sin(stride * 2) * 1.1);
    final sweep = swinging ? math.sin(attackProgress * math.pi) : 0.0;
    final angle = swinging
        ? bearing - 1.1 + attackProgress * 2.2
        : side > 0
        ? .65
        : math.pi - .65;
    final pole = weapon.style == 'spear' || weapon.id == 'javelin';
    final length = pole
        ? 57.0
        : weapon.id == 'greatsword'
        ? 46.0
        : 36.0;
    final width = weapon.id == 'rapier' ? 2.0 : 4.0;
    final fill = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = const Color(0xff1b2229);
    void shape(Path path, Color color) {
      canvas.drawPath(path, fill..color = color);
      canvas.drawPath(path, edge);
    }

    canvas.save();
    canvas.translate(
      hand.dx + math.cos(bearing) * sweep * 5,
      hand.dy + math.sin(bearing) * sweep * 3,
    );
    canvas.rotate(angle);
    if (pole || weapon.style == 'hammer' || weapon.style == 'axe') {
      canvas.drawLine(
        const Offset(-7, 0),
        Offset(length - 9, 0),
        Paint()
          ..color = const Color(0xff31281f)
          ..strokeWidth = 4,
      );
      canvas.drawLine(
        const Offset(-7, -.7),
        Offset(length - 9, -.7),
        Paint()
          ..color = const Color(0xffa38a60)
          ..strokeWidth = 1.3,
      );
    }
    if (weapon.style == 'axe' || weapon.id == 'throwingaxes') {
      shape(
        Path()
          ..moveTo(length - 13, -3)
          ..lineTo(length - 17, -15)
          ..quadraticBezierTo(length + 5, -13, length + 2, 5)
          ..lineTo(length - 12, 4)
          ..close(),
        const Color(0xff91a7b5),
      );
      canvas.drawLine(
        Offset(length - 13, -12),
        Offset(length + 1, -4),
        Paint()
          ..color = const Color(0xffe4edf1)
          ..strokeWidth = 1.8,
      );
    } else if (weapon.style == 'hammer') {
      final head = Rect.fromCenter(
        center: Offset(length - 8, 0),
        width: 14,
        height: 22,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(head, const Radius.circular(2)),
        fill..color = const Color(0xff63717e),
      );
      canvas.drawRect(
        Rect.fromLTWH(head.left, head.top, head.width, 4),
        fill..color = const Color(0xffb1bdc4),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(head, const Radius.circular(2)),
        edge,
      );
    } else {
      final base = pole ? length - 18 : 4.0;
      shape(
        Path()
          ..moveTo(base, -width)
          ..lineTo(length - 9, -width * .8)
          ..lineTo(length + 2, 0)
          ..lineTo(length - 9, width * .8)
          ..lineTo(base, width)
          ..close(),
        const Color(0xffb9cbd7),
      );
      shape(
        Path()
          ..moveTo(base, 0)
          ..lineTo(length + 2, 0)
          ..lineTo(length - 9, width * .8)
          ..lineTo(base, width)
          ..close(),
        const Color(0xff617786),
      );
      canvas.drawLine(
        Offset(base, -width + .4),
        Offset(length - 9, -width * .8 + .4),
        Paint()
          ..color = const Color(0xfff2f5ec)
          ..strokeWidth = 1,
      );
    }
    if (!pole) {
      canvas.drawLine(
        const Offset(2, -7),
        const Offset(2, 7),
        Paint()
          ..color = const Color(0xffd5b66e)
          ..strokeWidth = 3,
      );
      canvas.drawLine(
        const Offset(-8, 0),
        const Offset(0, 0),
        Paint()
          ..color = const Color(0xff4c3425)
          ..strokeWidth = 4,
      );
      canvas.drawCircle(
        const Offset(-9, 0),
        2.4,
        fill..color = const Color(0xffc5aa6d),
      );
    }
    // The gauntlet covers the grip and joins the steel to the actor silhouette.
    canvas.drawOval(
      const Rect.fromLTWH(-5, -4, 7, 8),
      fill..color = const Color(0xff566575),
    );
    canvas.restore();
  }
}

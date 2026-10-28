import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';

import 'adventure.dart';
import 'effect_visibility.dart';

class MountMerchant extends GameComponent with EffectVisibility {
  MountMerchant(this.session) {
    final at = session.mountMerchantAt;
    position = Vector2(at.dx - 14, at.dy - 12);
    size = Vector2(28, 24);
  }
  final Adventure session;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromLTWH(position.x - 30, position.y - 80, 90, 112);
  @override
  bool get isVisible => true;
  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final toward = session.hero.body.center - session.mountMerchantAt;
    session.art.actor(
      canvas,
      'merchant',
      const ui.Offset(14, 24),
      math.atan2(toward.dy, toward.dx),
      0,
      66,
    );
    canvas.drawCircle(
      const ui.Offset(14, -53),
      13,
      ui.Paint()..color = const ui.Color(0xee123a35),
    );
    canvas.drawCircle(
      const ui.Offset(14, -53),
      13,
      ui.Paint()
        ..color = const ui.Color(0xffc8ab6b)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.save();
    canvas.translate(3, -64);
    const MountSkillIconPainter('horse').paint(canvas, const ui.Size(22, 22));
    canvas.restore();
  }
}

/// Compact gold emblems echo the HUD artwork without covering the mount.
class MountSkillIconPainter extends CustomPainter {
  const MountSkillIconPainter(this.kind);
  final String kind;
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(math.min(size.width, size.height) / 48);
    final gold = ui.Paint()
      ..color = const ui.Color(0xffeed295)
      ..strokeWidth = 4
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..style = ui.PaintingStyle.stroke;
    final glow = ui.Paint()
      ..color = const ui.Color(0xff8bdccc)
      ..strokeWidth = 2
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;
    switch (kind) {
      case 'horse':
        canvas.drawArc(
          const ui.Rect.fromLTWH(-14, -16, 28, 32),
          -.45,
          math.pi + .9,
          false,
          gold..strokeWidth = 6,
        );
        for (final x in [-10.0, 10.0]) {
          canvas.drawLine(
            ui.Offset(x, -12),
            ui.Offset(x * 1.15, -19),
            gold..strokeWidth = 5,
          );
        }
        for (var i = 0; i < 4; i++) {
          final a = .25 + i * math.pi / 3;
          canvas.drawCircle(
            ui.Offset(math.cos(a) * 13, math.sin(a) * 14),
            1.2,
            glow..style = ui.PaintingStyle.fill,
          );
        }
        canvas.drawLine(
          const ui.Offset(-18, 16),
          const ui.Offset(15, 16),
          glow..style = ui.PaintingStyle.stroke,
        );
      case 'bicycle':
        for (final x in [-12.0, 12.0]) {
          canvas.drawCircle(ui.Offset(x, 7), 9, gold..strokeWidth = 2.5);
        }
        canvas.drawPath(
          ui.Path()
            ..moveTo(-12, 7)
            ..lineTo(-3, -7)
            ..lineTo(6, 7)
            ..lineTo(-12, 7)
            ..moveTo(-3, -7)
            ..lineTo(9, -7)
            ..lineTo(12, 7)
            ..moveTo(9, -7)
            ..lineTo(7, -14)
            ..lineTo(15, -14),
          gold..strokeWidth = 2.8,
        );
        canvas.drawLine(
          const ui.Offset(-18, -15),
          const ui.Offset(-7, -15),
          glow,
        );
      case 'motor':
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            const ui.Rect.fromLTWH(-15, -6, 24, 14),
            const ui.Radius.circular(3),
          ),
          gold,
        );
        canvas.drawLine(
          const ui.Offset(4, -3),
          const ui.Offset(21, -3),
          gold..strokeWidth = 5,
        );
        canvas.drawLine(const ui.Offset(4, 4), const ui.Offset(21, 4), gold);
        canvas.drawLine(
          const ui.Offset(-7, 8),
          const ui.Offset(-12, 17),
          gold..strokeWidth = 4,
        );
        canvas.drawLine(
          const ui.Offset(-18, -13),
          const ui.Offset(-7, -13),
          glow,
        );
        canvas.drawLine(
          const ui.Offset(-15, -18),
          const ui.Offset(-3, -18),
          glow,
        );
      default:
        canvas.drawPath(
          ui.Path()
            ..moveTo(-20, 2)
            ..lineTo(18, 2)
            ..lineTo(10, 12)
            ..lineTo(-11, 12)
            ..close(),
          gold,
        );
        canvas.drawPath(
          ui.Path()
            ..moveTo(-1, 2)
            ..lineTo(-1, -17)
            ..lineTo(12, -4)
            ..lineTo(-1, -4),
          gold..strokeWidth = 2.5,
        );
        for (final y in [17.0, 22.0]) {
          canvas.drawPath(
            ui.Path()
              ..moveTo(-18, y)
              ..quadraticBezierTo(-10, y - 5, -3, y)
              ..quadraticBezierTo(5, y + 4, 17, y),
            glow,
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MountSkillIconPainter oldDelegate) =>
      kind != oldDelegate.kind;
}

class MountSkillBadge extends StatelessWidget {
  const MountSkillBadge({
    required this.kind,
    required this.size,
    this.ammo = 0,
    this.hits = 0,
    super.key,
  });
  final String kind;
  final double size;
  final int ammo, hits;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: MountSkillIconPainter(kind)),
        if (kind == 'motor')
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xee102c29),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xffd3b572)),
              ),
              child: Text(
                '$ammo',
                style: const TextStyle(
                  color: Color(0xfff3d997),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
        if (kind == 'horse')
          Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (index) => Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < 3 - hits
                        ? const Color(0xffe7c579)
                        : const Color(0xff623b34),
                    border: Border.all(
                      color: const Color(0xffb89c63),
                      width: .7,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

import 'dart:math' as math;
import 'dart:ui';

import 'authored_settlement.dart';
import 'combat_balance.dart';
import 'sanctuary.dart';
import 'stage_content.dart';

class TownGates {
  static const lockDuration = 30.0 * CombatBalance.gameSpeed;
  static const motionDuration = .55 * CombatBalance.gameSpeed;
  double remaining = 0;
  double _motion = 0;
  bool _inside = true;
  bool get locked => remaining > 0;
  double get closure => (_motion / motionDuration).clamp(0.0, 1.0);

  void observe(bool inside) {
    if (_inside && !inside) remaining = lockDuration;
    _inside = inside;
  }

  void update(double dt, bool inside) {
    observe(inside);
    remaining = math.max(0, remaining - dt);
    _motion = (_motion + (locked ? dt : -dt)).clamp(0.0, motionDuration);
  }

  void restore(double time, {required bool inside}) {
    remaining = time.clamp(0.0, lockDuration);
    _motion = remaining > 0 ? motionDuration : 0;
    _inside = inside;
  }

  bool permits(Sanctuary sanctuary, Rect from, Rect to) =>
      !locked || sanctuary.protects(from) || !sanctuary.protects(to);

  List<(Offset, Offset)> spans(AuthoredSettlement settlement) => [
    for (final pair in const [
      (Offset(.43, .12), Offset(.57, .12)),
      (Offset(.43, .85), Offset(.58, .85)),
      (Offset(.08, .35), Offset(.075, .49)),
      (Offset(.925, .355), Offset(.93, .49)),
    ])
      (settlement.point(pair.$1), settlement.point(pair.$2)),
  ];

  void paint(Canvas canvas, AuthoredSettlement settlement, Rect view) {
    if (_motion <= 0) return;
    final t = closure, color = settlement.stage.sanctuaryColor;
    for (final (a, b) in spans(settlement)) {
      if (!Rect.fromPoints(a, b).inflate(110).overlaps(view)) continue;
      final half = (b - a) / 2;
      final normal = Offset(-half.dy, half.dx) / half.distance;
      for (final (hinge, vector) in [(a, half), (b, -half)]) {
        final end = hinge + vector * t + normal * half.distance * (1 - t);
        final path = Path()
          ..moveTo(hinge.dx, hinge.dy)
          ..lineTo(end.dx, end.dy)
          ..lineTo(end.dx, end.dy - 58)
          ..lineTo(hinge.dx, hinge.dy - 58)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xff302b24));
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xffa3916b)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        for (var i = 1; i < 6; i++) {
          final at = Offset.lerp(hinge, end, i / 6)!;
          canvas.drawLine(
            at,
            at - const Offset(0, 57),
            Paint()
              ..color = settlement.stage.usesCityArt
                  ? color
                  : const Color(0xff736047)
              ..strokeWidth = 4,
          );
        }
        canvas.drawLine(
          hinge - const Offset(0, 8),
          end - const Offset(0, 47),
          Paint()
            ..color = const Color(0xffbda374)
            ..strokeWidth = 4,
        );
      }
    }
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'player_afflictions.dart';

void paintPlayerAfflictions(
  ui.Canvas canvas,
  ui.Offset feet,
  PlayerAfflictions state,
  double time,
) {
  if (state.remaining(PlayerStatus.root) > 0) {
    final paint = ui.Paint()
      ..color = const ui.Color(0xffc6af82)
      ..strokeWidth = 1.5;
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(
        feet + ui.Offset(i * 7, -9),
        feet + ui.Offset(i * 7 - 9, 3),
        paint,
      );
      canvas.drawLine(
        feet + ui.Offset(i * 7, -9),
        feet + ui.Offset(i * 7 + 9, 3),
        paint,
      );
    }
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: feet - const ui.Offset(0, 3),
        width: 43,
        height: 20,
      ),
      paint..style = ui.PaintingStyle.stroke,
    );
  }
  if (state.frozen) {
    final paint = ui.Paint()..color = const ui.Color(0x889cdeff);
    for (var i = 0; i < 5; i++) {
      final x = feet.dx - 18 + i * 9;
      canvas.drawPath(
        ui.Path()
          ..moveTo(x - 6, feet.dy + 2)
          ..lineTo(x - 3, feet.dy - 17 - i % 2 * 12)
          ..lineTo(x + 5, feet.dy - 31 + i % 2 * 8)
          ..lineTo(x + 7, feet.dy + 2)
          ..close(),
        paint,
      );
    }
  }
  if (state.remaining(PlayerStatus.poison) > 0) {
    for (var i = 0; i < 3; i++) {
      final phase = (time * .8 + i / 3) % 1;
      canvas.drawCircle(
        feet + ui.Offset(math.sin(i * 2.4 + time) * 17, -7 - phase * 32),
        2 + (1 - phase),
        ui.Paint()
          ..color = const ui.Color(
            0xffa8dc63,
          ).withValues(alpha: (1 - phase) * .9),
      );
    }
  }
}

import 'dart:ui' as ui;

/// A small opaque marker remains readable against both foliage and bright stone.
void paintQuestMarker(
  ui.Canvas canvas,
  ui.Offset at, {
  ui.Color color = const ui.Color(0xffffd371),
  bool locked = false,
}) {
  final rect = ui.Rect.fromCenter(center: at, width: 25, height: 31);
  final path = ui.Path()
    ..addRRect(ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(8)))
    ..moveTo(at.dx - 4, rect.bottom - 1)
    ..lineTo(at.dx, rect.bottom + 5)
    ..lineTo(at.dx + 4, rect.bottom - 1)
    ..close();
  canvas.drawPath(
    path.shift(const ui.Offset(0, 2)),
    ui.Paint()..color = const ui.Color(0x88061513),
  );
  canvas.drawPath(path, ui.Paint()..color = const ui.Color(0xf219302b));
  canvas.drawPath(
    path,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color,
  );
  final ink = ui.Paint()
    ..color = color
    ..strokeWidth = 3
    ..strokeCap = ui.StrokeCap.round;
  if (locked) {
    canvas.drawLine(
      at + const ui.Offset(-4, -4),
      at + const ui.Offset(4, 4),
      ink,
    );
    canvas.drawLine(
      at + const ui.Offset(4, -4),
      at + const ui.Offset(-4, 4),
      ink,
    );
  } else {
    canvas.drawLine(
      at + const ui.Offset(0, -8),
      at + const ui.Offset(0, 1),
      ink,
    );
    canvas.drawCircle(at + const ui.Offset(0, 7), 1.9, ink);
  }
}

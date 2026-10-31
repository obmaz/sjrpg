import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'dungeon.dart';

abstract final class DungeonPainting {
  static void entrance(
    ui.Canvas c,
    ui.Image? image,
    ui.Offset feet,
    int index,
  ) {
    if (image == null) return;
    final cell = image.width / 3;
    c.drawImageRect(
      image,
      ui.Rect.fromLTWH(index % 3 * cell, index ~/ 3 * cell, cell, cell),
      ui.Rect.fromLTWH(feet.dx - 130, feet.dy - 250, 260, 260),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  static void terrain(
    ui.Canvas c,
    ui.Rect view,
    DungeonRun run,
    ui.Shader? stone,
    ui.Shader? wall,
  ) {
    final color = run.definition.color, layout = run.layout;
    c.drawRect(view, ui.Paint()..color = const ui.Color(0xff151b20));
    if (wall != null) c.drawRect(view, ui.Paint()..shader = wall);
    c.drawRect(view, ui.Paint()..color = const ui.Color(0x990b1119));
    c.drawRect(view, ui.Paint()..color = color.withValues(alpha: .08));
    layout.paintFloor(
      c,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 48
        ..color = const ui.Color(0xaa050b12),
    );
    c.save();
    c.translate(0, -4);
    layout.paintFloor(
      c,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: .22),
    );
    c.restore();
    // Opaque, identically shaded primitives form the same union as collision.
    // Drawing complex merged contours can fill their fork holes on the web.
    final paint = ui.Paint()..color = const ui.Color(0xff444849);
    if (stone != null) {
      paint.shader = stone;
      paint.colorFilter = ui.ColorFilter.matrix([
        (.82 + color.r * .18) * .58,
        0,
        0,
        0,
        0,
        0,
        (.82 + color.g * .18) * .58,
        0,
        0,
        0,
        0,
        0,
        (.82 + color.b * .18) * .58,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    layout.paintFloor(c, paint);
  }
}

class CavePortals extends GameComponent {
  CavePortals(this.session);
  final Adventure session;
  @override
  bool get isVisible => true;
  @override
  int get priority => 30;
  @override
  void render(ui.Canvas canvas) {
    final run = session.dungeon;
    final points = run == null
        ? [session.world.caveEntrance]
        : [run.layout.start, run.layout.goal];
    for (final at in points) {
      if (!gameRef.camera.visibleWorldRect.inflate(270).contains(at)) continue;
      final index = run == null
          ? CaveDefinition.forStage(session.world.stage).theme.index
          : 5;
      DungeonPainting.entrance(
        canvas,
        session.art.images['cave-entrances'],
        at,
        index,
      );
      session.art.text(
        canvas,
        run == null
            ? CaveDefinition.forStage(session.world.stage).name
            : at == run.layout.start
            ? '입구 · 나가기'
            : '출구',
        at + const ui.Offset(0, 18),
        size: 12,
      );
    }
    if (run != null && run.definition.theme == CaveTheme.bat) {
      for (var i = 0; i < 5; i++) {
        final a =
            session.hero.body.center +
            ui.Offset(180 * math.sin(session.elapsed * .3 + i), -150 + i * 12);
        final wings = 8 + 5 * math.sin(session.elapsed * 8 + i);
        canvas.drawPath(
          ui.Path()
            ..moveTo(a.dx - wings, a.dy - 5)
            ..lineTo(a.dx, a.dy + 2)
            ..lineTo(a.dx + wings, a.dy - 5)
            ..lineTo(a.dx + 4, a.dy + 5)
            ..lineTo(a.dx - 4, a.dy + 5)
            ..close(),
          ui.Paint()..color = const ui.Color(0xcc0b1018),
        );
      }
    }
  }
}

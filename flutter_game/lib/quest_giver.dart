import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'quest_marker.dart';
import 'world_model.dart';

class QuestGiver extends GameComponent {
  QuestGiver(this.session, this.giver) {
    position = Vector2(at.dx - 14, at.dy - 12);
    size = Vector2(28, 24);
  }
  final Adventure session;
  final TimeQuestGiver giver;
  ui.Offset get at => giver.atOrigin(session.world.spawn);
  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final toward = session.hero.body.center - at;
    final locked = session.timePath != null && session.timePath != giver.path;
    final color = locked
        ? const ui.Color(0xff9aaea6)
        : giver.path == TimePath.past
        ? const ui.Color(0xffffd371)
        : const ui.Color(0xff92e7f2);
    canvas.drawOval(
      const ui.Rect.fromLTWH(-2, 16, 32, 12),
      ui.Paint()..color = color.withValues(alpha: .18),
    );
    session.art.actor(
      canvas,
      giver.actor,
      const ui.Offset(14, 24),
      math.atan2(toward.dy, toward.dx),
      0,
      64,
    );
    paintQuestMarker(
      canvas,
      const ui.Offset(14, -64),
      color: color,
      locked: locked,
    );
  }
}

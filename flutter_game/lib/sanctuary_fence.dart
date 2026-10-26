import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'sanctuary.dart';
import 'stage_content.dart';

void paintSanctuaryFence(
  ui.Canvas canvas,
  WorldStage stage,
  ui.Offset a,
  ui.Offset b,
) {
  final (dark, light) = switch (stage) {
    WorldStage.forest => (
      const ui.Color(0xff30281c),
      const ui.Color(0xff9c7850),
    ),
    WorldStage.sands => (
      const ui.Color(0xff665139),
      const ui.Color(0xffd7bb7c),
    ),
    WorldStage.past => (const ui.Color(0xff414a44), const ui.Color(0xffabae94)),
    WorldStage.future => (
      const ui.Color(0xff1a313d),
      const ui.Color(0xff759ba8),
    ),
  };
  final color = stage.sanctuaryColor;
  canvas.drawLine(
    a + const ui.Offset(1, 2),
    b + const ui.Offset(1, 2),
    ui.Paint()
      ..color = const ui.Color(0x550b1713)
      ..strokeWidth = 12
      ..strokeCap = ui.StrokeCap.round,
  );
  for (final height
      in stage == WorldStage.forest || stage == WorldStage.past
          ? [8.0, 18.0]
          : [13.0]) {
    final from = a - ui.Offset(0, height), to = b - ui.Offset(0, height);
    if (stage == WorldStage.future) {
      canvas.drawLine(
        from,
        to,
        ui.Paint()
          ..color = color.withValues(alpha: .18)
          ..strokeWidth = 11,
      );
      canvas.drawLine(
        from,
        to,
        ui.Paint()
          ..color = color
          ..strokeWidth = 2.5,
      );
    } else {
      canvas.drawLine(
        from,
        to,
        ui.Paint()
          ..color = dark
          ..strokeWidth = stage == WorldStage.sands ? 4 : 7,
      );
      canvas.drawLine(
        from - const ui.Offset(0, 1),
        to - const ui.Offset(0, 1),
        ui.Paint()
          ..color = light
          ..strokeWidth = stage == WorldStage.sands ? 2 : 3.5,
      );
    }
  }
  for (final at in [a, b]) {
    canvas.drawOval(
      ui.Rect.fromCenter(center: at, width: 19, height: 8),
      ui.Paint()..color = const ui.Color(0x660d1710),
    );
    final post = ui.Rect.fromLTWH(at.dx - 5, at.dy - 27, 10, 28);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(post.inflate(1), const ui.Radius.circular(2)),
      ui.Paint()..color = dark,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(post, const ui.Radius.circular(1)),
      ui.Paint()
        ..shader = ui.Gradient.linear(post.topLeft, post.topRight, [
          light,
          dark,
        ]),
    );
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: at - const ui.Offset(0, 27),
        width: 11,
        height: 5,
      ),
      ui.Paint()..color = light,
    );
    if (stage == WorldStage.future) {
      canvas.drawLine(
        at - const ui.Offset(0, 21),
        at - const ui.Offset(0, 5),
        ui.Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        at - const ui.Offset(0, 25),
        3,
        ui.Paint()..color = color,
      );
    } else {
      for (final height in [7.0, 17.0]) {
        canvas.drawLine(
          at + ui.Offset(-3, -height),
          at + ui.Offset(3, -height + 1),
          ui.Paint()
            ..color = dark.withValues(alpha: .75)
            ..strokeWidth = 1,
        );
        if (stage == WorldStage.forest) {
          canvas.drawCircle(
            at + ui.Offset(-1, -height),
            1.2,
            ui.Paint()..color = const ui.Color(0xffd2bd82),
          );
        }
      }
      if (stage == WorldStage.forest || stage == WorldStage.past) {
        canvas.drawOval(
          ui.Rect.fromLTWH(at.dx - 7, at.dy - 1, 9, 4),
          ui.Paint()..color = const ui.Color(0xff6f8852),
        );
      }
    }
  }
}

class SanctuaryFence extends GameComponent {
  SanctuaryFence(this.section, this.stage) {
    final bounds = section.bounds;
    position = Vector2(bounds.left, bounds.top);
    size = Vector2(bounds.width, bounds.height);
  }
  final SanctuaryFenceSection section;
  final WorldStage stage;
  ui.Picture? _picture;
  @override
  int get priority => LayerPriority.getComponentPriority(
    ((section.start.dy + section.end.dy) / 2 +
            (hasGameRef ? gameRef.map.renderPriorityOffsetY : 0))
        .floor(),
  );
  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final picture = _picture ??= () {
      final recorder = ui.PictureRecorder();
      paintSanctuaryFence(
        ui.Canvas(recorder),
        stage,
        section.start - position.toOffset(),
        section.end - position.toOffset(),
      );
      return recorder.endRecording();
    }();
    canvas.drawPicture(picture);
  }

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }
}

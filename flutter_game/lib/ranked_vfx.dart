import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:bonfire/bonfire.dart';
import 'adventure.dart';
import 'game_art.dart';
import 'skill_growth.dart';

/// Extra moving fragments are added at every rank, rather than scaling a still picture.
void paintRankImpact(
  ui.Canvas canvas,
  ui.Offset at,
  double phase,
  int rank,
  ui.Color color, {
  double radius = 70,
}) {
  final r = SkillGrowth.level(rank);
  if (r <= 1) return;
  final t = phase.clamp(0.0, 1.0), fade = (1 - t) * (.25 + r * .06);
  final bright = ui.Color.lerp(
    color,
    const ui.Color(0xfffffbeb),
    (r - 1) * .12,
  )!;
  for (var i = 0; i < (r - 1) * 5; i++) {
    final angle = i * 2.39996 + .16 * math.sin(t * 7 + i);
    final distance = radius * (.2 + .75 * t) * (.65 + i % 4 * .12);
    final p =
        at +
        ui.Offset(
          math.cos(angle) * distance,
          math.sin(angle) * distance * .65 -
              math.sin(t * math.pi) * (8 + i % 3 * 9),
        );
    final d = ui.Offset(math.cos(angle), math.sin(angle) * .65) * (3 + r * .7);
    canvas.drawLine(
      p - d,
      p + d,
      ui.Paint()
        ..color = bright.withValues(alpha: fade)
        ..strokeWidth = 1 + r * .25
        ..strokeCap = ui.StrokeCap.round,
    );
    if (r >= 4 && i.isEven) {
      canvas.drawCircle(
        p,
        1.5,
        ui.Paint()..color = const ui.Color(0xfffffff1).withValues(alpha: fade),
      );
    }
  }
}

int steelWhirlwindFrame(int rank, double phase) =>
    SkillGrowth.tier(rank) * 12 +
    ((phase.clamp(0.0, .999999) * 2 % 1) * 12).floor();

void paintSteelWhirlwind(
  GameArt art,
  ui.Canvas canvas,
  ui.Offset center,
  double phase,
  int rank,
) {
  final r = SkillGrowth.level(rank), image = art.images['fx-steel-whirlwind'];
  final angle = phase * math.pi * 4;
  if (image != null) {
    final frame = steelWhirlwindFrame(r, phase),
        w = image.width / 4,
        h = image.height / 9;
    final side = 300.0 + r * 8;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(frame % 4 * w + 1, frame ~/ 4 * h + 1, w - 2, h - 2),
      ui.Rect.fromCenter(center: center, width: side, height: side * .65),
      ui.Paint()
        ..filterQuality = ui.FilterQuality.medium
        ..color = ui.Color.fromRGBO(255, 255, 255, .7 + r * .05),
    );
  }
  for (var i = 0; i < SkillGrowth.layers(r); i++) {
    final radius = 78.0 + i * 12;
    canvas.drawArc(
      ui.Rect.fromCenter(
        center: center,
        width: radius * 2,
        height: radius * 1.15,
      ),
      angle - i * 1.7,
      1.45 + r * .08,
      false,
      ui.Paint()
        ..color =
            (r >= 4 ? const ui.Color(0xffffdf9e) : const ui.Color(0xffe7f9ff))
                .withValues(alpha: .45 + r * .07)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.3 + r * .55
        ..strokeCap = ui.StrokeCap.round,
    );
  }
  paintRankImpact(
    canvas,
    center,
    phase * 2 % 1,
    r,
    const ui.Color(0xffe9c88f),
    radius: 100,
  );
}

class SteelWhirlwind extends GameComponent {
  SteelWhirlwind(
    this.session,
    this.hero, {
    required this.rank,
    required this.duration,
  }) : revision = session.buildRevision {
    position = Vector2(hero.body.center.dx, hero.body.center.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final Guardian hero;
  final int rank, revision;
  final double duration;
  double age = 0;
  bool finished = false;
  @override
  bool get isVisible => true;
  @override
  int get priority => 29;
  @override
  void update(double dt) {
    if (revision != session.buildRevision ||
        session.disposed ||
        hero.spin <= 0) {
      finished = true;
      removeFromParent();
      return;
    }
    if (!session.active) return;
    age += math.min(.05, dt);
    if (age >= duration) {
      finished = true;
      removeFromParent();
    }
    position.setValues(hero.body.center.dx, hero.body.center.dy);
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    if (finished) return;
    paintSteelWhirlwind(
      session.art,
      canvas,
      hero.body.center - position.toOffset(),
      age / duration,
      rank,
    );
  }
}

void paintGroundStrike(
  ui.Canvas canvas,
  double phase,
  int rank, {
  double bearing = 0,
  bool directional = false,
}) {
  final r = SkillGrowth.level(rank), t = phase.clamp(0.0, 1.0);
  final fade = (1 - t), length = 80 + r * 8.0;
  for (var i = 0; i < 5 + r * 2; i++) {
    final a = directional ? bearing - 1.1 + i / (4 + r * 2) * 2.2 : i * 2.39996;
    final reach = length * math.min(1, t * 4) * (.6 + i % 3 * .16);
    final axis = ui.Offset(math.cos(a), math.sin(a) * .7);
    final side = ui.Offset(-axis.dy, axis.dx) * (i.isEven ? 4 : -4);
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(axis.dx * reach * .45 + side.dx, axis.dy * reach * .45 + side.dy)
      ..lineTo(axis.dx * reach, axis.dy * reach);
    canvas.drawPath(
      path,
      ui.Paint()
        ..color = const ui.Color(0xff3d2d21).withValues(alpha: fade * .65)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2 + r * .4
        ..strokeCap = ui.StrokeCap.round,
    );
    canvas.drawPath(
      path,
      ui.Paint()
        ..color = const ui.Color(
          0xffffdda1,
        ).withValues(alpha: fade * (.3 + r * .09))
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = .8 + r * .2,
    );
    final at =
        axis * (reach * t) +
        ui.Offset(0, -math.sin(t * math.pi) * (10 + i % 3 * 9));
    canvas.drawCircle(
      at,
      1.5 + r * .3,
      ui.Paint()
        ..color = const ui.Color(0xffd8bd87).withValues(alpha: fade * .8),
    );
  }
  paintRankImpact(
    canvas,
    ui.Offset.zero,
    t,
    r,
    const ui.Color(0xffffd18b),
    radius: length,
  );
}

class GroundStrike extends GameComponent {
  GroundStrike(
    this.session,
    ui.Offset at, {
    required this.rank,
    this.tempo = 1,
    this.bearing = 0,
    this.directional = false,
  }) : revision = session.buildRevision {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final int rank, revision;
  final double tempo, bearing;
  final bool directional;
  double age = 0;
  bool finished = false;
  @override
  int get priority => 29;
  @override
  bool get isVisible => true;
  @override
  void update(double dt) {
    if (revision != session.buildRevision || session.disposed) {
      finished = true;
      removeFromParent();
      return;
    }
    if (!session.active) return;
    age += math.min(.05, dt) * tempo;
    if (age >= .42) {
      finished = true;
      removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    if (!finished) {
      paintGroundStrike(
        canvas,
        age / .42,
        rank,
        bearing: bearing,
        directional: directional,
      );
    }
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:bonfire/bonfire.dart';
import 'adventure.dart';
import 'effect_visibility.dart';
import 'game_art.dart';
import 'illustrated_combat_art.dart';
import 'skill_growth.dart';
import 'steel_pressure_vfx.dart';

/// A few short fragments mark the contact; rank refines their spread.
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
  final t = (phase * 1.35).clamp(0.0, 1.0), fade = (1 - t) * .55;
  final bright = ui.Color.lerp(color, const ui.Color(0xfffffbeb), .12)!;
  for (var i = 0; i < 2 + SkillGrowth.tier(r); i++) {
    final angle = i * 2.39996 + r * .045 + .1 * math.sin(t * 7 + i);
    final distance = radius * (.12 + .48 * t) * (.65 + i % 4 * .12);
    final p =
        at +
        ui.Offset(
          math.cos(angle) * distance,
          math.sin(angle) * distance * .65 -
              math.sin(t * math.pi) * (8 + i % 3 * 9),
        );
    final d = ui.Offset(math.cos(angle), math.sin(angle) * .65) * (3 + r * .15);
    canvas.drawLine(
      p - d,
      p + d,
      ui.Paint()
        ..color = bright.withValues(alpha: fade)
        ..strokeWidth = 1.3
        ..strokeCap = ui.StrokeCap.round,
    );
  }
}

int steelWhirlwindFrame(int rank, double phase) =>
    SkillGrowth.tier(rank) * 12 +
    ((phase.clamp(0.0, .999999) * 2 % 1) * 12).floor();

final _steelPressure = SteelPressureArt();

void paintSteelWhirlwind(
  GameArt art,
  ui.Canvas canvas,
  ui.Offset center,
  double phase,
  int rank,
) {
  _steelPressure.paintWhirlwind(
    canvas,
    center: center,
    progress: phase,
    radius: 96,
    rank: rank,
  );
  IllustratedCombatArt.sequence(
    art.effects,
    canvas,
    CombatIllustration.blade,
    center,
    progress: (phase * 7) % 1,
    radius: 102,
    bearing: phase * math.pi * 6,
    steel: true,
    protectBody: true,
  );
}

class SteelWhirlwind extends GameComponent with EffectVisibility {
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
  ui.Rect get effectBounds =>
      ui.Rect.fromCircle(center: hero.body.center, radius: 220);
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
  final fragments = 3 + SkillGrowth.tier(r);
  for (var i = 0; i < fragments; i++) {
    final a = directional
        ? bearing - .75 + i / (fragments - 1) * 1.5
        : i * 2.39996 + r * .025;
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
        ..strokeWidth = 2
        ..strokeCap = ui.StrokeCap.round,
    );
    canvas.drawPath(
      path,
      ui.Paint()
        ..color = const ui.Color(0xffffdda1).withValues(alpha: fade * .38)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final at =
        axis * (reach * t) +
        ui.Offset(0, -math.sin(t * math.pi) * (10 + i % 3 * 9));
    canvas.drawCircle(
      at,
      1.7,
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

class GroundStrike extends GameComponent with EffectVisibility {
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
  ui.Rect get effectBounds =>
      ui.Rect.fromCircle(center: position.toOffset(), radius: 170);
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

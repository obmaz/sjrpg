import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'effect_visibility.dart';
import 'game_art.dart';
import 'mage_combat_art.dart';
import 'ranked_vfx.dart';
import 'skill_growth.dart';

enum SpellClip {
  meteorFlight('fx-meteor', 0, 8, .65, ui.Offset(.28, .75)),
  meteorImpact('fx-meteor', 8, 8, .56, ui.Offset(.5, .7)),
  iceNova('fx-ice-nova', 0, 16, .72, ui.Offset(.5, .64)),
  whirlwind('fx-whirlwind', 0, 16, .5, ui.Offset(.5, .6)),
  warcry('fx-warcry', 0, 16, .64, ui.Offset(.5, .59));

  const SpellClip(
    this.asset,
    this.first,
    this.count,
    this.duration,
    this.anchor,
  );
  final String asset;
  final int first, count;
  final double duration;
  final ui.Offset anchor;

  int frameAt(double age) =>
      first + (age / duration * count).floor().clamp(0, count - 1);
  ui.Rect source(int width, int height, double age) {
    final frame = frameAt(age), w = width / 4, h = height / 4;
    // Stay inside the cell when bilinear filtering samples the transparent edge.
    return ui.Rect.fromLTWH(
      (frame % 4) * w + 1,
      (frame ~/ 4) * h + 1,
      w - 2,
      h - 2,
    );
  }
}

bool paintSpellFrame(
  GameArt art,
  ui.Canvas canvas,
  SpellClip clip,
  double age,
  ui.Offset at,
  double side, {
  double opacity = 1,
}) {
  return art.effects.draw(
    canvas,
    clip.asset,
    clip.frameAt(age),
    ui.Rect.fromLTWH(
      at.dx - side * clip.anchor.dx,
      at.dy - side * clip.anchor.dy,
      side,
      side,
    ),
    opacity: opacity,
  );
}

class SpellBurst extends GameComponent with EffectVisibility {
  SpellBurst(
    this.session,
    this.clip,
    ui.Offset at, {
    required this.radius,
    this.rank = 1,
    this.tempo = 1,
  }) : buildRevision = session.buildRevision {
    assert(clip != SpellClip.meteorFlight);
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final SpellClip clip;
  final double radius, tempo;
  final int rank;
  final int buildRevision;
  double age = 0;
  bool finished = false;
  final _mageArt = MageCombatArt();
  @override
  ui.Rect get effectBounds => ui.Rect.fromCenter(
    center: position.toOffset(),
    width: radius * 3,
    height: radius * 3.8 + 96,
  );
  @override
  bool get isVisible => true;
  @override
  int get priority => 29;
  @override
  void update(double dt) {
    if (finished) return;
    if ((clip == SpellClip.whirlwind || clip == SpellClip.warcry) &&
        buildRevision != session.buildRevision) {
      finished = true;
      removeFromParent();
      return;
    }
    if (!session.active) return;
    if (clip == SpellClip.whirlwind) {
      final center = session.hero.body.center;
      position.setValues(center.dx, center.dy);
    }
    age = math.min(clip.duration, age + math.min(.05, dt) * tempo);
    if (age >= clip.duration) {
      finished = true;
      removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    if (finished) return;
    super.render(canvas);
    canvas.save();
    if (clip == SpellClip.whirlwind) {
      final offset = session.hero.body.center - position.toOffset();
      canvas.translate(offset.dx, offset.dy);
    }
    final t = (age / clip.duration).clamp(0.0, 1.0),
        icy = clip == SpellClip.iceNova;
    final color = icy
        ? const ui.Color(0xffa5efff)
        : clip == SpellClip.whirlwind
        ? const ui.Color(0xffa8f6df)
        : const ui.Color(0xffffbf73);
    final mageContact = icy || clip == SpellClip.meteorImpact;
    if (mageContact) {
      _mageArt.impact(
        canvas,
        ui.Offset.zero,
        t,
        radius,
        icy ? MageElement.ice : MageElement.fire,
        rank,
      );
    }
    if (mageContact) {
      canvas.restore();
      return;
    }
    // A single pressure edge identifies the shout; the contact painter above
    // already owns elemental impacts, so no atlas or second ring overlaps it.
    final front = radius * (1 - math.pow(1 - t, 3));
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: front * 2,
        height: front * 1.3,
      ),
      ui.Paint()
        ..color = color.withValues(alpha: (1 - t) * .65)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    paintRankImpact(canvas, ui.Offset.zero, t, rank, color, radius: radius);
    canvas.restore();
  }
}

// Drawing only transforms this local geometry; no caller receives or mutates it.
final _iceShieldShard = ui.Path()
  ..moveTo(0, -10)
  ..lineTo(4, -2)
  ..lineTo(1, 8)
  ..lineTo(-4, 1)
  ..close();

void paintIceShield(
  ui.Canvas canvas,
  ui.Offset center,
  double time, {
  int rank = 1,
}) {
  final shell = ui.Path()
    ..moveTo(center.dx - 31, center.dy + 12)
    ..lineTo(center.dx - 39, center.dy - 10)
    ..lineTo(center.dx - 23, center.dy - 32)
    ..lineTo(center.dx, center.dy - 39)
    ..lineTo(center.dx + 23, center.dy - 32)
    ..lineTo(center.dx + 39, center.dy - 10)
    ..lineTo(center.dx + 31, center.dy + 12);
  canvas.drawPath(
    shell,
    ui.Paint()
      ..color = const ui.Color(0xff8edff4).withValues(alpha: .035)
      ..style = ui.PaintingStyle.fill,
  );
  canvas.drawPath(
    shell,
    ui.Paint()
      ..color = const ui.Color(0xffdbfaff).withValues(alpha: .36)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.1,
  );
  final shards = 3 + SkillGrowth.tier(rank);
  for (var i = 0; i < shards; i++) {
    final a = time * .65 + i * math.pi * 2 / shards + rank * .03;
    final at =
        center +
        ui.Offset(
          math.cos(a) * 35,
          math.sin(a) * 16 + math.sin(time * 3 + i) * 3,
        );
    final glint = (.5 + .5 * math.sin(time * 5 + i)).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(math.sin(a) * .28);
    canvas.drawPath(
      _iceShieldShard,
      ui.Paint()..color = ui.Color.fromRGBO(182, 226, 237, .4 + glint * .2),
    );
    canvas.drawLine(
      const ui.Offset(0, -8),
      const ui.Offset(1, 5),
      ui.Paint()
        ..color = ui.Color.fromRGBO(235, 255, 255, .4 + glint * .2)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }
}

void paintRuneWave(
  ui.Canvas canvas,
  double t,
  double radius,
  ui.Color color, {
  int rank = 1,
}) {
  paintRankImpact(canvas, ui.Offset.zero, t, rank, color, radius: radius);
  for (var wave = 0; wave < 1; wave++) {
    final life = (t - wave * .13) / (1 - wave * .13);
    if (life < 0 || life >= 1) continue;
    final r = radius * (1 - math.pow(1 - life, 2));
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: r * 2,
        height: r * 1.35,
      ),
      ui.Paint()
        ..color = color.withValues(alpha: (1 - life) * .4)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }
  final streaks = 3 + SkillGrowth.tier(rank);
  for (var i = 0; i < streaks; i++) {
    final a = i * math.pi * 2 / streaks + rank * .03,
        r = radius * (.15 + .65 * t);
    final at = ui.Offset(
      math.cos(a) * r,
      math.sin(a) * r * .675 - math.sin(t * math.pi) * (i.isEven ? 16 : 5),
    );
    final axis = ui.Offset(math.cos(a), math.sin(a) * .675);
    canvas.drawLine(
      at - axis * (1 - t) * 9,
      at,
      ui.Paint()
        ..color = color.withValues(alpha: (1 - t) * .65)
        ..strokeWidth = 1.3
        ..strokeCap = ui.StrokeCap.round,
    );
  }
}

void paintWhirlwind(ui.Canvas canvas, ui.Offset center, double phase) {
  final t = phase.clamp(0.0, 1.0), fade = math.sin(t * math.pi).clamp(0.0, 1.0);
  for (var arm = 0; arm < 3; arm++) {
    final path = ui.Path();
    final start = arm * math.pi * 2 / 3 + t * math.pi * 5;
    for (var step = 0; step <= 14; step++) {
      final f = step / 14, a = start - f * 2.2;
      final r = (50 + t * 90) * (1 - f * .38);
      final at =
          center + ui.Offset(math.cos(a) * r, math.sin(a) * r * .7 - f * 10);
      if (step == 0) {
        path.moveTo(at.dx, at.dy);
      } else {
        path.lineTo(at.dx, at.dy);
      }
    }
    final blade =
        center +
        ui.Offset(
          math.cos(start) * (50 + t * 90),
          math.sin(start) * (50 + t * 90) * .7,
        );
    final tail =
        center +
        ui.Offset(
          math.cos(start - 2.2) * (50 + t * 90) * .62,
          math.sin(start - 2.2) * (50 + t * 90) * .62 * .7 - 10,
        );
    canvas.drawPath(
      path,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          tail,
          blade,
          [
            const ui.Color(0x0077eadb),
            ui.Color.fromRGBO(190, 255, 243, fade),
            ui.Color.fromRGBO(236, 255, 242, fade),
          ],
          [0, .7, 1],
        )
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3 + 5 * fade
        ..strokeCap = ui.StrokeCap.round,
    );
    canvas.drawLine(
      blade,
      blade + ui.Offset(-math.sin(start), math.cos(start) * .7) * 18,
      ui.Paint()
        ..color = ui.Color.fromRGBO(236, 255, 242, fade)
        ..strokeWidth = 2
        ..strokeCap = ui.StrokeCap.round,
    );
  }
  for (var i = 0; i < 12; i++) {
    final a = i * 2.4 + t * 10, r = 40 + t * (70 + i % 3 * 15);
    canvas.drawCircle(
      center + ui.Offset(math.cos(a) * r, math.sin(a) * r * .7),
      1 + i % 2,
      ui.Paint()..color = ui.Color.fromRGBO(177, 239, 218, fade * .6),
    );
  }
}

void paintBattleAura(
  ui.Canvas canvas,
  ui.Offset center,
  double time, {
  bool frenzy = false,
  int rank = 1,
}) {
  final color = frenzy
      ? const ui.Color(0xffff9b65)
      : const ui.Color(0xffffd58a);
  final feet = center + const ui.Offset(0, 8);
  canvas.drawArc(
    ui.Rect.fromCenter(center: feet, width: 54, height: 18),
    .2,
    math.pi * .75,
    false,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: .25 + .05 * math.sin(time * 5)),
  );
  final embers = 2 + SkillGrowth.tier(rank);
  for (var i = 0; i < embers; i++) {
    final a = time * .7 + i * math.pi * 2 / embers + rank * .035;
    final rise = (.5 + .5 * math.sin(time * 5 + i)) * (frenzy ? 10 : 5);
    final at = feet + ui.Offset(math.cos(a) * 31, math.sin(a) * 10);
    canvas.drawLine(
      at,
      at - ui.Offset(0, 2 + rise),
      ui.Paint()
        ..color = color.withValues(alpha: .3 + .1 * math.sin(a))
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }
  if (frenzy) {
    for (var i = 0; i < 2; i++) {
      final y = -8.0 - i * 14;
      final x = (i == 0 ? -19 : 19) + math.sin(time * 7 + i * 2) * 2;
      canvas.drawLine(
        center + ui.Offset(x - 5, y + 6),
        center + ui.Offset(x + 3, y - 4),
        ui.Paint()
          ..color = color.withValues(alpha: .45)
          ..strokeWidth = 1.2
          ..strokeCap = ui.StrokeCap.round,
      );
    }
  }
}

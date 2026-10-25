import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:bonfire/bonfire.dart';
import 'adventure.dart';
import 'game_art.dart';

enum SpellClip {
  meteorFlight('fx-meteor', 0, 8, .65, ui.Offset(.28, .75)),
  meteorImpact('fx-meteor', 8, 8, .56, ui.Offset(.5, .7)),
  iceNova('fx-ice-nova', 0, 16, .72, ui.Offset(.5, .64)),
  whirlwind('fx-whirlwind', 0, 16, .5, ui.Offset(.5, .6));

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
  final image = art.images[clip.asset];
  if (image == null) return false;
  canvas.drawImageRect(
    image,
    clip.source(image.width, image.height, age),
    ui.Rect.fromLTWH(
      at.dx - side * clip.anchor.dx,
      at.dy - side * clip.anchor.dy,
      side,
      side,
    ),
    ui.Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1)),
  );
  return true;
}

class SpellBurst extends GameComponent {
  SpellBurst(this.session, this.clip, ui.Offset at, {required this.radius})
    : buildRevision = session.buildRevision {
    assert(clip != SpellClip.meteorFlight);
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final SpellClip clip;
  final double radius;
  final int buildRevision;
  double age = 0;
  bool finished = false;
  @override
  bool get isVisible => true;
  @override
  int get priority => 29;
  @override
  void update(double dt) {
    if (finished) return;
    if (clip == SpellClip.whirlwind && buildRevision != session.buildRevision) {
      finished = true;
      removeFromParent();
      return;
    }
    if (!session.active) return;
    if (clip == SpellClip.whirlwind) {
      final center = session.hero.body.center;
      position.setValues(center.dx, center.dy);
    }
    age = math.min(clip.duration, age + math.min(.05, dt));
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
        ..strokeWidth = 2 + (1 - t) * 3,
    );
    paintSpellFrame(
      session.art,
      canvas,
      clip,
      age,
      ui.Offset.zero,
      radius * 2.1,
      opacity: ((1 - t) / .22).clamp(0, .95),
    );
    // Debris has independent radial velocity and gravity, beyond the atlas shape changes.
    for (var i = 0; i < 12; i++) {
      final a = i * 2.39996, speed = radius * (.5 + (i % 4) * .16);
      final at = ui.Offset(
        math.cos(a) * speed * t,
        math.sin(a) * speed * t * .6 -
            math.sin(t * math.pi) * (22 + i % 3 * 15),
      );
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(a + t * (i.isEven ? 4 : -4));
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromCenter(
            center: ui.Offset.zero,
            width: icy ? 3 : 4,
            height: icy ? 8 : 4,
          ),
          const ui.Radius.circular(1),
        ),
        ui.Paint()..color = color.withValues(alpha: (1 - t) * .85),
      );
      canvas.restore();
    }
    canvas.restore();
  }
}

void paintIceShield(ui.Canvas canvas, ui.Offset center, double time) {
  final ring = ui.Rect.fromCenter(center: center, width: 72, height: 35);
  canvas.drawArc(
    ring,
    time * 1.7,
    math.pi * 1.3,
    false,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const ui.Color(0x7789eaff),
  );
  for (var i = 0; i < 7; i++) {
    final a = time * 1.7 + i * math.pi * 2 / 7;
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
    final shard = ui.Path()
      ..moveTo(0, -10)
      ..lineTo(4, -2)
      ..lineTo(1, 8)
      ..lineTo(-4, 1)
      ..close();
    canvas.drawPath(
      shard,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          const ui.Offset(-4, -7),
          const ui.Offset(4, 6),
          [
            ui.Color.fromRGBO(212, 251, 255, .65 + glint * .3),
            const ui.Color(0x8868bfdc),
          ],
        ),
    );
    canvas.drawLine(
      const ui.Offset(0, -8),
      const ui.Offset(1, 5),
      ui.Paint()
        ..color = ui.Color.fromRGBO(235, 255, 255, .5 + glint * .4)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }
}

void paintRuneWave(ui.Canvas canvas, double t, double radius, ui.Color color) {
  for (var wave = 0; wave < 3; wave++) {
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
        ..color = color.withValues(alpha: (1 - life) * (.7 - wave * .15))
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1 + (1 - life) * (5 - wave),
    );
  }
  for (var i = 0; i < 16; i++) {
    final a = i * math.pi / 8 + .1, r = radius * (.15 + .85 * t);
    final at = ui.Offset(
      math.cos(a) * r,
      math.sin(a) * r * .675 - math.sin(t * math.pi) * (i.isEven ? 16 : 5),
    );
    final axis = ui.Offset(math.cos(a), math.sin(a) * .675);
    canvas.drawLine(
      at - axis * (1 - t) * 18,
      at,
      ui.Paint()
        ..color = color.withValues(alpha: 1 - t)
        ..strokeWidth = 1 + (1 - t) * 2
        ..strokeCap = ui.StrokeCap.round,
    );
    canvas.drawCircle(
      at,
      (i.isEven ? 2.5 : 1.5) * (1 - t),
      ui.Paint()..color = color.withValues(alpha: 1 - t),
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
}) {
  final color = frenzy
      ? const ui.Color(0xffff9b65)
      : const ui.Color(0xffffd58a);
  final feet = center + const ui.Offset(0, 8);
  canvas.drawOval(
    ui.Rect.fromCenter(center: feet, width: 68, height: 24),
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: .35 + .15 * math.sin(time * 5)),
  );
  for (var i = 0; i < 8; i++) {
    final a = time * 1.9 + i * math.pi / 4;
    final rise = (.5 + .5 * math.sin(time * 5 + i)) * (frenzy ? 17 : 9);
    final at = feet + ui.Offset(math.cos(a) * 31, math.sin(a) * 10);
    final rune = ui.Path()
      ..moveTo(at.dx - 2, at.dy)
      ..lineTo(at.dx, at.dy - 5 - rise)
      ..lineTo(at.dx + 2, at.dy);
    canvas.drawPath(
      rune,
      ui.Paint()
        ..color = color.withValues(alpha: .45 + .25 * math.sin(a))
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }
  if (frenzy) {
    for (var i = 0; i < 3; i++) {
      final y = -8.0 - i * 14;
      final x = math.sin(time * 7 + i * 2) * 22;
      canvas.drawLine(
        center + ui.Offset(x - 5, y + 6),
        center + ui.Offset(x + 3, y - 4),
        ui.Paint()
          ..color = color.withValues(alpha: .7)
          ..strokeWidth = 1.5
          ..strokeCap = ui.StrokeCap.round,
      );
    }
  }
}

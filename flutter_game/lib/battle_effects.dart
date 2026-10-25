import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:bonfire/bonfire.dart';
import 'adventure.dart';
import 'world_model.dart';

void areaStrike(
  Adventure s,
  ui.Offset center,
  double radius,
  double damage, {
  double stun = 0,
  double slow = 0,
}) {
  for (final mob in List<HuntEnemy>.of(s.mobs)) {
    final d = mob.body.center - center;
    if (mob.combatReady &&
        !mob.isDead &&
        !mob.isRemoving &&
        d.distance < radius &&
        s.world.clearLine(center, mob.body.center, const ui.Size(3, 3))) {
      s.hit(mob, damage, d.distance > 0 ? d / d.distance * 16 : ui.Offset.zero);
      mob.stun = math.max(mob.stun, stun * (mob.boss ? .35 : 1));
      mob.slow = math.max(mob.slow, slow);
    }
  }
}

void paintCombatEffect(
  Adventure session,
  ui.Canvas canvas,
  ui.Offset center,
  int index,
  ui.Size size, {
  double opacity = 1,
}) {
  final image = session.art.images['combat-fx'];
  if (image == null) return;
  final cell = image.width / 4;
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH((index % 4) * cell, (index ~/ 4) * cell, cell, cell),
    ui.Rect.fromCenter(center: center, width: size.width, height: size.height),
    ui.Paint()
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1))
      ..filterQuality = ui.FilterQuality.medium,
  );
}

class ContactSpark extends GameComponent {
  ContactSpark(this.session, ui.Offset at) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  double age = 0;
  @override
  bool get isVisible => true;
  @override
  int get priority => 99999;
  @override
  void update(double dt) {
    if (!session.active) return;
    age += math.min(.05, dt);
    if (age >= .18) removeFromParent();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final t = (age / .18).clamp(0.0, 1.0), side = 42 + t * 18;
    paintCombatEffect(
      session,
      canvas,
      ui.Offset.zero,
      7,
      ui.Size.square(side),
      opacity: 1 - t,
    );
  }
}

class EnemySwipe extends GameComponent {
  EnemySwipe(this.session, ui.Offset at, this.strikeAngle) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final double strikeAngle;
  double age = 0;
  @override
  int get priority => 99999;
  @override
  bool get isVisible => true;
  @override
  void update(double dt) {
    if (!session.active) return;
    age += math.min(.05, dt);
    if (age >= .22) removeFromParent();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final t = (age / .22).clamp(0.0, 1.0);
    canvas.drawArc(
      ui.Rect.fromCircle(center: ui.Offset.zero, radius: 80),
      strikeAngle - .85 + t * .8,
      1.2,
      false,
      ui.Paint()
        ..color = ui.Color.fromRGBO(255, 200, 158, 1 - t)
        ..strokeWidth = 6 * (1 - t) + 1
        ..strokeCap = ui.StrokeCap.round
        ..style = ui.PaintingStyle.stroke,
    );
    paintCombatEffect(
      session,
      canvas,
      ui.Offset(math.cos(strikeAngle), math.sin(strikeAngle)) * 66,
      7,
      const ui.Size.square(52),
      opacity: 1 - t,
    );
  }
}

class ShadowBolt extends GameComponent {
  ShadowBolt(this.session, ui.Offset at, double angle, {this.damage = 8})
    : direction = ui.Offset(math.cos(angle), math.sin(angle)) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(12);
  }
  final Adventure session;
  final ui.Offset direction;
  final double damage;
  double remaining = 2;
  bool resolved = false;
  @override
  bool get isVisible => true;
  void finish() {
    resolved = true;
    removeFromParent();
  }

  @override
  void update(double dt) {
    if (!session.active || resolved) return;
    dt = math.min(dt, math.min(.05, remaining));
    remaining -= dt;
    final distance = dt * 280, steps = math.max(1, (distance / 5).ceil());
    for (var i = 0; i < steps; i++) {
      final at = position.toOffset() + direction * (distance / steps);
      if (session.world.blocked(
        ui.Rect.fromCenter(center: at, width: 6, height: 6),
      )) {
        finish();
        return;
      }
      position.setValues(at.dx, at.dy);
      if (session.hero.body.inflate(7).contains(at)) {
        session.hurtHero(damage);
        finish();
        return;
      }
    }
    if (remaining <= 0) finish();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    const tip = ui.Offset(0, -14);
    canvas.drawLine(
      tip - direction * 23,
      tip,
      ui.Paint()
        ..color = const ui.Color(0x88ef64b0)
        ..strokeWidth = 10
        ..strokeCap = ui.StrokeCap.round,
    );
    paintCombatEffect(
      session,
      canvas,
      tip,
      3,
      const ui.Size.square(40),
      opacity: (remaining / .2).clamp(0, 1),
    );
    canvas.drawCircle(tip, 4, ui.Paint()..color = const ui.Color(0xffffd2ef));
  }
}

class ArcaneBolt extends GameComponent {
  ArcaneBolt(
    this.session,
    ui.Offset at,
    double angle,
    this.damage, {
    this.element = 'fire',
    this.explosive = false,
  }) : direction = ui.Offset(math.cos(angle), math.sin(angle)) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(12);
  }
  final Adventure session;
  final ui.Offset direction;
  final double damage;
  final String element;
  final bool explosive;
  double remaining = .88;
  bool resolved = false;
  void finish() {
    resolved = true;
    removeFromParent();
  }

  ui.Color get color => element == 'ice'
      ? const ui.Color(0xffb0efff)
      : element == 'lightning'
      ? const ui.Color(0xffdbb4ff)
      : const ui.Color(0xffffb659);
  @override
  void update(double dt) {
    if (!session.active || resolved) return;
    dt = math.min(dt, math.min(.05, remaining));
    remaining -= dt;
    final distance = dt * 620, n = math.max(1, (distance / 5).ceil());
    for (var i = 0; i < n; i++) {
      final at = position.toOffset() + direction * (distance / n);
      if (session.world.blocked(
        ui.Rect.fromCenter(center: at, width: 8, height: 8),
      )) {
        finish();
        return;
      }
      position.setValues(at.dx, at.dy);
      for (final mob in List<HuntEnemy>.of(session.mobs)) {
        if (mob.combatReady &&
            !mob.isDead &&
            !mob.isRemoving &&
            mob.body.inflate(7).contains(at)) {
          session.hit(mob, damage, direction * 12);
          if (element == 'ice') mob.slow = math.max(mob.slow, 1.5);
          if (explosive) areaStrike(session, at, 85, damage * .35);
          session.game?.add(
            RuneBurst(
              session,
              at,
              color,
              radius: explosive ? 85 : 27,
              icy: element == 'ice',
            ),
          );
          finish();
          return;
        }
      }
    }
    if (remaining <= 0) finish();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final c = canvas;
    const tip = ui.Offset(0, -14);
    c.drawLine(
      tip - direction * 26,
      tip,
      ui.Paint()
        ..color = color.withValues(alpha: .3)
        ..strokeWidth = 13
        ..strokeCap = ui.StrokeCap.round,
    );
    c.drawLine(
      tip - direction * 14,
      tip,
      ui.Paint()
        ..color = color
        ..strokeWidth = 7
        ..strokeCap = ui.StrokeCap.round,
    );
    c.drawCircle(tip, 3, ui.Paint()..color = const ui.Color(0xfffff5d5));
    paintCombatEffect(
      session,
      c,
      tip,
      element == 'ice'
          ? 2
          : element == 'lightning'
          ? 3
          : 4,
      const ui.Size.square(42),
    );
  }
}

class RuneBurst extends GameComponent {
  RuneBurst(
    this.session,
    ui.Offset at,
    this.color, {
    this.radius = 160,
    this.icy = false,
  }) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final ui.Color color;
  final double radius;
  final bool icy;
  double age = 0;
  @override
  void update(double dt) {
    if (!session.active) return;
    age += math.min(.05, dt);
    if (age >= .55) removeFromParent();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final c = canvas;
    final t = (age / .55).clamp(0.0, 1.0), r = radius * (.2 + .8 * t);
    final texture = session.art.images['combat-fx'];
    if (texture != null) {
      final cell = texture.width / 4,
          index = icy
              ? 2
              : color == const ui.Color(0xffdbb4ff)
              ? 3
              : color == const ui.Color(0xffffcf81)
              ? 0
              : color == const ui.Color(0xffff9952) ||
                    color == const ui.Color(0xffffad6b) ||
                    color == const ui.Color(0xffffb659)
              ? 4
              : 7;
      c.drawImageRect(
        texture,
        ui.Rect.fromLTWH((index % 4) * cell, (index ~/ 4) * cell, cell, cell),
        ui.Rect.fromCenter(
          center: ui.Offset.zero,
          width: r * 2.4,
          height: r * 2.0,
        ),
        ui.Paint()
          ..color = ui.Color.fromRGBO(255, 255, 255, (1 - t).clamp(0, 1))
          ..filterQuality = ui.FilterQuality.medium,
      );
    }

    c.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: r * 2,
        height: r * 1.35,
      ),
      ui.Paint()
        ..color = color.withValues(alpha: (1 - t) * .7)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - t) + 1,
    );
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6,
          p = ui.Offset(math.cos(angle) * r, math.sin(angle) * r * .675);
      c.drawLine(
        p * (icy ? .6 : .86),
        p,
        ui.Paint()
          ..color = color.withValues(alpha: 1 - t)
          ..strokeWidth = icy ? 3 : 2,
      );
    }
  }
}

class WhirlwindPulse extends GameComponent {
  WhirlwindPulse(this.session, this.hero, this.damage);
  final Adventure session;
  final Guardian hero;
  final double damage;
  double age = 0;
  int pulses = 0;
  @override
  bool get isVisible => true;
  @override
  void update(double dt) {
    if (!session.active) return;
    age += math.min(.05, dt);
    if (age >= pulses * .16 && pulses < 3) {
      pulses++;
      areaStrike(session, hero.body.center, 175, damage);
    }
    if (pulses == 3) removeFromParent();
    super.update(dt);
  }
}

void chainLightning(Adventure s, ui.Offset from, double damage, int count) {
  final points = <ui.Offset>[from], visited = <HuntEnemy>{};
  for (var i = 0; i < math.min(5, count); i++) {
    final at = points.last;
    final candidates =
        s.mobs
            .where(
              (e) =>
                  e.combatReady &&
                  !e.isDead &&
                  !e.isRemoving &&
                  !visited.contains(e) &&
                  (e.body.center - at).distance < (i == 0 ? 470 : 260) &&
                  s.world.clearLine(at, e.body.center, const ui.Size(3, 3)),
            )
            .toList()
          ..sort(
            (a, b) => (a.body.center - at).distance.compareTo(
              (b.body.center - at).distance,
            ),
          );
    if (candidates.isEmpty) break;
    final target = candidates.first;
    visited.add(target);
    points.add(target.body.center);
    s.hit(target, damage * math.pow(.9, i), ui.Offset.zero);
  }
  s.game?.add(LightningTrace(s, points));
}

class LightningTrace extends GameComponent {
  LightningTrace(this.session, this.points);
  final Adventure session;
  final List<ui.Offset> points;
  double age = 0;
  @override
  bool get isVisible => true;
  @override
  int get priority => 9999;
  @override
  void update(double dt) {
    if (!session.active) return;
    age += math.min(.05, dt);
    if (age > .3) removeFromParent();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final c = canvas;
    for (var i = 1; i < points.length; i++) {
      final texture = session.art.images['combat-fx'];
      if (texture != null) {
        final cell = texture.width / 4;
        c.drawImageRect(
          texture,
          ui.Rect.fromLTWH(cell * 3, 0, cell, cell),
          ui.Rect.fromCenter(
            center: points[i] - const ui.Offset(0, 35),
            width: 125,
            height: 125,
          ),
          ui.Paint()
            ..color = ui.Color.fromRGBO(
              255,
              255,
              255,
              (1 - age / .3).clamp(0, 1),
            ),
        );
      }
      final a = points[i - 1] - const ui.Offset(0, 20),
          b = points[i] - const ui.Offset(0, 20),
          d = b - a,
          path = ui.Path()..moveTo(a.dx, a.dy);
      for (var j = 1; j <= 8; j++) {
        final p =
            ui.Offset.lerp(a, b, j / 8)! +
            (j == 8
                ? ui.Offset.zero
                : ui.Offset(-d.dy, d.dx) /
                      math.max(1, d.distance) *
                      math.sin(j * 7.0 + i) *
                      13);
        path.lineTo(p.dx, p.dy);
      }
      c.drawPath(
        path,
        ui.Paint()
          ..color = const ui.Color(0x88ad9bff)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 8,
      );
      c.drawPath(
        path,
        ui.Paint()
          ..color = const ui.Color(0xffe5f6ff)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
}

class MeteorFall extends GameComponent {
  MeteorFall(this.session, this.origin, this.target, this.damage);
  final Adventure session;
  final ui.Offset origin, target;
  final double damage;
  double age = 0;
  bool struck = false;
  @override
  bool get isVisible => true;
  @override
  int get priority => 9999;
  @override
  void update(double dt) {
    if (!session.active) return;
    age += math.min(.05, dt);
    if (age >= .65 && !struck) {
      struck = true;
      if (session.world.clearLine(origin, target, const ui.Size(3, 3))) {
        areaStrike(session, target, 175, damage);
        session.game?.add(
          RuneBurst(session, target, const ui.Color(0xffff9952), radius: 175),
        );
      }
      removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final c = canvas;
    c.drawOval(
      ui.Rect.fromCenter(center: target, width: 280, height: 180),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const ui.Color(0xaaffab59),
    );
    final p = target + ui.Offset(70 * (1 - age / .65), -330 * (1 - age / .65));
    c.drawLine(
      p - const ui.Offset(-24, 90),
      p,
      ui.Paint()
        ..strokeWidth = 23
        ..strokeCap = ui.StrokeCap.round
        ..color = const ui.Color(0x88ff973d),
    );
    paintCombatEffect(session, c, p, 4, const ui.Size(130, 150));
    c.drawCircle(p, 7, ui.Paint()..color = const ui.Color(0xffffe7ba));
  }
}

class GroundLoot extends GameComponent {
  GroundLoot(this.session, this.item, ui.Offset at) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(20);
  }
  final Adventure session;
  final Gear item;
  double age = 0;
  bool collected = false, warned = false;
  void tryCollect() {
    if (collected ||
        isRemoving ||
        !session.active ||
        (session.hero.body.center - position.toOffset()).distance > 85 ||
        !session.world.clearLine(
          session.hero.body.center,
          position.toOffset(),
          const ui.Size(3, 3),
        )) {
      return;
    }
    final p = session.progress, goldBefore = p.gold;
    final added = p.collect(item);
    if (!added && p.gold == goldBefore) {
      if (!warned) {
        warned = true;
        session.announce('가방이 가득 찼습니다 · 가방에서 장비를 판매하세요');
      }
      return;
    }
    collected = true;
    session.bubble(
      added ? item.name : '+${p.gold - goldBefore} 골드',
      position.toOffset() - const ui.Offset(0, 55),
      ui.Color(item.rarity.color),
    );
    session.refresh();
    removeFromParent();
  }

  @override
  void update(double dt) {
    if (!session.active) return;
    age += math.min(.05, dt);
    if (age > 150) removeFromParent();
    super.update(dt);
  }

  @override
  void onRemove() {
    session.loot.remove(this);
    super.onRemove();
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final c = canvas;
    final color = ui.Color(item.rarity.color);
    c.drawOval(
      const ui.Rect.fromLTWH(-12, -3, 24, 10),
      ui.Paint()..color = color.withValues(alpha: .3),
    );
    if (item.rarity != Rarity.common) {
      c.drawRect(
        const ui.Rect.fromLTWH(-3, -46, 6, 46),
        ui.Paint()
          ..shader = ui.Gradient.linear(
            const ui.Offset(0, -46),
            ui.Offset.zero,
            [color.withValues(alpha: 0), color.withValues(alpha: .6)],
          ),
      );
    }
    c.save();
    c.rotate(math.pi / 4);
    c.drawRect(
      const ui.Rect.fromLTWH(-5, -5, 10, 10),
      ui.Paint()..color = color,
    );
    c.restore();
  }
}

class StageLandmarks extends GameComponent {
  StageLandmarks(this.session);
  final Adventure session;
  @override
  bool get isVisible => true;
  @override
  int get priority => 22;
  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final c = canvas;
    final view = gameRef.camera.visibleWorldRect.inflate(120);
    for (final exit in stageExits) {
      final at = ui.Offset(exit.x, exit.y);
      if (!view.contains(at)) continue;
      c.save();
      c.translate(at.dx, at.dy);
      final color = session.progress.bossDefeated
          ? const ui.Color(0xffa4e8ea)
          : const ui.Color(0xffb4a68b);
      c.drawOval(
        const ui.Rect.fromLTWH(-42, -14, 84, 28),
        ui.Paint()..color = const ui.Color(0xff384e48),
      );
      c.drawOval(
        const ui.Rect.fromLTWH(-30, -76, 60, 80),
        ui.Paint()
          ..shader = ui.Gradient.radial(const ui.Offset(0, -34), 44, [
            color.withValues(alpha: .5),
            const ui.Color(0x003b7878),
          ]),
      );
      c.drawArc(
        const ui.Rect.fromLTWH(-34, -80, 68, 86),
        math.pi,
        math.pi,
        false,
        ui.Paint()
          ..color = color
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 9,
      );
      c.drawLine(
        const ui.Offset(-34, -38),
        const ui.Offset(-34, 0),
        ui.Paint()
          ..color = color
          ..strokeWidth = 9,
      );
      c.drawLine(
        const ui.Offset(34, -38),
        const ui.Offset(34, 0),
        ui.Paint()
          ..color = color
          ..strokeWidth = 9,
      );
      session.art.text(
        c,
        '${exit.direction} · ${exit.destination}',
        const ui.Offset(0, -110),
        size: 14,
      );
      c.restore();
    }
    for (var i = 0; i < Adventure.chestLocations.length; i++) {
      final at = Adventure.chestLocations[i];
      if (!view.contains(at)) continue;
      final opened = session.openedChests.contains(i);
      c.save();
      c.translate(at.dx, at.dy);
      c.drawOval(
        const ui.Rect.fromLTWH(-25, 3, 50, 14),
        ui.Paint()..color = const ui.Color(0x550a201a),
      );
      final image = session.art.images['world-forest']!, cell = image.width / 4;
      c.drawImageRect(
        image,
        ui.Rect.fromLTWH(cell * 3, cell * 2, cell, cell),
        const ui.Rect.fromLTWH(-38, -58, 76, 76),
        ui.Paint()
          ..color = opened
              ? const ui.Color(0xff8b8b8b)
              : const ui.Color(0xffffffff),
      );
      if (opened) {
        c.drawOval(
          const ui.Rect.fromLTWH(-19, -30, 38, 12),
          ui.Paint()..color = const ui.Color(0xaa1b241b),
        );
      }
      c.restore();
    }
  }
}

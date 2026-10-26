import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'audio_settings.dart';
import 'boss_attacks.dart';
import 'device_settings.dart';
import 'ranked_vfx.dart';
import 'spell_vfx.dart';
import 'world_model.dart';

void areaStrike(
  Adventure s,
  ui.Offset center,
  double radius,
  double damage, {
  double stun = 0,
  double slow = 0,
  int maxTargets = 3,
  Set<HuntEnemy>? castTargets,
  Set<HuntEnemy> excluded = const {},
}) {
  if (maxTargets <= 0) return;
  final targets = castTargets ?? <HuntEnemy>{};
  final candidates =
      s.mobs
          .where(
            (mob) =>
                mob.combatReady &&
                !mob.isDead &&
                !mob.isRemoving &&
                !excluded.contains(mob) &&
                (mob.body.center - center).distance < radius &&
                s.world.clearLine(center, mob.body.center, const ui.Size(3, 3)),
          )
          .toList()
        ..sort((a, b) {
          final order = (a.body.center - center).distance.compareTo(
            (b.body.center - center).distance,
          );
          return order != 0
              ? order
              : s.mobs.indexOf(a).compareTo(s.mobs.indexOf(b));
        });
  for (final mob in candidates) {
    if (!targets.contains(mob)) {
      if (targets.length >= maxTargets) continue;
      targets.add(mob);
    }
    final d = mob.body.center - center;
    s.hit(mob, damage, d.distance > 0 ? d / d.distance * 16 : ui.Offset.zero);
    mob.stun = math.max(mob.stun, stun * (mob.boss ? .35 : 1));
    mob.slow = math.max(mob.slow, slow);
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
  ContactSpark(
    this.session,
    ui.Offset at, {
    this.heavy = false,
    this.rank = 1,
    this.bearing = 0,
  }) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final bool heavy;
  final int rank;
  final double bearing;
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
    final t = (age / .18).clamp(0.0, 1.0), reach = (heavy ? 38 : 26) * t;
    paintRankImpact(
      canvas,
      ui.Offset.zero,
      t,
      rank,
      const ui.Color(0xffffdca1),
      radius: heavy ? 65 : 40,
    );
    for (var i = 0; i < 8; i++) {
      final a = bearing + (i < 5 ? (i - 2) * .48 : i * math.pi / 4);
      final axis = ui.Offset(math.cos(a), math.sin(a) * .75);
      canvas.drawLine(
        axis * reach * .45,
        axis * (reach + (1 - t) * 10),
        ui.Paint()
          ..color = ui.Color.fromRGBO(255, 228, 165, 1 - t)
          ..strokeWidth = (heavy ? 3 : 2) * (1 - t) + .5
          ..strokeCap = ui.StrokeCap.round,
      );
      canvas.drawCircle(
        axis * (reach * 1.2) + ui.Offset(0, 12 * t * t),
        1.5 * (1 - t),
        ui.Paint()..color = ui.Color.fromRGBO(255, 247, 217, 1 - t),
      );
    }
    canvas.drawCircle(
      ui.Offset.zero,
      (heavy ? 7 : 4) * (1 - t),
      ui.Paint()..color = ui.Color.fromRGBO(255, 251, 226, 1 - t),
    );
    if (t < .3) {
      final flash = 1 - t / .3;
      for (final angle in [bearing + .65, bearing - .65]) {
        final axis = ui.Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          -axis * (heavy ? 16 : 10) * flash,
          axis * (heavy ? 16 : 10) * flash,
          ui.Paint()
            ..color = ui.Color.fromRGBO(255, 255, 240, flash)
            ..strokeWidth = heavy ? 3 : 2
            ..strokeCap = ui.StrokeCap.round,
        );
      }
    }
  }
}

class EnemySwipe extends GameComponent {
  EnemySwipe(
    this.session,
    ui.Offset at,
    this.strikeAngle, {
    this.radius = 80,
    this.halfAngle = .85,
  }) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final double strikeAngle, radius, halfAngle;
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
      ui.Rect.fromCircle(center: ui.Offset.zero, radius: radius),
      strikeAngle - halfAngle + t * .8,
      halfAngle * 1.4,
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
      ui.Offset(math.cos(strikeAngle), math.sin(strikeAngle)) * (radius * .825),
      7,
      const ui.Size.square(52),
      opacity: 1 - t,
    );
  }
}

class ShadowBolt extends GameComponent {
  ShadowBolt(
    this.session,
    ui.Offset at,
    double angle, {
    this.damage = 8,
    this.technological = false,
    this.venomous = false,
  }) : direction = ui.Offset(math.cos(angle), math.sin(angle)) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(12);
  }
  final Adventure session;
  final ui.Offset direction;
  final double damage;
  final bool technological, venomous;
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
    final distance = dt * (technological ? 320 : 280),
        steps = math.max(1, (distance / 5).ceil());
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
    if (venomous) {
      canvas.drawLine(
        tip - direction * 28,
        tip,
        ui.Paint()
          ..color = const ui.Color(0x88acd959)
          ..strokeWidth = 9
          ..strokeCap = ui.StrokeCap.round,
      );
      canvas.drawCircle(tip, 5, ui.Paint()..color = const ui.Color(0xffd0f48a));
      return;
    }
    if (technological) {
      final pulse = .7 + .3 * math.sin(remaining * 40);
      canvas.drawLine(
        tip - direction * 32,
        tip,
        ui.Paint()
          ..color = const ui.Color(0xff45cde0).withValues(alpha: .45 * pulse)
          ..strokeWidth = 12
          ..strokeCap = ui.StrokeCap.round,
      );
      canvas.drawLine(
        tip - direction * 24,
        tip,
        ui.Paint()
          ..color = const ui.Color(0xffcefcff)
          ..strokeWidth = 3
          ..strokeCap = ui.StrokeCap.round,
      );
      canvas.drawCircle(tip, 4, ui.Paint()..color = const ui.Color(0xffecffff));
      return;
    }
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
    this.launchDelay = 0,
    this.caster,
    this.rank = 1,
    int? targetLimit,
  }) : targetLimit = targetLimit ?? (explosive ? 3 : 1),
       direction = ui.Offset(math.cos(angle), math.sin(angle)),
       buildRevision = session.buildRevision {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(12);
  }
  final Adventure session;
  final ui.Offset direction;
  final double damage;
  final String element;
  final bool explosive;
  final Guardian? caster;
  double launchDelay;
  final int targetLimit, rank;
  final int buildRevision;
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
    if (buildRevision != session.buildRevision) {
      finish();
      return;
    }
    if (!session.active || resolved) return;
    dt = math.min(dt, .05);
    if (launchDelay > 0) {
      if (caster != null && (caster!.dashing > 0 || session.riding != null)) {
        finish();
        return;
      }
      if (caster != null) {
        position.setValues(caster!.body.center.dx, caster!.body.center.dy);
      }
      final waiting = math.min(dt, launchDelay);
      launchDelay -= waiting;
      dt -= waiting;
      if (dt <= 0) return;
    }
    dt = math.min(dt, remaining);
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
          if (explosive) {
            areaStrike(
              session,
              at,
              85,
              damage * .35,
              maxTargets: targetLimit - 1,
              excluded: {mob},
            );
          }
          session.game?.add(
            element == 'lightning'
                ? RuneBurst(
                    session,
                    at,
                    color,
                    radius: explosive ? 85 : 27,
                    rank: rank,
                  )
                : SpellBurst(
                    session,
                    element == 'ice'
                        ? SpellClip.iceNova
                        : SpellClip.meteorImpact,
                    at,
                    radius: explosive ? 85 : 30,
                    rank: rank,
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
    if (launchDelay > 0 || resolved) return;
    super.render(canvas);
    final c = canvas;
    const tip = ui.Offset(0, -14);
    paintRankImpact(
      c,
      tip,
      ((.88 - remaining) * 6) % 1,
      rank,
      color,
      radius: 16 + rank * 2,
    );
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
    final age = .88 - remaining;
    c.save();
    c.translate(tip.dx, tip.dy);
    if (element == 'fire') {
      c.rotate(math.atan2(direction.dy, direction.dx) - math.pi * .75);
      paintSpellFrame(
        session.art,
        c,
        SpellClip.meteorFlight,
        age % .65,
        ui.Offset.zero,
        72,
      );
    } else if (element == 'ice') {
      c.rotate(math.atan2(direction.dy, direction.dx));
      final shard = ui.Path()
        ..moveTo(13, 0)
        ..lineTo(-5, -6)
        ..lineTo(-10, 0)
        ..lineTo(-5, 6)
        ..close();
      c.drawPath(
        shard,
        ui.Paint()
          ..shader = ui.Gradient.linear(
            const ui.Offset(-10, -5),
            const ui.Offset(12, 5),
            [
              const ui.Color(0xff4eafd3),
              ui.Color.fromRGBO(227, 255, 255, .8 + math.sin(age * 35) * .15),
            ],
          ),
      );
      for (var i = 0; i < 3; i++) {
        final x = -10.0 - i * 8;
        c.drawCircle(
          ui.Offset(x, math.sin(age * 35 - i) * (4 + i)),
          1.6,
          ui.Paint()..color = color,
        );
      }
    } else {
      final path = ui.Path()..moveTo(-direction.dx * 28, -direction.dy * 28);
      final side = ui.Offset(-direction.dy, direction.dx);
      for (var i = 1; i <= 5; i++) {
        final at =
            direction * (-28 + i * 7) + side * math.sin(age * 90 + i * 2) * 6;
        path.lineTo(at.dx, at.dy);
      }
      c.drawPath(
        path,
        ui.Paint()
          ..color = color
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    c.restore();
  }
}

class RuneBurst extends GameComponent {
  RuneBurst(
    this.session,
    ui.Offset at,
    this.color, {
    this.radius = 160,
    this.rank = 1,
    this.tempo = 1,
  }) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final ui.Color color;
  final double radius, tempo;
  final int rank;
  double age = 0;
  @override
  void update(double dt) {
    if (!session.active) return;
    age += math.min(.05, dt) * tempo;
    if (age >= .55) removeFromParent();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    paintRuneWave(
      canvas,
      (age / .55).clamp(0.0, 1.0),
      radius,
      color,
      rank: rank,
    );
  }
}

class WhirlwindPulse extends GameComponent {
  WhirlwindPulse(
    this.session,
    this.hero,
    this.damage, {
    this.targetLimit = 3,
    this.duration = .5,
    this.rank = 1,
  }) : buildRevision = session.buildRevision;
  final Adventure session;
  final Guardian hero;
  final double damage;
  final int targetLimit, rank;
  final double duration;
  final targets = <HuntEnemy>{};
  final int buildRevision;
  double age = 0;
  int pulses = 0;
  @override
  bool get isVisible => true;
  @override
  void update(double dt) {
    if (buildRevision != session.buildRevision) {
      removeFromParent();
      return;
    }
    if (!session.active) return;
    age += math.min(.05, dt);
    if (age >= pulses * duration / 3 && pulses < 3) {
      pulses++;
      areaStrike(
        session,
        hero.body.center,
        175,
        damage,
        maxTargets: targetLimit,
        castTargets: targets,
      );
      for (final mob in targets) {
        if (!mob.isDead &&
            (mob.body.center - hero.body.center).distance < 180) {
          session.game?.add(
            ContactSpark(
              session,
              mob.body.center - const ui.Offset(0, 25),
              rank: rank,
              heavy: rank >= 3,
            ),
          );
        }
      }
      if (targets.isNotEmpty) session.kickCamera(.35 + rank * .08);
    }
    if (pulses == 3) removeFromParent();
    super.update(dt);
  }
}

void chainLightning(
  Adventure s,
  ui.Offset from,
  double damage,
  int count, {
  int rank = 1,
}) {
  final points = <ui.Offset>[from], visited = <HuntEnemy>{};
  for (var i = 0; i < count.clamp(0, 32); i++) {
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
  s.game?.add(LightningTrace(s, points, rank: rank));
}

class LightningTrace extends GameComponent {
  LightningTrace(this.session, this.points, {this.rank = 1});
  final Adventure session;
  final List<ui.Offset> points;
  final int rank;
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
      paintRankImpact(
        c,
        points[i] - const ui.Offset(0, 20),
        age / .3,
        rank,
        const ui.Color(0xffb1dfff),
        radius: 35 + rank * 3,
      );
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
                      math.sin(j * 7.0 + i + age * 90) *
                      13);
        path.lineTo(p.dx, p.dy);
      }
      for (var branch = 0; branch < rank - 1; branch++) {
        final mid = ui.Offset.lerp(a, b, .5 + branch * .09)!;
        final end =
            mid +
            ui.Offset(
                  math.cos(age * 65 + branch * 2.4),
                  math.sin(age * 65 + branch * 2.4),
                ) *
                (12 + rank * 4);
        c.drawLine(
          mid,
          end,
          ui.Paint()
            ..color = const ui.Color(
              0xffb9dbff,
            ).withValues(alpha: (1 - age / .3).clamp(0, 1))
            ..strokeWidth = 1.2 + rank * .2,
        );
      }
      c.drawPath(
        path,
        ui.Paint()
          ..color = const ui.Color(0x88ad9bff)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 7 + rank * 1.2,
      );
      c.drawPath(
        path,
        ui.Paint()
          ..color = const ui.Color(0xffe5f6ff)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.8 + rank * .25,
      );
    }
  }
}

class MeteorFall extends GameComponent {
  MeteorFall(
    this.session,
    this.origin,
    this.target,
    this.damage, {
    this.targetLimit = 3,
    this.rank = 1,
    this.tempo = 1,
  }) : buildRevision = session.buildRevision;
  final Adventure session;
  final ui.Offset origin, target;
  final double damage;
  final int targetLimit, rank;
  final double tempo;
  final int buildRevision;
  double age = 0;
  bool struck = false;
  @override
  bool get isVisible => true;
  @override
  int get priority => 9999;
  @override
  void update(double dt) {
    if (buildRevision != session.buildRevision) {
      struck = true;
      removeFromParent();
      return;
    }
    if (!session.active) return;
    age += math.min(.05, dt);
    if (age >= .65 / tempo && !struck) {
      struck = true;
      if (session.world.clearLine(origin, target, const ui.Size(3, 3))) {
        session.kickCamera(1.5);
        session.audio.play(EffectSound.fire);
        session.device.pulse(FeedbackKind.skill);
        areaStrike(session, target, 175, damage, maxTargets: targetLimit);
        session.game?.add(
          SpellBurst(
            session,
            SpellClip.meteorImpact,
            target,
            radius: 175,
            rank: rank,
            tempo: tempo,
          ),
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
    final t = (age * tempo / .65).clamp(0.0, 1.0), fall = t * t;
    paintRankImpact(c, target, t, rank, const ui.Color(0xffffc578), radius: 85);
    final p = target + ui.Offset(110 * (1 - fall), -360 * (1 - fall));
    c.drawOval(
      ui.Rect.fromCenter(
        center: target,
        width: 35 + t * 65,
        height: 18 + t * 30,
      ),
      ui.Paint()..color = ui.Color.fromRGBO(255, 160, 70, .1 + t * .25),
    );
    for (var i = 0; i < 7 + (rank - 1) * 2; i++) {
      final lag = (age * 2.6 + i * .13) % 1;
      final at =
          p +
          ui.Offset(
            20 + lag * 65,
            -35 - lag * 135 + math.sin(age * 40 + i) * 7,
          );
      c.drawCircle(
        at,
        1 + (1 - lag) * 2,
        ui.Paint()..color = ui.Color.fromRGBO(255, 195, 101, (1 - lag) * .7),
      );
    }
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(-.49);
    paintSpellFrame(
      session.art,
      c,
      SpellClip.meteorFlight,
      age * tempo,
      ui.Offset.zero,
      170 + (rank - 1) * 8,
    );
    c.restore();
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
    session.audio.play(EffectSound.loot);
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
    for (final mount in session.mounts) {
      if (identical(mount, session.riding) || !view.contains(mount.at)) {
        continue;
      }
      session.art.actor(
        c,
        mount.def.artKey,
        mount.at + ui.Offset(0, mount.def.bodySize.height / 2),
        mount.bearing,
        0,
        mount.def.waterOnly ? 48 : 62,
      );
    }
    final marked = session.visibleSites.map((site) => site.id).toSet();
    for (final site in session.world.sites) {
      if (!view.inflate(100).contains(site.at)) continue;
      if (session.world.stage == WorldStage.future) {
        session.art.cityProp(
          c,
          site.artIndex,
          site.at - const ui.Offset(0, 18),
          156,
        );
      } else {
        session.art.landmark(
          c,
          site.artIndex,
          site.at - const ui.Offset(0, 18),
          144,
          themed: session.world.stage != WorldStage.forest,
        );
      }
      if (!marked.contains(site.id)) continue;
      final done = session.cleansedSites.contains(site.id);
      c.drawOval(
        ui.Rect.fromCenter(
          center: site.at - const ui.Offset(0, 2),
          width: 72,
          height: 28,
        ),
        ui.Paint()
          ..color = site.color.withValues(alpha: done ? .5 : .18)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      session.art.text(
        c,
        done
            ? '✓'
            : session.world.stage == WorldStage.sands &&
                  session.acceptedCommission != site.id
            ? '?'
            : '!',
        site.at - const ui.Offset(0, 148),
        size: 21,
        color: site.color,
      );
    }

    for (var i = 0; i < session.stageChestLocations.length; i++) {
      final at = session.stageChestLocations[i];
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

class BossAttackVisual extends GameComponent {
  BossAttackVisual(
    this.session,
    this.source,
    this.pattern, {
    this.impact = false,
  }) {
    position = Vector2.zero();
    size = Vector2(worldSize.width, worldSize.height);
  }
  final Adventure session;
  final HuntEnemy source;
  final BossAttack pattern;
  final bool impact;
  double age = 0;
  bool get validWarning =>
      !source.isDead &&
      !source.isRemoving &&
      identical(source.bossAttack, pattern);
  @override
  int get priority => 29;
  @override
  bool get isVisible => true;
  @override
  void update(double dt) {
    if (session.disposed || !impact && !validWarning) {
      removeFromParent();
      return;
    }
    if (!session.active) return;
    if (impact) {
      age += math.min(.05, dt);
      if (age >= .5) removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (session.disposed) return;
    if (impact) {
      pattern.paintImpact(canvas, age / .5);
    } else if (validWarning) {
      pattern.paintWarning(canvas, 1 - source.windup / pattern.warningTime);
    }
  }
}

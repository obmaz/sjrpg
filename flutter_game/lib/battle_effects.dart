import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'area_damage.dart';
import 'audio_settings.dart';
import 'boss_attacks.dart';
import 'combat_feedback.dart';
import 'device_settings.dart';
import 'effect_visibility.dart';
import 'fire_plume.dart';
import 'gear_icon_art.dart';
import 'mage_combat_art.dart';
import 'player_afflictions.dart';
import 'ranked_vfx.dart';
import 'spell_vfx.dart';
import 'world_model.dart';

List<HuntEnemy> _areaTargets(
  Adventure s,
  ui.Offset center,
  double radius, {
  required int maxTargets,
  Set<HuntEnemy>? castTargets,
  Set<int>? castChests,
  Set<HuntEnemy> excluded = const {},
}) {
  if (maxTargets <= 0 || !s.combatAllowed) return [];
  final targets = castTargets ?? <HuntEnemy>{};
  final candidates =
      s.mobs
          .where(
            (mob) =>
                s.canHitEnemy(mob, origin: center) &&
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
  final selected = <HuntEnemy>[];
  for (final mob in candidates) {
    if (!targets.contains(mob)) {
      if (targets.length + (castChests?.length ?? 0) >= maxTargets) continue;
      targets.add(mob);
    }
    selected.add(mob);
  }
  return selected;
}

// The caller chooses a whole eligible group before applying one shared scale.
// In particular, projectile direct hits and their splash share this multiplier.
void _damageAreaTargets(
  Adventure s,
  List<HuntEnemy> targets,
  ui.Offset center,
  double damage, {
  required double multiplier,
  ImpactKind? impactKind,
  int impactRank = 1,
  double stun = 0,
  double slow = 0,
}) {
  for (final mob in targets) {
    final d = mob.body.center - center;
    if (!s.hit(
      mob,
      damage * multiplier,
      d.distance > 0 ? d / d.distance * 16 : ui.Offset.zero,
      origin: center,
      impactKind: impactKind,
      impactRank: impactRank,
    )) {
      continue;
    }
    mob.applyStun(stun);
    mob.slow = math.max(mob.slow, slow);
  }
}

void _areaChests(
  Adventure s,
  ui.Offset center,
  double radius,
  int remaining, {
  Set<int>? castChests,
}) {
  for (final index in s.attackableChests(center, radius)) {
    if (remaining <= 0) break;
    if (s.breakChest(index)) {
      castChests?.add(index);
      remaining--;
    }
  }
}

void areaStrike(
  Adventure s,
  ui.Offset center,
  double radius,
  double damage, {
  double stun = 0,
  double slow = 0,
  int maxTargets = 3,
  Set<HuntEnemy>? castTargets,
  Set<int>? castChests,
  Set<HuntEnemy> excluded = const {},
  ImpactKind? impactKind,
  int impactRank = 1,
}) {
  if (maxTargets <= 0 || !s.combatAllowed) return;
  final targets = castTargets ?? <HuntEnemy>{};
  final selected = _areaTargets(
    s,
    center,
    radius,
    maxTargets: maxTargets,
    castTargets: targets,
    castChests: castChests,
    excluded: excluded,
  );
  _damageAreaTargets(
    s,
    selected,
    center,
    damage,
    multiplier: enemyGroupDamageScale(selected.length),
    impactKind: impactKind,
    impactRank: impactRank,
    stun: stun,
    slow: slow,
  );
  _areaChests(
    s,
    center,
    radius,
    maxTargets - targets.length - (castChests?.length ?? 0),
    castChests: castChests,
  );
}

void paintCombatEffect(
  Adventure session,
  ui.Canvas canvas,
  ui.Offset center,
  int index,
  ui.Size size, {
  double opacity = 1,
}) {
  session.art.effects.draw(
    canvas,
    'combat-fx',
    index,
    ui.Rect.fromCenter(center: center, width: size.width, height: size.height),
    rows: 2,
    inset: 0,
    opacity: opacity,
  );
}

class EnemySwipe extends GameComponent with EffectVisibility {
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
  ui.Rect get effectBounds =>
      ui.Rect.fromCircle(center: position.toOffset(), radius: radius + 30);
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

class ShadowBolt extends GameComponent with EffectVisibility {
  ShadowBolt(
    this.session,
    ui.Offset at,
    double angle, {
    this.damage = 8,
    this.technological = false,
    this.venomous = false,
    this.status,
    this.statusPotency = 1,
  }) : direction = ui.Offset(math.cos(angle), math.sin(angle)) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(12);
  }
  final Adventure session;
  final ui.Offset direction;
  final double damage;
  final bool technological, venomous;
  final PlayerStatus? status;
  final double statusPotency;
  double remaining = 2;
  bool resolved = false;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromCircle(center: position.toOffset(), radius: 75);
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
    final distance =
            dt *
            (status == PlayerStatus.root
                ? 240
                : technological
                ? 320
                : 280),
        steps = math.max(1, (distance / 5).ceil());
    for (var i = 0; i < steps; i++) {
      final at = position.toOffset() + direction * (distance / steps);
      if (session.world.blocked(
        ui.Rect.fromCenter(center: at, width: 6, height: 6),
        avoidSanctuary: true,
      )) {
        finish();
        return;
      }
      position.setValues(at.dx, at.dy);
      if (session.hero.body.inflate(7).contains(at)) {
        session.hurtHero(
          damage,
          origin: at,
          status: status,
          statusPotency: statusPotency,
        );
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
    if (status == PlayerStatus.root) {
      final axis = ui.Offset(-direction.dy, direction.dx);
      final net = tip - direction * 8;
      final paint = ui.Paint()
        ..color = const ui.Color(0xffbca37c)
        ..strokeWidth = 1.5;
      for (var i = -2; i <= 2; i++) {
        canvas.drawLine(
          net + direction * (i * 5) - axis * 11,
          net + direction * (i * 5) + axis * 11,
          paint,
        );
        canvas.drawLine(
          net + axis * (i * 5) - direction * 11,
          net + axis * (i * 5) + direction * 11,
          paint,
        );
      }
      canvas.drawCircle(
        net,
        15,
        ui.Paint()
          ..color = const ui.Color(0xff7feafa)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }
    if (status == PlayerStatus.blind) {
      canvas.drawCircle(
        tip,
        10,
        ui.Paint()..color = const ui.Color(0xff192f4a),
      );
      canvas.drawCircle(
        tip,
        8,
        ui.Paint()
          ..color = const ui.Color(0xffc9b6ff)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        tip - direction * 20,
        tip,
        ui.Paint()
          ..color = const ui.Color(0xff8de7f4)
          ..strokeWidth = 3,
      );
      return;
    }
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

class ArcaneBolt extends GameComponent with EffectVisibility {
  ArcaneBolt(
    this.session,
    ui.Offset at,
    double angle,
    this.damage, {
    this.element = 'fire',
    this.explosive = false,
    this.propOnly = false,
    this.launchDelay = 0,
    this.caster,
    this.rank = 1,
    int? targetLimit,
  }) : targetLimit = targetLimit ?? (explosive ? 3 : 1),
       direction = ui.Offset(math.cos(angle), math.sin(angle)),
       chargeDuration = launchDelay,
       buildRevision = session.buildRevision {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(12);
  }
  final Adventure session;
  final ui.Offset direction;
  final double damage;
  final String element;
  final bool explosive, propOnly;
  final Guardian? caster;
  double launchDelay;
  final double chargeDuration;
  final int targetLimit, rank;
  final int buildRevision;
  double remaining = .88;
  bool resolved = false;
  final _art = MageCombatArt();
  MageElement get _element => MageElement.fromStyle(element);
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromCircle(center: position.toOffset(), radius: 140);

  void _contact(ui.Offset at, {bool terrain = false}) {
    session.game?.add(
      MageContact(
        session,
        at,
        element: _element,
        radius: terrain
            ? 18
            : explosive
            ? 85
            : 34,
        rank: rank,
      ),
    );
  }

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
      if (caster != null &&
          (caster!.dashing > 0 ||
              session.riding != null ||
              session.afflictions.frozen)) {
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
    // A hit can schedule removals. Keep one stable snapshot for this movement,
    // rather than copying every enemy at each five-pixel collision step.
    final candidates = propOnly
        ? const <HuntEnemy>[]
        : List<HuntEnemy>.of(session.mobs);
    for (var i = 0; i < n; i++) {
      final from = position.toOffset();
      final at = from + direction * (distance / n);
      final chest = session.world.firstChestOnSegment(from, at, padding: 4);
      if (chest != null) {
        final beforeContact = chest.at - direction * .5;
        if (!session.world.blocked(
              ui.Rect.fromCenter(center: beforeContact, width: 8, height: 8),
              avoidSanctuary: !propOnly,
            ) &&
            session.breakChest(chest.index)) {
          if (explosive && !propOnly) {
            areaStrike(
              session,
              chest.at,
              85,
              damage * .35,
              maxTargets: targetLimit - 1,
            );
          }
          _contact(chest.at);
        }
        finish();
        return;
      }
      if (session.world.blocked(
        ui.Rect.fromCenter(center: at, width: 8, height: 8),
        avoidSanctuary: !propOnly,
      )) {
        _contact(at, terrain: true);
        finish();
        return;
      }
      position.setValues(at.dx, at.dy);
      if (propOnly) continue;
      for (final mob in candidates) {
        if (mob.combatReady &&
            !mob.isDead &&
            !mob.isRemoving &&
            mob.body.inflate(7).contains(at)) {
          if (!session.canHitEnemy(mob, origin: at)) {
            finish();
            return;
          }
          final splash = explosive
              ? _areaTargets(
                  session,
                  at,
                  85,
                  maxTargets: targetLimit - 1,
                  excluded: {mob},
                )
              : <HuntEnemy>[];
          final multiplier = enemyGroupDamageScale(1 + splash.length);
          if (!session.hit(
            mob,
            damage * multiplier,
            direction * 12,
            origin: at,
            impactKind: ImpactKind.forElement(element),
            impactRank: rank,
          )) {
            finish();
            return;
          }
          if (element == 'ice') mob.slow = math.max(mob.slow, 1.5);
          if (explosive) {
            _damageAreaTargets(
              session,
              splash,
              at,
              damage * .35,
              multiplier: multiplier,
              impactKind: ImpactKind.forElement(element),
              impactRank: rank,
            );
            _areaChests(session, at, 85, targetLimit - 1 - splash.length);
          }
          _contact(at);
          session.kickCamera(element == 'lightning' ? .55 : .35);
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
    if (resolved) return;
    super.render(canvas);
    const tip = ui.Offset(0, -14);
    if (launchDelay > 0) {
      _art.charge(
        canvas,
        tip + direction * 18,
        _element,
        chargeDuration <= 0 ? 1 : 1 - launchDelay / chargeDuration,
        rank,
      );
      return;
    }
    _art.projectile(
      canvas,
      tip,
      math.atan2(direction.dy, direction.dx),
      .88 - remaining,
      _element,
      rank,
    );
    if (element == 'fire') {
      canvas.save();
      canvas.translate(tip.dx, tip.dy);
      canvas.rotate(math.atan2(direction.dy, direction.dx) - math.pi * .75);
      paintSpellFrame(
        session.art,
        canvas,
        SpellClip.meteorFlight,
        (.88 - remaining) % .65,
        ui.Offset.zero,
        64,
      );
      canvas.restore();
    }
  }
}

/// Contact animation only: projectile collision already resolved its one hit.
class MageContact extends GameComponent with EffectVisibility {
  MageContact(
    this.session,
    ui.Offset at, {
    required this.element,
    required this.radius,
    this.rank = 1,
  }) : buildRevision = session.buildRevision {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  static const duration = .48;
  final Adventure session;
  final MageElement element;
  final double radius;
  final int rank, buildRevision;
  final _art = MageCombatArt();
  double age = 0;
  bool finished = false;
  @override
  ui.Rect get effectBounds =>
      MageCombatArt.impactBounds(position.toOffset(), radius);
  @override
  int get priority => 9999;
  @override
  void update(double dt) {
    if (finished) return;
    if (buildRevision != session.buildRevision) {
      finished = true;
      removeFromParent();
      return;
    }
    if (!session.active) return;
    age = math.min(duration, age + math.min(.05, dt));
    if (age >= duration) {
      finished = true;
      removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    if (finished) return;
    super.render(canvas);
    _art.impact(canvas, ui.Offset.zero, age / duration, radius, element, rank);
    if (element != MageElement.lightning) {
      final clip = element == MageElement.ice
          ? SpellClip.iceNova
          : SpellClip.meteorImpact;
      paintSpellFrame(
        session.art,
        canvas,
        clip,
        age / duration * clip.duration,
        ui.Offset.zero,
        radius * 1.6,
        opacity: (1 - age / duration).clamp(0, .95),
      );
    }
  }
}

class RuneBurst extends GameComponent with EffectVisibility {
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
  ui.Rect get effectBounds => ui.Rect.fromCircle(
    center: position.toOffset(),
    radius: radius * 1.3 + 50,
  );
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
  final chests = <int>{};
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
        castChests: chests,
        impactRank: rank,
      );
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
  final hits = <({HuntEnemy enemy, ui.Offset origin, double damage})>[];
  for (var i = 0; i < count.clamp(0, 32); i++) {
    final at = points.last;
    final candidates =
        s.mobs
            .where(
              (e) =>
                  s.canHitEnemy(e, origin: at) &&
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
    final props = s.attackableChests(at, i == 0 ? 470 : 260);
    if (props.isNotEmpty &&
        (candidates.isEmpty ||
            (s.stageChestLocations[props.first] - at).distanceSquared <
                (candidates.first.body.center - at).distanceSquared)) {
      if (!s.breakChest(props.first)) break;
      points.add(s.stageChestLocations[props.first]);
      continue;
    }
    if (candidates.isEmpty) break;
    final target = candidates.first;
    visited.add(target);
    points.add(target.body.center);
    hits.add((enemy: target, origin: at, damage: damage * math.pow(.9, i)));
  }
  final multiplier = enemyGroupDamageScale(hits.length);
  for (final hit in hits) {
    if (!s.hit(
      hit.enemy,
      hit.damage * multiplier,
      ui.Offset.zero,
      origin: hit.origin,
      impactKind: ImpactKind.lightning,
      impactRank: rank,
    )) {
      break;
    }
  }
  s.game?.add(LightningTrace(s, points, rank: rank));
}

class LightningTrace extends GameComponent with EffectVisibility {
  LightningTrace(this.session, this.points, {this.rank = 1});
  static const duration = .48;
  final Adventure session;
  final List<ui.Offset> points;
  final int rank;
  final _art = MageCombatArt();
  late final _arcs = List.generate(
    math.max(0, points.length - 1),
    (_) => ElectricArcArt(),
  );
  double age = 0;
  @override
  late final ui.Rect effectBounds = points.isEmpty
      ? ui.Rect.zero
      : points
            .skip(1)
            .fold(
              ui.Rect.fromCircle(center: points.first, radius: 1),
              (bounds, point) => bounds.expandToInclude(
                ui.Rect.fromCircle(center: point, radius: 1),
              ),
            )
            .inflate(112);
  @override
  bool get isVisible => true;
  @override
  int get priority => 9999;
  @override
  void update(double dt) {
    if (!session.active) return;
    age += math.min(.05, dt);
    if (age >= duration) removeFromParent();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    if (age >= duration) return;
    super.render(canvas);
    final t = (age / duration).clamp(0.0, 1.0);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1] - const ui.Offset(0, 20),
          b = points[i] - const ui.Offset(0, 20);
      // Brief, staggered leaders with a shared instant contact; no delayed hit.
      final pulse = (.72 + .28 * math.cos(age * 48 - i * 1.7)).clamp(0.0, 1.0);
      _arcs[i - 1].paint(
        canvas,
        a,
        b,
        age,
        rank: rank,
        opacity: (1 - t) * pulse,
        seed: i,
        branches: 1 + rank ~/ 2,
      );
      _art.impact(
        canvas,
        points[i] + const ui.Offset(0, 8),
        t,
        28 + rank * 3,
        MageElement.lightning,
        rank,
      );
    }
    if (points.length > 1 && t < .35) {
      _art.charge(
        canvas,
        points.first - const ui.Offset(0, 20),
        MageElement.lightning,
        1 - t / .35,
        rank,
      );
    }
  }
}

class MeteorFall extends GameComponent with EffectVisibility {
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
  late final _flame = FirePlume();
  final _art = MageCombatArt();
  @override
  ui.Rect get effectBounds => ui.Rect.fromLTRB(
    target.dx - 220,
    target.dy - 570,
    target.dx + 340,
    target.dy + 220,
  );
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
        areaStrike(
          session,
          target,
          175,
          damage,
          maxTargets: targetLimit,
          impactKind: ImpactKind.fire,
          impactRank: rank,
        );
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
    _art.meteorPressure(c, target, t, rank);
    paintRankImpact(c, target, t, rank, const ui.Color(0xffffc578), radius: 85);
    final p = target + ui.Offset(110 * (1 - fall), -360 * (1 - fall));
    _flame.flight(c, p, math.atan2(360, -110), age * tempo, radius: 65);
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

class GroundLoot extends GameComponent with EffectVisibility {
  GroundLoot(this.session, this.item, ui.Offset at) {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(20);
  }
  final Adventure session;
  final Gear item;
  final _spritePaint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
  final _shadowPaint = ui.Paint()..color = const ui.Color(0x66000000);
  final _lightPaint = ui.Paint();
  final _glintPaint = ui.Paint()
    ..strokeWidth = 1
    ..strokeCap = ui.StrokeCap.round;
  // Vector light has no native shader or picture to retain across sessions.
  // These small, immutable paths are shared for the app's lifetime.
  static final _beams = [
    for (final height in [48.0, 37.0, 26.0])
      ui.Path()
        ..moveTo(-.5, -height)
        ..lineTo(.5, -height)
        ..lineTo(3, 1)
        ..lineTo(-3, 1)
        ..close(),
  ];
  static const _iconBounds = ui.Rect.fromLTWH(-16, -26, 32, 32);
  static const _visualBounds = ui.Rect.fromLTRB(-18, -49, 18, 8);
  ui.Image? _iconSheet;
  ui.Rect? _iconSource;
  double age = 0;
  bool collected = false, warned = false;

  @override
  int get priority => 29; // Ground light and equipment stay below actors.
  @override
  bool get isVisible => true; // Full visual bounds are culled in renderTree.
  @override
  ui.Rect get effectBounds => _visualBounds.shift(position.toOffset());

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
    if (added && p.isEquipped(item)) session.syncLife();
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
    if (session.disposed || collected || isRemoving) return;
    super.render(canvas);
    final color = ui.Color(item.rarity.color);
    final pulse = .5 + .5 * math.sin(age * 2.1 + item.serial * 1.7);
    canvas.drawOval(const ui.Rect.fromLTWH(-13, -2, 26, 8), _shadowPaint);
    _lightPaint.color = color.withValues(
      alpha: item.rarity == Rarity.common ? .13 : .28 + pulse * .08,
    );
    canvas.drawOval(const ui.Rect.fromLTWH(-15, -3, 30, 9), _lightPaint);
    if (item.rarity != Rarity.common) {
      final strength = item.rarity == Rarity.magic ? .75 : 1.0;
      _lightPaint.color = color.withValues(
        alpha: (.12 + pulse * .06) * strength,
      );
      for (final beam in _beams) {
        canvas.drawPath(beam, _lightPaint);
      }
    }
    final image = session.art.images['gear-icons'];
    if (image != null) {
      if (!identical(image, _iconSheet)) {
        _iconSheet = image;
        _iconSource = GearIconArt.source(image, item.base);
      }
      final source = _iconSource;
      if (source != null) {
        canvas.drawImageRect(image, source, _iconBounds, _spritePaint);
      }
    } else {
      // Headless/early-loading fallback; never draw over loaded equipment art.
      _lightPaint.color = color;
      canvas.save();
      canvas.rotate(math.pi / 4);
      canvas.drawRect(const ui.Rect.fromLTWH(-5, -5, 10, 10), _lightPaint);
      canvas.restore();
    }
    if (item.rarity != Rarity.common) {
      final at = ui.Offset(9, -20 - pulse * 2);
      _glintPaint.color = color.withValues(alpha: .24 + pulse * .44);
      canvas.drawLine(
        at - const ui.Offset(2, 0),
        at + const ui.Offset(2, 0),
        _glintPaint,
      );
      canvas.drawLine(
        at - const ui.Offset(0, 3),
        at + const ui.Offset(0, 3),
        _glintPaint,
      );
    }
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
      if (session.world.stage.usesCityArt) {
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
  }
}

class BossAttackVisual extends GameComponent with EffectVisibility {
  BossAttackVisual(
    this.session,
    this.source,
    this.pattern, {
    this.impact = false,
  }) {
    position = Vector2.zero();
    size = Vector2(worldSize.width, worldSize.height);
    if (!impact && pattern.power != BossPower.impact) {
      _label =
          (ui.ParagraphBuilder(
                  ui.ParagraphStyle(
                    fontFamily: 'Guardian',
                    fontSize: 13,
                    textAlign: ui.TextAlign.center,
                  ),
                )
                ..pushStyle(
                  ui.TextStyle(
                    color: pattern.color,
                    fontWeight: ui.FontWeight.bold,
                  ),
                )
                ..addText(pattern.power.label))
              .build()
            ..layout(const ui.ParagraphConstraints(width: 160));
    }
  }
  ui.Paragraph? _label;
  final Adventure session;
  final HuntEnemy source;
  final BossAttack pattern;
  final bool impact;
  double age = 0;
  @override
  late final ui.Rect effectBounds = pattern.zones
      .map((zone) => zone.path.getBounds())
      .reduce((bounds, zone) => bounds.expandToInclude(zone))
      .inflate(90)
      .expandToInclude(
        ui.Rect.fromCenter(
          center: pattern.target - const ui.Offset(0, 120),
          width: 170,
          height: 28,
        ),
      );
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
      if (_label case final label?) {
        final at =
            pattern.target +
            ui.Offset(
              -80,
              (session.viewportSize?.height ?? 640) < 520 ? 25 : -132,
            );
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(at.dx, at.dy, 160, 24),
            const ui.Radius.circular(6),
          ),
          ui.Paint()..color = const ui.Color(0xe610252d),
        );
        canvas.drawParagraph(label, at + const ui.Offset(0, 3));
      }
    }
  }

  @override
  void onRemove() {
    _label?.dispose();
    _label = null;
    super.onRemove();
  }
}

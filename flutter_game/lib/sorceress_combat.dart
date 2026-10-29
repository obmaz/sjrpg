import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'area_damage.dart';
import 'combat_feedback.dart';
import 'effect_visibility.dart';
import 'illustrated_combat_art.dart';
import 'mobility_motion.dart';
import 'rpg_model.dart';
import 'skill_aim.dart';
import 'sorceress_defenses.dart';
import 'sorceress_rules.dart';
import 'sorceress_vfx.dart';

/// One owner for cast transactions. Components own travel/contact; timers use
/// simulation seconds, so pause and the engine time scale apply uniformly.
class SorceressCombat {
  SorceressCombat(this.hero);
  final Guardian hero;
  Adventure get session => hero.session;
  Progress get progress => session.progress;
  late final defenses = SorceressDefenses(session);
  double sharedDelay = 0, channelTime = 0, _channelPulse = 0;
  SorceressSpellStats? _channel;
  ui.Offset? _lastBlaze;
  double blazeTime = 0, _blazePulse = 0;
  SorceressSpellStats? _blaze;
  final _trailHitUntil = <HuntEnemy, double>{};
  double _clock = 0;
  static const defensiveIds = {
    'frozenArmor',
    'shiverArmor',
    'chillingArmor',
    'energyShield',
    'enchant',
    'thunderStorm',
  };
  bool get channeling => _channel != null;
  SorceressSpellStats stats(SkillDef skill) => progress.sorceressSpell(skill);
  bool canActivate(SkillDef skill, {SkillAim? aim}) {
    final spec = stats(skill);
    if (skill.id == 'inferno' && progress.energy < spec.minimumStartMana) {
      return false;
    }
    if (spec.timerGroup.isNotEmpty && sharedDelay > 0) return false;
    if (skill.id == 'blink') return teleportLanding(spec, aim) != null;
    return true;
  }

  void update(double dt) {
    if (!session.active || dt <= 0) return;
    _clock += dt;
    _trailHitUntil.removeWhere(
      (enemy, until) => enemy.isDead || enemy.isRemoving || until <= _clock,
    );
    sharedDelay = math.max(0, sharedDelay - dt);
    defenses.update(dt);
    if (_channel != null) {
      final spec = _channel!;
      if (session.afflictions.frozen ||
          session.riding != null ||
          session.progress.heroClass != HeroClass.mage ||
          hero.aim?.cancelled == true ||
          !session.combatAllowed) {
        endChannel();
      } else {
        channelTime += dt;
        _channelPulse -= dt;
        if (_channelPulse <= 0) {
          final interval = math.max(.04, spec.interval);
          final mana = spec.manaPerSecond * interval;
          if (progress.energy < mana) {
            endChannel();
          } else {
            progress.energy -= mana;
            _channelPulse += interval;
            final angle = hero.aim?.angle ?? hero.bearing;
            _cone(spec, angle, interval);
            hero.castLock = math.max(hero.castLock, .12);
            hero.swingDuration = hero.swing = .24;
            hero.attackBearing = angle;
            _visual(
              spec,
              hero.body.center,
              mode: 'ground',
              duration: .18,
              radius: spec.range,
              bearing: angle,
            );
          }
        }
        // A tap produces a single brief stream; a held owner keeps channeling.
        if (hero.aim?.id != 'inferno' && channelTime > .22) endChannel();
      }
    }
    if (blazeTime > 0 && _blaze != null) {
      blazeTime = math.max(0, blazeTime - dt);
      _blazePulse -= dt;
      if (_blazePulse <= 0 &&
          (_lastBlaze == null ||
              (hero.body.center - _lastBlaze!).distanceSquared >= 40 * 40)) {
        _blazePulse = .12;
        _lastBlaze = hero.body.center;
        addZone(
          _blaze!,
          hero.body.center,
          duration: math.max(.1, _blaze!.groundDuration),
          radius: math.max(22, _blaze!.radius),
          interval: .35,
        );
      }
    }
  }

  void endChannel() {
    _channel = null;
    channelTime = 0;
  }

  void clear() {
    endChannel();
    sharedDelay = blazeTime = 0;
    _blaze = null;
    _lastBlaze = null;
    _trailHitUntil.clear();
    defenses.clear();
  }

  Map<String, Object?> captureState() => {
    'sharedDelay': sharedDelay,
    'defenses': defenses.captureState(),
    'blazeTime': blazeTime,
    'blazeRank': blazeTime > 0 ? _blaze?.rank ?? 0 : 0,
  };
  void restoreState(Map<String, dynamic> state) {
    clear();
    final delay = state['sharedDelay'];
    sharedDelay = delay is num && delay.isFinite
        ? delay.toDouble().clamp(0, 10)
        : 0;
    final trailTime = state['blazeTime'], trailRank = state['blazeRank'];
    if (trailTime is num &&
        trailTime.isFinite &&
        trailTime > 0 &&
        trailRank is int &&
        trailRank > 0 &&
        progress.rank('blaze') > 0) {
      final def = progress.skills.firstWhere((skill) => skill.id == 'blaze');
      _blaze = progress.sorceressSpell(def, atRank: trailRank.clamp(1, 20));
      blazeTime = trailTime.toDouble().clamp(0, _blaze!.duration);
    }
    final buffs = state['defenses'];
    if (buffs is Map) defenses.restoreState(Map<String, dynamic>.from(buffs));
    for (final def in progress.skills) {
      if (stats(def).timerGroup.isNotEmpty) {
        hero.cooldowns[def.id] = sharedDelay;
      }
    }
  }

  ui.Offset? teleportLanding(SorceressSpellStats spec, SkillAim? aim) {
    if (session.afflictions.movementBlocked) return null;
    final from = hero.position.toOffset();
    final direction = ui.Offset(
      math.cos(aim?.angle ?? hero.bearing),
      math.sin(aim?.angle ?? hero.bearing),
    );
    final distance = aim == null
        ? spec.range
        : math.min(spec.range, aim.distance);
    if (!distance.isFinite ||
        distance <= 0 ||
        session.world.blocked(hero.body)) {
      return null;
    }
    // Teleport crosses intervening walls and creatures; only the complete,
    // Float32-stored landing body must be valid terrain.
    for (var travel = distance; travel > 6; travel -= 6) {
      final candidate = from + direction * travel;
      final stored = Vector2(candidate.dx, candidate.dy).toOffset();
      if (!session.world.blocked(stored & hero.body.size) &&
          session.townGates.permits(
            session.world.sanctuary,
            hero.body,
            stored & hero.body.size,
          )) {
        return stored;
      }
    }
    return null;
  }

  void activate(SkillDef skill, {SkillAim? aim, bool propOnly = false}) {
    final spec = stats(skill);
    endChannel();
    if (spec.timerGroup.isNotEmpty) {
      sharedDelay = spec.castDelay;
      for (final def in progress.skills) {
        if (stats(def).timerGroup.isNotEmpty) {
          hero.cooldowns[def.id] = sharedDelay;
        }
      }
    }
    final angle = aim?.angle ?? _autoBearing(spec.range);
    hero.attackBearing = angle;
    hero.strikePose = 2;
    final motionTime =
        progress.skillMotionTime(skill) / session.afflictions.attackTempo;
    hero.castLock = math.max(hero.castLock, motionTime);
    hero.attackClock = math.max(hero.attackClock, motionTime);
    hero.swingDuration = hero.swing = motionTime;
    _visual(spec, hero.body.center, mode: 'cast', radius: 45, bearing: angle);
    if (defensiveIds.contains(skill.id)) {
      defenses.activate(skill.id, spec);
      return;
    }
    switch (skill.id) {
      case 'blink':
        final landing = teleportLanding(spec, aim);
        if (landing != null) {
          final before = hero.body.center;
          hero.position.setValues(landing.dx, landing.dy);
          session.townGates.observe(session.sheltered);
          hero.lastClearPosition = landing;
          session.game?.add(MobilityVisual(session, before, hero.body.center));
        }
      case 'inferno':
        _channel = spec;
        _channelPulse = math.max(.04, spec.interval);
        channelTime = 0;
        progress.energy = math.max(
          0,
          progress.energy - spec.manaPerSecond * _channelPulse,
        );
        _cone(spec, angle, _channelPulse);
      case 'blaze':
        _blaze = spec;
        blazeTime = spec.duration;
        _lastBlaze = null;
      case 'frostNova' || 'nova':
        area(spec, hero.body.center, radius: spec.radius);
        _visual(
          spec,
          hero.body.center,
          mode: 'ground',
          radius: spec.radius,
          duration: .5,
        );
      case 'staticField':
        final targets = eligible(
          hero.body.center,
          spec.radius,
        ).take(spec.maxTargets).toList();
        for (final enemy in targets) {
          final floor = enemy.boss
              ? enemy.life.max * spec.staticBossFloor
              : 1.0;
          final amount = math.min(
            math.max(0, enemy.life.value - floor),
            enemy.life.value * spec.currentHpFraction,
          );
          damage(enemy, amount.toDouble(), spec);
        }
        _visual(
          spec,
          hero.body.center,
          mode: 'ground',
          radius: spec.radius,
          duration: .5,
        );
      case 'telekinesis':
        final target = targetPoint(spec, aim);
        final chest = session.world.firstChestOnSegment(
          hero.body.center,
          target,
          padding: 12,
        );
        final direction = unit(target - hero.body.center);
        if (chest != null &&
            session.world.clearEnemyLine(
              hero.body.center,
              chest.at - direction * 5,
              const ui.Size(3, 3),
            )) {
          session.breakChest(chest.index);
        } else {
          final enemies = eligible(target, 55);
          if (enemies.isNotEmpty) {
            final enemy = enemies.first;
            damage(
              enemy,
              roll(spec),
              spec,
              impulse: unit(enemy.body.center - hero.body.center) * 45,
            );
            enemy.applyStun(math.max(.25, spec.freezeDuration));
          }
        }
        _beam(spec, [hero.body.center, target]);
      case 'lightning':
        _lightning(spec, angle);
      case 'chainLightning':
        _chain(spec, angle);
      case 'firewall':
        addZone(
          spec,
          targetPoint(spec, aim),
          radius: spec.radius,
          duration: spec.duration,
          bearing: angle + math.pi / 2,
          line: true,
        );
      case 'blizzard':
        addZone(
          spec,
          targetPoint(spec, aim),
          radius: spec.radius,
          duration: spec.duration,
          interval: math.max(.04, spec.interval),
          falling: true,
        );
      case 'meteor':
        session.game?.add(SorceressMeteor(this, spec, targetPoint(spec, aim)));
      case 'hydra':
        session.game?.add(SorceressHydra(this, spec, targetPoint(spec, aim)));
      case 'frozenOrb':
        projectile(spec, hero.body.center, angle, orb: true);
      case 'chargedBolt':
        for (var i = 0; i < spec.projectileCount; i++) {
          final spread = spec.projectileCount == 1
              ? 0.0
              : (i / (spec.projectileCount - 1) - .5) * .8;
          projectile(
            spec,
            hero.body.center,
            angle + spread,
            wander: true,
            seed: i,
            propOnly: propOnly,
          );
        }
      default:
        projectile(spec, hero.body.center, angle, propOnly: propOnly);
    }
  }

  void paintAim(ui.Canvas canvas, SkillAim aim) {
    final def = progress.skills.firstWhere((skill) => skill.id == aim.id);
    final spec = stats(def);
    final origin = hero.body.center - hero.position.toOffset();
    final bearing = aim.dragged ? aim.angle : hero.bearing;
    final paint = ui.Paint()
      ..color = aim.cancelled
          ? const ui.Color(0xfff08a78)
          : const ui.Color(0xff9edbd6)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.6;
    if (def.id == 'blink') {
      final at = teleportLanding(spec, aim.dragged ? aim : null);
      if (at != null) {
        final rect = (at & hero.body.size).shift(-hero.position.toOffset());
        canvas.drawLine(origin, rect.center, paint);
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(4)),
          paint,
        );
      } else {
        canvas.drawLine(
          origin - const ui.Offset(9, 9),
          origin + const ui.Offset(9, 9),
          paint,
        );
        canvas.drawLine(
          origin - const ui.Offset(9, -9),
          origin + const ui.Offset(9, -9),
          paint,
        );
      }
      return;
    }
    if (const {'firewall', 'meteor', 'blizzard', 'hydra'}.contains(def.id)) {
      final target =
          targetPoint(spec, aim.dragged ? aim : null) -
          hero.position.toOffset();
      canvas.drawLine(origin, target, paint);
      if (def.id == 'firewall') {
        final across =
            ui.Offset(-math.sin(bearing), math.cos(bearing)) * spec.radius;
        canvas.drawLine(
          target - across,
          target + across,
          paint..strokeWidth = 12,
        );
      } else {
        canvas.drawCircle(target, def.id == 'hydra' ? 24 : spec.radius, paint);
      }
      return;
    }
    final end =
        hero.aimedImpact(bearing, spec.range) - hero.position.toOffset();
    canvas.drawLine(origin, end, paint);
    if (def.id == 'inferno' || def.id == 'chargedBolt') {
      final half = def.id == 'inferno' ? .30 : .40;
      for (final side in [-1, 1]) {
        final edge =
            hero.aimedImpact(bearing + side * half, spec.range) -
            hero.position.toOffset();
        canvas.drawLine(origin, edge, paint);
      }
    }
    canvas.drawCircle(end, 6, paint);
  }

  double _autoBearing(double range) {
    final targets = eligible(hero.body.center, range);
    if (targets.isEmpty) return hero.bearing;
    final d = targets.first.body.center - hero.body.center;
    return math.atan2(d.dy, d.dx);
  }

  ui.Offset targetPoint(SorceressSpellStats spec, SkillAim? aim) {
    if (aim != null) {
      return hero.aimedImpact(aim.angle, math.min(spec.range, aim.distance));
    }
    final targets = eligible(hero.body.center, spec.range);
    if (targets.isNotEmpty) return targets.first.body.center;
    return hero.aimedImpact(hero.bearing, math.min(190, spec.range));
  }

  List<HuntEnemy> eligible(ui.Offset center, double radius) =>
      session.mobs
          .where(
            (e) =>
                session.canHitEnemy(e, origin: center) &&
                distanceToTargetBody(center, e.body) <= radius &&
                session.world.clearEnemyLine(
                  center,
                  e.body.center,
                  const ui.Size(3, 3),
                ),
          )
          .toList()
        ..sort(
          (a, b) => (a.body.center - center).distanceSquared.compareTo(
            (b.body.center - center).distanceSquared,
          ),
        );
  static ui.Offset unit(ui.Offset d) =>
      d.distance > 0 ? d / d.distance : const ui.Offset(1, 0);
  double roll(SorceressSpellStats spec, {bool perSecond = false}) {
    final low = perSecond ? spec.minDamagePerSecond : spec.minDamage;
    final high = perSecond ? spec.maxDamagePerSecond : spec.maxDamage;
    if (perSecond && high == 0) return spec.damagePerSecond;
    return low + session.random.nextDouble() * math.max(0, high - low);
  }

  bool damage(
    HuntEnemy enemy,
    double amount,
    SorceressSpellStats spec, {
    ui.Offset? impulse,
    bool hitStop = false,
  }) {
    if (amount <= 0) return false;
    if (spec.damageType == SorceressDamageType.cold) {
      amount *= 1 + math.min(1, progress.sorceressColdPierce);
    }
    final accepted = session.hit(
      enemy,
      amount,
      impulse ?? ui.Offset.zero,
      hitStop: hitStop,
      impactKind: spec.damageType == SorceressDamageType.cold
          ? ImpactKind.ice
          : ImpactKind.magic,
      impactRank: spec.rank,
    );
    if (accepted &&
        spec.damageType == SorceressDamageType.cold &&
        !enemy.isDead) {
      enemy.slow = math.max(enemy.slow, math.max(1, spec.chillDuration));
      if (spec.freezeDuration > 0) enemy.applyStun(spec.freezeDuration);
    }
    return accepted;
  }

  void applyColdHit(
    HuntEnemy enemy,
    double amount, {
    double freezeDuration = 0,
    double slowDuration = 0,
  }) {
    final accepted = amount <= 0
        ? session.canHitEnemy(enemy) &&
              session.world.clearEnemyLine(
                hero.body.center,
                enemy.body.center,
                const ui.Size(3, 3),
              )
        : session.hit(
            enemy,
            amount * (1 + math.min(1, progress.sorceressColdPierce)),
            ui.Offset.zero,
            hitStop: false,
            impactKind: ImpactKind.ice,
          );
    if (accepted) {
      enemy.slow = math.max(enemy.slow, slowDuration);
      if (freezeDuration > 0) enemy.applyStun(freezeDuration);
    }
  }

  void retaliateIceBolt(HuntEnemy enemy, {double? amount}) {
    final skill = progress.skills.firstWhere((s) => s.id == 'iceBolt');
    projectile(
      stats(skill),
      hero.body.center,
      math.atan2(
        enemy.body.center.dy - hero.body.center.dy,
        enemy.body.center.dx - hero.body.center.dx,
      ),
      damageOverride: amount,
    );
  }

  void thunderStrike(HuntEnemy enemy) {
    final spec = stats(
      progress.skills.firstWhere((s) => s.id == 'thunderStorm'),
    );
    damage(enemy, roll(spec), spec);
    _beam(spec, [
      enemy.body.center - const ui.Offset(0, 150),
      enemy.body.center,
    ]);
  }

  void area(
    SorceressSpellStats spec,
    ui.Offset center, {
    double? radius,
    double? amount,
  }) {
    final targets = eligible(
      center,
      radius ?? spec.radius,
    ).take(spec.maxTargets).toList();
    final share = enemyGroupDamageScale(targets.length);
    for (final enemy in targets) {
      damage(enemy, (amount ?? roll(spec)) * share, spec, hitStop: true);
    }
  }

  void _cone(SorceressSpellStats spec, double bearing, double interval) {
    final direction = ui.Offset(math.cos(bearing), math.sin(bearing));
    final targets = eligible(hero.body.center, spec.range)
        .where((enemy) {
          final d = enemy.body.center - hero.body.center;
          final dot = unit(d).dx * direction.dx + unit(d).dy * direction.dy;
          return dot > math.cos(.30);
        })
        .take(spec.maxTargets)
        .toList();
    final share = enemyGroupDamageScale(targets.length);
    for (final enemy in targets) {
      damage(enemy, roll(spec, perSecond: true) * interval * share, spec);
    }
  }

  void _lightning(SorceressSpellStats spec, double bearing) {
    final from = hero.body.center;
    final to = hero.aimedImpact(bearing, spec.range);
    final delta = to - from;
    final targets =
        session.mobs.where((e) {
          if (!session.canHitEnemy(e) ||
              !session.world.clearEnemyLine(
                from,
                e.body.center,
                const ui.Size(3, 3),
              )) {
            return false;
          }
          final t = delta.distanceSquared == 0
              ? 0.0
              : ((e.body.center - from).dx * delta.dx +
                        (e.body.center - from).dy * delta.dy) /
                    delta.distanceSquared;
          return t >= 0 &&
              t <= 1 &&
              distanceToTargetBody(from + delta * t, e.body) <= 9;
        }).toList()..sort(
          (a, b) => (a.body.center - from).distanceSquared.compareTo(
            (b.body.center - from).distanceSquared,
          ),
        );
    final selected = targets.take(spec.maxTargets).toList(),
        share = enemyGroupDamageScale(
          math.min(targets.length, spec.maxTargets),
        );
    for (final enemy in selected) {
      damage(enemy, roll(spec) * share, spec);
    }
    _beam(spec, [from, to]);
  }

  void _chain(SorceressSpellStats spec, double bearing) {
    final points = <ui.Offset>[hero.body.center], visited = <HuntEnemy>{};
    var point = hero.body.center;
    final limit = math.min(spec.maxTargets, math.max(1, spec.lightningBounces));
    for (var i = 0; i < limit; i++) {
      final choices = eligible(
        point,
        i == 0 ? spec.range : 220,
      ).where((e) => !visited.contains(e)).toList();
      if (i == 0) {
        final direction = ui.Offset(math.cos(bearing), math.sin(bearing));
        choices.removeWhere((enemy) {
          final delta = enemy.body.center - point;
          final along = delta.dx * direction.dx + delta.dy * direction.dy;
          final side = (delta.dx * direction.dy - delta.dy * direction.dx)
              .abs();
          return along < 0 || side > enemy.body.longestSide / 2 + 12;
        });
      }
      if (choices.isEmpty) break;
      final enemy = choices.first;
      visited.add(enemy);
      point = enemy.body.center;
      points.add(point);
    }
    final share = enemyGroupDamageScale(visited.length);
    for (final enemy in visited) {
      damage(enemy, roll(spec) * share, spec);
    }
    _beam(spec, points);
  }

  void projectile(
    SorceressSpellStats spec,
    ui.Offset from,
    double bearing, {
    bool wander = false,
    bool orb = false,
    bool simple = false,
    bool propOnly = false,
    int seed = 0,
    double? damageOverride,
    double? rangeOverride,
  }) {
    session.game?.add(
      SorceressProjectile(
        this,
        spec,
        from,
        bearing: bearing,
        damageAmount: damageOverride ?? roll(spec),
        wander: wander,
        orb: orb,
        simple: simple,
        propOnly: propOnly,
        seed: seed,
        rangeOverride: rangeOverride,
      ),
    );
  }

  void addZone(
    SorceressSpellStats spec,
    ui.Offset at, {
    required double duration,
    required double radius,
    double interval = .3,
    double bearing = 0,
    bool line = false,
    bool falling = false,
  }) {
    session.game?.add(
      SorceressGround(
        this,
        spec,
        at,
        duration: duration,
        radius: radius,
        interval: interval,
        bearing: bearing,
        line: line,
        falling: falling,
      ),
    );
  }

  void _visual(
    SorceressSpellStats spec,
    ui.Offset at, {
    String mode = 'impact',
    double duration = .35,
    double radius = 40,
    double bearing = 0,
    List<ui.Offset>? points,
  }) {
    session.game?.add(
      SorceressFlash(
        this,
        spec,
        at,
        mode: mode,
        duration: duration,
        radius: radius,
        bearing: bearing,
        points: points,
      ),
    );
  }

  void _beam(SorceressSpellStats spec, List<ui.Offset> points) {
    if (points.length > 1) {
      _visual(
        spec,
        points.first,
        mode: 'beam',
        points: points,
        duration: .22,
        radius: spec.range,
      );
    }
  }
}

abstract class SorceressEffect extends GameComponent with EffectVisibility {
  SorceressEffect(this.owner, this.spec, ui.Offset at)
    : revision = owner.session.buildRevision {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  final SorceressCombat owner;
  final SorceressSpellStats spec;
  final int revision;
  double age = 0;
  bool finished = false;
  Adventure get session => owner.session;
  bool step(double dt) {
    if (finished) return false;
    if (session.disposed ||
        session.defeated ||
        revision != session.buildRevision) {
      finish();
      return false;
    }
    if (!session.active || dt <= 0) return false;
    age += math.min(.05, dt);
    return true;
  }

  void finish() {
    finished = true;
    removeFromParent();
  }

  @override
  ui.Rect get protectedActorBody => session.hero.body;
}

class SorceressProjectile extends SorceressEffect {
  SorceressProjectile(
    super.owner,
    super.spec,
    super.at, {
    required this.damageAmount,
    required this.bearing,
    this.wander = false,
    this.orb = false,
    this.simple = false,
    this.propOnly = false,
    this.seed = 0,
    this.rangeOverride,
  });
  final double damageAmount, bearing;
  final bool wander, orb, simple, propOnly;
  final int seed;
  final double? rangeOverride;
  final struck = <HuntEnemy>{};
  double travelled = 0;
  int orbShards = 0;
  bool _terminalExploded = false;
  double get range => rangeOverride ?? spec.range;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromCircle(center: position.toOffset(), radius: 45);
  @override
  void update(double dt) {
    if (!step(dt)) return;
    dt = math.min(.05, dt);
    final angle =
        bearing + (wander ? math.sin(age * 17 + seed * 2.3) * .36 : 0);
    final direction = ui.Offset(math.cos(angle), math.sin(angle));
    final distance = math.min(dt * spec.boltSpeed, range - travelled);
    final steps = math.max(1, (distance / 5).ceil());
    for (var i = 0; i < steps; i++) {
      final from = position.toOffset(),
          next = from + direction * (distance / steps);
      final chest = session.world.firstChestOnSegment(from, next, padding: 4);
      if (chest != null) {
        final approach = ui.Rect.fromCenter(
          center: chest.at - direction * .5,
          width: 8,
          height: 8,
        );
        if (!(propOnly
            ? session.world.blocked(approach)
            : session.world.blocksEnemy(approach))) {
          session.breakChest(chest.index);
        }
        _terminalNova();
        finish();
        return;
      }
      final footprint = ui.Rect.fromCenter(center: next, width: 6, height: 6);
      if (propOnly
          ? session.world.blocked(footprint)
          : session.world.blocksEnemy(footprint)) {
        _terminalNova();
        finish();
        return;
      }
      position.setValues(next.dx, next.dy);
      if (!orb && !propOnly) {
        final hit = session.mobs
            .where(
              (e) =>
                  !struck.contains(e) &&
                  distanceToTargetBody(next, e.body) <= 9 &&
                  session.canHitEnemy(e, origin: next) &&
                  session.world.clearEnemyLine(
                    next,
                    e.body.center,
                    const ui.Size(3, 3),
                  ),
            )
            .toList();
        if (hit.isNotEmpty) {
          final enemy = hit.first;
          struck.add(enemy);
          if (!simple && spec.radius > 12) {
            owner.area(spec, next, amount: damageAmount);
          } else {
            owner.damage(enemy, damageAmount, spec, hitStop: true);
          }
          owner._visual(spec, next, radius: math.max(24, spec.radius));
          if (simple || !spec.pierces || struck.length >= spec.maxTargets) {
            finish();
            return;
          }
        }
      }
    }
    travelled += distance;
    if (orb) {
      final wanted = math.min(
        spec.orbTrailCount,
        (travelled / range * spec.orbTrailCount + 1e-6).floor(),
      );
      while (orbShards < wanted) {
        owner.projectile(
          spec,
          position.toOffset(),
          bearing + orbShards * 19 * math.pi * 2 / 64,
          damageOverride: damageAmount,
          rangeOverride: 180,
          simple: true,
        );
        orbShards++;
      }
    }
    if (travelled >= range) {
      _terminalNova();
      finish();
    }
  }

  void _terminalNova() {
    if (!orb || _terminalExploded) return;
    _terminalExploded = true;
    _shards(spec.orbBurstCount);
  }

  void _shards(int count) {
    for (var i = 0; i < count; i++) {
      owner.projectile(
        spec,
        position.toOffset(),
        i * math.pi * 2 / count + age * 2,
        damageOverride: damageAmount,
        rangeOverride: 180,
        simple: true,
      );
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (finished) return;
    SorceressVfx.projectile(
      canvas,
      orb
          ? 'frozenOrb'
          : simple
          ? (spec.id == 'hydra' ? 'firebolt' : 'iceBolt')
          : spec.id,
      ui.Offset.zero,
      bearing: bearing,
      time: age,
      rank: spec.rank,
      seed: seed,
      radius: orb ? 24 : 12,
    );
  }
}

class SorceressGround extends SorceressEffect {
  SorceressGround(
    super.owner,
    super.spec,
    super.at, {
    required this.duration,
    required this.radius,
    required this.interval,
    this.bearing = 0,
    this.line = false,
    this.falling = false,
  });
  final double duration, radius, interval, bearing;
  final bool line, falling;
  double pulse = 0;
  @override
  ui.Rect get effectBounds => ui.Rect.fromLTRB(
    position.x - radius - 35,
    position.y - radius * (falling ? 2 : 1) - 35,
    position.x + radius + 35,
    position.y + radius + 35,
  );
  @override
  int get priority => 29;
  @override
  void update(double dt) {
    if (!step(dt)) return;
    if (age >= duration) {
      finish();
      return;
    }
    pulse -= math.min(.05, dt);
    if (pulse > 0) return;
    pulse += math.max(.1, interval);
    final center = position.toOffset();
    var targets = owner.eligible(center, radius);
    if (line) {
      final normal = ui.Offset(-math.sin(bearing), math.cos(bearing));
      targets = targets.where((e) {
        final d = e.body.center - center;
        return (d.dx * normal.dx + d.dy * normal.dy).abs() < 24;
      }).toList();
    }
    if (falling) {
      final angle = session.random.nextDouble() * math.pi * 2;
      final r = math.sqrt(session.random.nextDouble()) * radius;
      final at = center + ui.Offset(math.cos(angle), math.sin(angle)) * r;
      owner._visual(spec, at, mode: 'impact', radius: 28, duration: .3);
      // Blizzard shards are discrete falling contacts, never a full-radius DoT.
      targets = targets
          .where(
            (e) =>
                distanceToTargetBody(at, e.body) < 45 &&
                !session.world.blocksEnemy(
                  ui.Rect.fromCenter(center: at, width: 6, height: 6),
                ) &&
                session.world.clearEnemyLine(
                  at,
                  e.body.center,
                  const ui.Size(3, 3),
                ),
          )
          .toList();
    }
    targets = targets.take(spec.maxTargets).toList();
    if (spec.id == 'blaze') {
      targets = targets
          .where((enemy) => (owner._trailHitUntil[enemy] ?? 0) <= owner._clock)
          .toList();
      for (final enemy in targets) {
        owner._trailHitUntil[enemy] = owner._clock + interval;
      }
    }
    final share = enemyGroupDamageScale(targets.length);
    for (final enemy in targets) {
      owner.damage(
        enemy,
        (falling
                ? owner.roll(spec)
                : owner.roll(spec, perSecond: true) * interval) *
            share,
        spec,
      );
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (finished) return;
    SorceressVfx.ground(
      canvas,
      spec.id == 'meteor' ? 'meteorResidual' : spec.id,
      ui.Offset.zero,
      progress: (age / duration).clamp(0, .9999),
      time: age,
      rank: spec.rank,
      radius: radius,
      bearing: bearing,
    );
  }
}

class SorceressMeteor extends SorceressEffect {
  SorceressMeteor(super.owner, super.spec, super.at);
  static const fallTime = 2.4;
  @override
  ui.Rect get effectBounds => ui.Rect.fromLTRB(
    position.x - spec.radius - 35,
    position.y - spec.radius * 4 - 35,
    position.x + spec.radius + 35,
    position.y + spec.radius + 35,
  );
  @override
  void update(double dt) {
    if (!step(dt)) return;
    if (age < fallTime) return;
    final center = position.toOffset();
    owner.area(spec, center);
    owner._visual(spec, center, radius: spec.radius, duration: .5);
    owner.addZone(
      spec,
      center,
      duration: math.max(.1, spec.groundDuration),
      radius: spec.radius,
    );
    finish();
  }

  @override
  void render(ui.Canvas canvas) {
    if (finished) return;
    SorceressVfx.projectile(
      canvas,
      'meteor',
      ui.Offset(0, -(1 - age / fallTime) * 160),
      bearing: math.pi / 2,
      time: age,
      rank: spec.rank,
      radius: 24,
    );
    SorceressVfx.ground(
      canvas,
      'meteorMarker',
      ui.Offset.zero,
      progress: age / fallTime * .44,
      time: age,
      rank: spec.rank,
      radius: spec.radius,
    );
  }
}

class SorceressHydra extends SorceressEffect {
  SorceressHydra(super.owner, super.spec, super.at);
  double shoot = 0;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromCircle(center: position.toOffset(), radius: 90);
  @override
  void update(double dt) {
    if (!step(dt)) return;
    if (age >= spec.duration) {
      finish();
      return;
    }
    shoot -= math.min(.05, dt);
    if (shoot > 0) return;
    shoot += math.max(.35, spec.interval);
    final targets = owner
        .eligible(position.toOffset(), spec.range)
        .take(spec.maxTargets)
        .toList();
    if (targets.isEmpty) return;
    for (var head = 0; head < 3; head++) {
      final from = SorceressVfx.hydraHeads(
        position.toOffset(),
        time: age,
        radius: 60,
      )[head];
      final target = targets[head % targets.length];
      owner.projectile(
        spec,
        from,
        math.atan2(
          target.body.center.dy - from.dy,
          target.body.center.dx - from.dx,
        ),
        damageOverride:
            owner.roll(spec) *
            enemyGroupDamageScale(math.min(3, targets.length)),
        simple: true,
      );
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (finished) return;
    SorceressVfx.ground(
      canvas,
      'hydra',
      ui.Offset.zero,
      time: age,
      progress: age / spec.duration,
      radius: 60,
      rank: spec.rank,
    );
  }
}

class SorceressFlash extends SorceressEffect {
  SorceressFlash(
    super.owner,
    super.spec,
    super.at, {
    required this.mode,
    required this.duration,
    required this.radius,
    this.bearing = 0,
    this.points,
  });
  final String mode;
  final double duration, radius, bearing;
  final List<ui.Offset>? points;
  @override
  ui.Rect get effectBounds => points == null
      ? ui.Rect.fromCircle(center: position.toOffset(), radius: radius + 35)
      : ui.Rect.fromPoints(
          points!.reduce(
            (a, b) => ui.Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy)),
          ),
          points!.reduce(
            (a, b) => ui.Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy)),
          ),
        ).inflate(60);
  @override
  void update(double dt) {
    if (!step(dt)) return;
    if (age >= duration) finish();
  }

  @override
  void render(ui.Canvas canvas) {
    if (finished) return;
    final t = age / duration;
    if (mode == 'beam') {
      SorceressVfx.beam(
        canvas,
        spec.id,
        points!.map((p) => p - position.toOffset()).toList(),
        time: age,
        rank: spec.rank,
        progress: t,
      );
    } else if (mode == 'cast') {
      SorceressVfx.cast(
        canvas,
        spec.id,
        ui.Offset.zero,
        progress: t,
        rank: spec.rank,
        radius: radius,
        bearing: bearing,
      );
    } else if (mode == 'ground') {
      SorceressVfx.ground(
        canvas,
        spec.id,
        ui.Offset.zero,
        progress: t,
        time: age,
        rank: spec.rank,
        radius: radius,
        bearing: bearing,
      );
    } else {
      SorceressVfx.impact(
        canvas,
        spec.id,
        ui.Offset.zero,
        progress: t,
        rank: spec.rank,
        radius: radius,
        bearing: bearing,
      );
    }
    if (mode == 'beam' && points != null && points!.isNotEmpty) {
      IllustratedCombatArt.sequence(
        session.art.effects,
        canvas,
        CombatIllustration.lightning,
        points!.last - position.toOffset(),
        progress: t,
        radius: 32,
        opacity: .78,
      );
    } else if (mode == 'impact' ||
        ((mode == 'cast' || mode == 'ground') &&
            const {'frostNova', 'nova', 'staticField'}.contains(spec.id))) {
      IllustratedCombatArt.sequence(
        session.art.effects,
        canvas,
        IllustratedCombatArt.family(spec.id),
        ui.Offset.zero,
        progress: t,
        radius: math.min(128, radius),
        bearing: bearing,
        protectBody: mode == 'cast' || mode == 'ground',
      );
    } else if (mode == 'ground' && spec.id == 'inferno') {
      IllustratedCombatArt.sequence(
        session.art.effects,
        canvas,
        CombatIllustration.blade,
        ui.Offset(math.cos(bearing), math.sin(bearing)) * radius * .35,
        progress: t,
        radius: 28,
        bearing: bearing,
        opacity: .5,
      );
    }
  }
}

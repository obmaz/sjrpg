import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'area_damage.dart';
import 'barbarian_vfx.dart';
import 'combat_feedback.dart';
import 'effect_visibility.dart';
import 'illustrated_combat_art.dart';
import 'physical_aim_preview.dart' show barbarianDoubleThrowHalfSpread;
import 'rpg_model.dart';
import 'skill_aim.dart';
import 'weapon_profiles.dart';

/// Paid combat actions own their follow-up hits and grounded leap trajectory.
/// The caller owns skill-slot validation, the one resource debit and cooldown.
class BarbarianCombat {
  BarbarianCombat(this.hero);
  final Guardian hero;
  Adventure get session => hero.session;
  Progress get progress => session.progress;
  static const skillIds = {
    'bash',
    'leap',
    'doubleSwing',
    'stun',
    'doubleThrow',
    'leapAttack',
    'concentrate',
    'frenzy',
    'berserk',
  };
  String? _pending;
  double _followup = 0, _concentrate = 0, _berserk = 0;
  ui.Offset? _leapFrom, _leapTo;
  double _leapElapsed = 0, _leapDuration = 0;
  bool _leapAttack = false;
  double _bearing = 0;
  BarbarianVfxArt _leapArt = BarbarianVfxArt(BarbarianVfxKind.leap);
  bool get airborne => _leapTo != null;
  bool get busy => airborne || _pending != null;
  double get airborneHeight => airborne
      ? barbarianAirborneHeight(
          _leapAttack ? BarbarianVfxKind.leapAttack : BarbarianVfxKind.leap,
          (_leapElapsed / _leapDuration).clamp(0.0, 1.0),
        )
      : 0;

  HuntEnemy? _target(SkillDef skill, {double? range}) {
    final list =
        session.mobs
            .where(
              (enemy) =>
                  session.canHitEnemy(enemy) &&
                  distanceToTargetBody(hero.body.center, enemy.body) <=
                      (range ?? progress.skillRange(skill)) &&
                  session.world.clearEnemyLine(
                    hero.body.center,
                    enemy.body.center,
                    const ui.Size(3, 3),
                  ),
            )
            .toList()
          ..sort(
            (a, b) => (a.body.center - hero.body.center).distanceSquared
                .compareTo((b.body.center - hero.body.center).distanceSquared),
          );
    return list.isEmpty ? null : list.first;
  }

  ui.Offset? _landing(SkillDef skill, SkillAim? aim) {
    final manualAim = aim != null && aim.dragged ? aim : null;
    final origin = hero.body.topLeft;
    var angle = manualAim?.angle ?? hero.bearing;
    var distance = math.min(
      manualAim?.distance ?? progress.skillRange(skill),
      progress.skillRange(skill),
    );
    if (skill.id == 'leapAttack' && manualAim == null) {
      final enemy = _target(skill);
      if (enemy != null) {
        final d = enemy.body.center - hero.body.center;
        if (distanceToTargetBody(hero.body.center, enemy.body) <=
                progress.weapon.base.contactRange &&
            !session.world.blocksEnemy(hero.body) &&
            !session.mobs.any(
              (m) =>
                  !m.isDead &&
                  !m.isRemoving &&
                  !m.encounterDormant &&
                  m.body.overlaps(hero.body),
            )) {
          return origin;
        }
        angle = math.atan2(d.dy, d.dx);
        distance = math.max(
          24,
          d.distance -
              (hero.body.longestSide + enemy.body.longestSide) / 2 -
              12,
        );
      }
    }
    final axis = ui.Offset(math.cos(angle), math.sin(angle));
    for (var length = distance; length >= 24; length -= 8) {
      final point = origin + axis * length;
      final at = Vector2(point.dx, point.dy).toOffset();
      final body = at & hero.body.size;
      if (!session.world.blocksEnemy(body) &&
          !session.mobs.any(
            (enemy) =>
                !enemy.isDead &&
                !enemy.isRemoving &&
                !enemy.encounterDormant &&
                enemy.body.overlaps(body),
          ) &&
          session.world.clearEnemyLine(origin, at, hero.body.size)) {
        return at;
      }
    }
    return null;
  }

  bool canActivate(SkillDef skill, {SkillAim? aim}) =>
      !((skill.id == 'leap' || skill.id == 'leapAttack') &&
          (session.afflictions.movementBlocked ||
              _landing(skill, aim) == null));

  ui.Offset? previewLanding(SkillDef skill, {SkillAim? aim}) =>
      _landing(skill, aim);

  double previewBearing(SkillDef skill, {SkillAim? aim}) {
    if (aim != null && aim.dragged) return aim.angle;
    if (skill.id == 'doubleThrow' || skill.id == 'leapAttack') {
      final target = _target(skill);
      if (target != null) {
        final d = target.body.center - hero.body.center;
        return math.atan2(d.dy, d.dx);
      }
    }
    return hero.bearing;
  }

  void activate(SkillDef skill, {SkillAim? aim}) {
    final kind = _kind(skill.id);
    _bearing = aim?.angle ?? hero.bearing;
    if (skill.id == 'leap' || skill.id == 'leapAttack') {
      final landing = _landing(skill, aim);
      if (landing == null) return;
      _leapFrom = hero.body.topLeft;
      _leapTo = landing;
      _leapAttack = skill.id == 'leapAttack';
      _leapArt = BarbarianVfxArt(kind);
      _leapElapsed = 0;
      _leapDuration = progress.skillMotionTime(skill);
      final d = landing - _leapFrom!;
      _bearing = d.distanceSquared > .001
          ? math.atan2(d.dy, d.dx)
          : previewBearing(skill, aim: aim);
      hero.bearing = hero.attackBearing = _bearing;
      hero.swingDuration = hero.swing = _leapDuration;
      hero.strikePose = 1;
      hero.stop();
      return;
    }
    if (skill.id == 'doubleThrow') {
      final target = aim == null ? _target(skill) : null;
      if (target != null) {
        final d = target.body.center - hero.body.center;
        _bearing = math.atan2(d.dy, d.dx);
      }
      _throw(skill, -barbarianDoubleThrowHalfSpread);
      _pending = skill.id;
      _followup = .15 / progress.skillTempo(skill);
    } else {
      if (skill.id == 'concentrate') {
        _concentrate = progress.skillMotionTime(skill);
        progress.concentrateArmorMultiplier = progress
            .concentrateDefenseMultiplier();
      } else if (skill.id == 'berserk') {
        _berserk = progress.barbarianEffectDuration(skill.id);
        progress.berserkActive = true;
      }
      _strike(skill);
      if (skill.id == 'doubleSwing' || skill.id == 'frenzy') {
        _pending = skill.id;
        _followup = .16 / progress.skillTempo(skill);
      }
    }
    if (kind != BarbarianVfxKind.doubleThrow) _visual(kind);
  }

  void _pose({int pose = 0}) {
    hero.strikes++;
    hero.attackBearing = _bearing;
    if (hero.velocity.isZero()) hero.bearing = _bearing;
    hero.strikePose = pose;
    hero.swingDuration = hero.swing = .28;
    hero.attackClock = math.max(hero.attackClock, .2);
  }

  void _strike(SkillDef skill, {bool followup = false}) {
    final enemy = _target(
      skill,
      range: skill.id == 'leapAttack'
          ? progress.weapon.base.contactRange
          : null,
    );
    if (enemy != null) {
      final delta = enemy.body.center - hero.body.center;
      _bearing = math.atan2(delta.dy, delta.dx);
    }
    _pose(
      pose: followup
          ? 1
          : skill.id == 'bash' || skill.id == 'berserk'
          ? 2
          : 0,
    );
    if (enemy == null) {
      final chests = session.attackableChests(
        hero.body.center,
        progress.skillRange(skill),
        bearing: _bearing,
        halfAngle: 1.1,
      );
      if (chests.isNotEmpty) session.breakChest(chests.first);
      return;
    }
    final critical =
        progress.weaponCriticalChance > 0 &&
        session.random.nextDouble() < progress.weaponCriticalChance;
    final damage = progress.skillDamage(skill) * (critical ? 2 : 1);
    final impulse = skill.id == 'bash'
        ? ui.Offset(math.cos(_bearing), math.sin(_bearing)) *
              (48 + progress.effectiveRank(skill.id) * 2)
        : ui.Offset.zero;
    if (session.hit(
      enemy,
      damage,
      impulse,
      origin: hero.body.center,
      impactKind: skill.id == 'berserk' ? ImpactKind.magic : ImpactKind.heavy,
      impactRank: progress.effectiveRank(skill.id),
      critical: critical,
    )) {
      if (skill.id == 'bash') {
        session.game?.add(
          BarbarianCombatVisual(
            session,
            BarbarianVfxKind.bash,
            enemy.body.center,
            bearing: _bearing,
            rank: progress.effectiveRank(skill.id),
            radius: 24,
            contactImpact: true,
          ),
        );
      }
      if (skill.id == 'stun') {
        enemy.applyStun(progress.barbarianEffectDuration(skill.id));
      }
      if (skill.id == 'frenzy') {
        progress.frenzyStacks = math.min(6, progress.frenzyStacks + 1);
        hero.frenzyTime = progress.frenzyDuration;
      }
    }
  }

  void _throw(SkillDef skill, double offset) {
    _pose(pose: offset > 0 ? 1 : 0);
    final critical =
        progress.throwingCriticalChance > 0 &&
        session.random.nextDouble() < progress.throwingCriticalChance;
    session.game?.add(
      BarbarianThrownAxe(
        session,
        hero.body.center,
        _bearing + offset,
        progress.skillDamage(skill) * (critical ? 2 : 1),
        range: progress.skillRange(skill),
        rank: progress.effectiveRank(skill.id),
        critical: critical,
        profile: progress.weapon.base.throwingProfile,
      ),
    );
  }

  /// The regular world sweep applies this delta, so airborne feet still cannot
  /// tunnel through walls, closed chests, water or the sanctuary fence.
  ui.Offset? leapDelta(ui.Offset from, double dt) {
    if (!airborne) return null;
    _leapElapsed = math.min(_leapDuration, _leapElapsed + dt);
    return ui.Offset.lerp(_leapFrom!, _leapTo!, _leapElapsed / _leapDuration)! -
        from;
  }

  void paintAirborneShadow(ui.Canvas canvas, ui.Offset feet) {
    if (airborne) {
      _leapArt.paintAirborneShadow(
        canvas,
        feet,
        (_leapElapsed / _leapDuration).clamp(0.0, 1.0),
      );
    }
  }

  void finishMovement() {
    if (!airborne || _leapElapsed < _leapDuration) return;
    final skill = progress.skills.firstWhere(
      (s) => s.id == (_leapAttack ? 'leapAttack' : 'leap'),
    );
    final crowded = session.mobs.any(
      (m) =>
          !m.isDead &&
          !m.isRemoving &&
          !m.encounterDormant &&
          m.body.overlaps(hero.body),
    );
    if (crowded || session.world.blocksEnemy(hero.body)) {
      // The committed destination can become occupied during the jump.
      hero.position.setValues(_leapFrom!.dx, _leapFrom!.dy);
    }
    _leapTo = null;
    hero.lastClearPosition = hero.body.topLeft;
    if (_leapAttack) {
      _strike(skill);
    } else {
      final radius = progress.barbarianRadius(skill.id);
      for (final enemy
          in session.mobs
              .where(
                (m) =>
                    session.canHitEnemy(m) &&
                    (m.body.center - hero.body.center).distanceSquared <=
                        radius * radius &&
                    session.world.clearEnemyLine(
                      hero.body.center,
                      m.body.center,
                      const ui.Size(3, 3),
                    ),
              )
              .take(progress.skillTargetLimit(skill))) {
        final d = enemy.body.center - hero.body.center;
        if (d.distance > .001) enemy.push(d / d.distance * 46);
        enemy.applyStun(.18);
      }
    }
    _visual(_kind(skill.id));
  }

  void update(double dt) {
    if (!session.active || dt <= 0) return;
    _concentrate = math.max(0, _concentrate - dt);
    _berserk = math.max(0, _berserk - dt);
    if (_concentrate <= 0) progress.concentrateArmorMultiplier = 1;
    progress.berserkActive = _berserk > 0;
    if (hero.frenzyTime <= 0) progress.frenzyStacks = 0;
    if (session.afflictions.movementBlocked || session.riding != null) {
      cancelActions();
      return;
    }
    final id = _pending;
    if (id == null) return;
    _followup -= dt;
    if (_followup > 0) return;
    _pending = null;
    final skill = progress.skills.firstWhere((s) => s.id == id);
    if (id == 'doubleThrow') {
      _throw(skill, barbarianDoubleThrowHalfSpread);
    } else {
      _strike(skill, followup: true);
      _visual(_kind(id));
    }
  }

  void cancelActions() {
    if (airborne) {
      hero.position.setValues(_leapFrom!.dx, _leapFrom!.dy);
      hero.lastClearPosition = hero.body.topLeft;
    }
    _pending = null;
    _leapTo = null;
  }

  void clearBuffs() {
    _concentrate = _berserk = 0;
    progress.concentrateArmorMultiplier = 1;
    progress.berserkActive = false;
    progress.frenzyStacks = 0;
    hero.frenzyTime = 0;
  }

  void dispelBuffs() {
    _concentrate = 0;
    progress.concentrateArmorMultiplier = 1;
    progress.frenzyStacks = 0;
    hero.frenzyTime = 0;
  }

  void _visual(BarbarianVfxKind kind) => session.game?.add(
    BarbarianCombatVisual(
      session,
      kind,
      hero.body.center,
      bearing: _bearing,
      rank: progress.effectiveRank(kind.name),
      radius: math.min(150, progress.weapon.base.contactRange),
    ),
  );
  BarbarianVfxKind _kind(String id) => BarbarianVfxKind.values.firstWhere(
    (v) => v.name == id,
    orElse: () => BarbarianVfxKind.bash,
  );
}

class BarbarianCombatVisual extends GameComponent with EffectVisibility {
  BarbarianCombatVisual(
    this.session,
    BarbarianVfxKind kind,
    ui.Offset at, {
    required this.bearing,
    required this.rank,
    this.radius = 72,
    this.axeImpact = false,
    this.contactImpact = false,
  }) : art = BarbarianVfxArt(kind),
       revision = session.buildRevision {
    position = Vector2(at.dx, at.dy);
  }
  final Adventure session;
  final BarbarianVfxArt art;
  final int rank, revision;
  final double bearing, radius;
  final bool axeImpact, contactImpact;
  double remaining = .32;
  @override
  ui.Rect get effectBounds => art.bounds(position.toOffset(), radius);
  @override
  void update(double dt) {
    if (revision != session.buildRevision || session.disposed) {
      removeFromParent();
      return;
    }
    if (!session.active || dt <= 0) return;
    remaining -= dt;
    if (remaining <= 0) removeFromParent();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (remaining > 0) {
      if (contactImpact) {
        IllustratedCombatArt.contact(
          session.art.effects,
          canvas,
          ui.Offset.zero,
          1 - remaining / .32,
          radius: radius,
        );
        return;
      }
      if (axeImpact) {
        art.paintAxeImpact(
          canvas,
          ui.Offset.zero,
          bearing,
          1 - remaining / .32,
        );
        return;
      }
      if (art.kind == BarbarianVfxKind.leap ||
          art.kind == BarbarianVfxKind.leapAttack) {
        art.paintLanding(
          canvas,
          progress: 1 - remaining / .32,
          radius: radius,
          heavy: art.kind == BarbarianVfxKind.leapAttack,
        );
        return;
      }
      art.paint(
        canvas,
        progress: 1 - remaining / .32,
        bearing: bearing,
        radius: radius,
        rank: rank,
      );
      // A broad magical crescent only belongs to Berserk. Physical single
      // strikes keep their directional authored blade and local hit spark.
      if (art.kind == BarbarianVfxKind.berserk) {
        IllustratedCombatArt.sequence(
          session.art.effects,
          canvas,
          CombatIllustration.blade,
          ui.Offset.zero,
          progress: 1 - remaining / .32,
          radius: math.min(96, radius),
          bearing: bearing,
          steel: art.kind != BarbarianVfxKind.berserk,
          protectBody: true,
        );
      }
    }
  }
}

class BarbarianThrownAxe extends GameComponent with EffectVisibility {
  BarbarianThrownAxe(
    this.session,
    ui.Offset at,
    double bearing,
    this.damage, {
    required this.range,
    required this.rank,
    this.critical = false,
    this.profile,
    this.generateRage = false,
    this.rageStrikeId,
  }) : direction = ui.Offset(math.cos(bearing), math.sin(bearing)),
       bearing = bearing,
       revision = session.buildRevision {
    position = Vector2(at.dx, at.dy);
  }
  final Adventure session;
  final double damage, range, bearing;
  final ui.Offset direction;
  final int rank, revision;
  final bool critical;
  final ThrownWeaponProfile? profile;
  final bool generateRage;
  final int? rageStrikeId;
  double get speed => profile?.speed ?? 700;
  double get impactRadius => profile?.impactRadius ?? 5;
  String get projectileId => profile?.id ?? 'throwingaxes';
  final _art = BarbarianVfxArt(BarbarianVfxKind.doubleThrow);
  double travelled = 0;
  bool resolved = false;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromCircle(center: position.toOffset(), radius: 28);
  void _finish() {
    resolved = true;
    removeFromParent();
  }

  @override
  void update(double dt) {
    if (resolved || !session.active || dt <= 0) return;
    if (revision != session.buildRevision) {
      _finish();
      return;
    }
    final distance = math.min(math.min(dt, .05) * speed, range - travelled);
    final steps = math.max(1, (distance / 5).ceil());
    final enemies = List<HuntEnemy>.of(session.mobs);
    for (var i = 0; i < steps; i++) {
      final from = position.toOffset(),
          next = from + direction * (distance / steps);
      final chest = session.world.firstChestOnSegment(from, next, padding: 4);
      if (chest != null) {
        final beforeContact = chest.at - direction * .5;
        if (!session.world.blocksEnemy(
          ui.Rect.fromCenter(center: beforeContact, width: 8, height: 8),
        )) {
          session.breakChest(chest.index);
        }
        _finish();
        return;
      }
      if (session.world.blocksEnemy(
        ui.Rect.fromCenter(center: next, width: 8, height: 8),
      )) {
        _finish();
        return;
      }
      position.setValues(next.dx, next.dy);
      for (final enemy in enemies) {
        if (session.canHitEnemy(enemy, origin: next) &&
            enemy.body.inflate(impactRadius).contains(next)) {
          session.hit(
            enemy,
            damage,
            direction * 12,
            origin: next,
            impactKind: ImpactKind.heavy,
            impactRank: rank,
            critical: critical,
            generateRage: generateRage,
            rageStrikeId: rageStrikeId,
          );
          session.game?.add(
            BarbarianCombatVisual(
              session,
              BarbarianVfxKind.doubleThrow,
              next,
              bearing: bearing,
              rank: rank,
              radius: 24,
              axeImpact: true,
            ),
          );
          _finish();
          return;
        }
      }
    }
    travelled += distance;
    if (travelled >= range) _finish();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (!resolved) {
      if (projectileId == 'javelin') {
        _art.paintJavelin(canvas, const ui.Offset(0, -14), bearing);
        return;
      }
      _art.paintThrownAxe(
        canvas,
        const ui.Offset(0, -14),
        bearing,
        travelled / range,
        rank: rank,
      );
    }
  }
}

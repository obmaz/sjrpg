import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'area_damage.dart';
import 'barbarian_vfx.dart';
import 'effect_visibility.dart';
import 'rpg_model.dart';

class _Corpse {
  _Corpse(
    this.at,
    this.expires, {
    required this.kind,
    required this.elite,
    required this.unique,
  });
  final String kind;
  final ui.Offset at;
  final double expires;
  final bool elite, unique;
  bool available = true;
}

class _WarcryState {
  double fearUntil = 0, tauntUntil = 0, cryUntil = 0;
  ui.Offset fearOrigin = ui.Offset.zero;
  double outgoing = 1, incoming = 1, tauntOutgoing = 1;
}

class _GrimWard {
  _GrimWard(this.at, this.until, this.radius, this.targetLimit);
  final ui.Offset at;
  final double until, radius;
  final int targetLimit;
}

/// Transient, stage-local barbarian state. The owner calls [update] with
/// simulation time, records only accepted deaths, and [clear] on reset/dispose.
/// Activation owns effects/rewards; the caller owns resource/cooldown commits.
class BarbarianUtilities {
  BarbarianUtilities(this.session) : _revision = session.buildRevision;

  final Adventure session;
  int _revision;
  // Corpse rolls must not change the loot/critical random sequence.
  late final _corpseRandom = math.Random(session.world.seed ^ 0x435250);
  double _time = 0, _wardPulse = 0;
  double _shoutUntil = 0, _ordersUntil = 0, _commandUntil = 0;
  double _shoutArmor = 1, _ordersPower = 1;
  final _corpses = <_Corpse>[];
  final _wards = <_GrimWard>[];
  final _enemies = <HuntEnemy, _WarcryState>{};
  // Weak keys prevent duplicate rewards without retaining removed monsters.
  Expando<bool> _recorded = Expando<bool>('barbarian corpse');
  static const corpseLimit = 32, enemyStateLimit = 64, wardLimit = 3;
  static const corpseLifetime = 180.0, corpseRange = 240.0;
  static const corpseChance = .10;
  static const skillIds = {
    'howl',
    'findPotion',
    'taunt',
    'shout',
    'findItem',
    'battleCry',
    'battleOrders',
    'grimWard',
    'warcry',
    'battleCommand',
  };
  static const _corpseSkills = {'findPotion', 'findItem', 'grimWard'};
  int get corpseCount => _corpses.where((c) => c.available).length;
  int get wardCount => _wards.length;
  int get enemyStateCount => _enemies.length;
  double get shoutTime => math.max(0, _shoutUntil - _time);
  double get ordersTime => math.max(0, _ordersUntil - _time);
  double get commandTime => math.max(0, _commandUntil - _time);
  double get armorMultiplier => _shoutUntil > _time ? _shoutArmor : 1;
  double get lifeMultiplier => _ordersUntil > _time ? _ordersPower : 1;
  double get resourceMultiplier => lifeMultiplier;
  int get skillBonus => _commandUntil > _time ? 1 : 0;

  ui.Offset? fearedFrom(HuntEnemy enemy) {
    final state = _enemies[enemy];
    return state != null && state.fearUntil > _time ? state.fearOrigin : null;
  }

  bool taunted(HuntEnemy enemy) => (_enemies[enemy]?.tauntUntil ?? 0) > _time;
  double outgoingDamageMultiplier(HuntEnemy enemy) {
    final state = _enemies[enemy];
    if (state == null) return 1;
    return math.min(
      state.cryUntil > _time ? state.outgoing : 1,
      state.tauntUntil > _time ? state.tauntOutgoing : 1,
    );
  }

  double incomingDamageMultiplier(HuntEnemy enemy) {
    final state = _enemies[enemy];
    return state != null && state.cryUntil > _time ? state.incoming : 1;
  }

  void recordCorpse(HuntEnemy enemy) {
    if (_revision != session.buildRevision) clear();
    if (session.disposed ||
        enemy.session != session ||
        !enemy.rewarded ||
        !enemy.isDead ||
        enemy.boss ||
        _recorded[enemy] == true) {
      return;
    }
    _recorded[enemy] = true;
    if (_corpseRandom.nextDouble() >= corpseChance) return;
    _expire();
    if (_corpses.length >= corpseLimit) {
      _corpses.removeAt(0).available = false;
    }
    final corpse = _Corpse(
      enemy.body.center,
      _time + corpseLifetime,
      kind: enemy.kind,
      elite: enemy.isElite,
      unique: enemy.isUnique,
    );
    _corpses.add(corpse);
    session.game?.add(_CorpseMarker(this, corpse));
  }

  _Corpse? _nearestCorpse(String id) {
    _Corpse? nearest;
    final range = id == 'grimWard'
        ? corpseRange
        : session.progress.barbarianRadius(id);
    var distance = range * range;
    for (final corpse in _corpses) {
      if (!corpse.available || corpse.expires <= _time) continue;
      final delta = (corpse.at - session.hero.body.center).distanceSquared;
      if (delta > distance ||
          !session.world.clearLine(
            session.hero.body.center,
            corpse.at,
            const ui.Size(3, 3),
          )) {
        continue;
      }
      nearest = corpse;
      distance = delta;
    }
    return nearest;
  }

  List<HuntEnemy> _targets(String id, {int? atRank}) {
    final p = session.progress;
    final radius = p.barbarianRadius(id, atRank: atRank);
    final skill = p.skills.firstWhere((s) => s.id == id);
    final result =
        session.mobs
            .where(
              (enemy) =>
                  session.canHitEnemy(enemy) &&
                  !enemy.encounterDormant &&
                  (enemy.body.center - session.hero.body.center).distance <=
                      radius &&
                  session.world.clearLine(
                    session.hero.body.center,
                    enemy.body.center,
                    const ui.Size(3, 3),
                  ) &&
                  (!{'howl', 'taunt'}.contains(id) ||
                      !enemy.boss && !enemy.isElite),
            )
            .toList()
          ..sort(
            (a, b) => (a.body.center - session.hero.body.center).distanceSquared
                .compareTo(
                  (b.body.center - session.hero.body.center).distanceSquared,
                ),
          );
    return result.take(p.skillTargetLimit(skill, atRank: atRank)).toList();
  }

  /// Read-only preflight. Corpse lookup and target selection consume nothing.
  bool canActivate(String id) {
    if (!skillIds.contains(id) ||
        _revision != session.buildRevision ||
        !session.active ||
        session.progress.hp <= 0 ||
        session.progress.heroClass != HeroClass.warrior ||
        session.progress.rank(id) <= 0) {
      return false;
    }
    if (_corpseSkills.contains(id)) {
      return (id != 'grimWard' || _wards.length < wardLimit) &&
          _nearestCorpse(id) != null;
    }
    if ({'howl', 'taunt', 'battleCry', 'warcry'}.contains(id)) {
      return _targets(id).isNotEmpty;
    }
    return true;
  }

  /// [rank], when supplied, is invested rank. Progress applies Battle Command
  /// once, including soft rank 21 for a fully invested barbarian skill.
  bool activate(SkillDef skill, {int? rank}) {
    final id = skill.id;
    if (!canActivate(id)) return false;
    final p = session.progress;
    final r = p.effectiveRank(id, atRank: rank);
    var at = session.hero.body.center;
    if (_corpseSkills.contains(id)) {
      final corpse = _nearestCorpse(id);
      if (corpse == null) return false;
      corpse.available = false;
      _corpses.remove(corpse);
      at = corpse.at;
      if (id == 'grimWard') {
        final ward = _GrimWard(
          at,
          _time + p.barbarianBuffDuration(id, atRank: rank),
          p.barbarianRadius(id, atRank: rank),
          p.skillTargetLimit(skill, atRank: rank),
        );
        _wards.add(ward);
        session.game?.add(_WardMarker(this, ward));
        _pulseWards();
      } else {
        // An unsuccessful search still consumes this corpse once, as in the
        // source mechanic; retrying cannot reroll a body indefinitely.
        final chance = p.barbarianFindChance(id, atRank: rank);
        if (session.random.nextDouble() < chance) {
          if (id == 'findPotion') {
            if (session.random.nextBool()) {
              session.progress.healingPotions++;
            } else {
              session.progress.energyPotions++;
            }
          } else {
            session.dropGear(
              session.progress.rollLoot(
                session.random,
                elite: corpse.elite,
                unique: corpse.unique,
              ),
              at,
            );
          }
        }
      }
    } else if (id == 'shout') {
      _shoutUntil = _time + p.barbarianBuffDuration(id, atRank: rank);
      _shoutArmor = p.shoutArmorMultiplier(atRank: rank);
    } else if (id == 'battleOrders') {
      _ordersUntil = _time + p.barbarianBuffDuration(id, atRank: rank);
      _ordersPower = p.battleOrdersMultiplier(atRank: rank);
    } else if (id == 'battleCommand') {
      _commandUntil = _time + p.barbarianBuffDuration(id, atRank: rank);
    } else {
      final targets = _targets(id, atRank: rank);
      if (targets.isEmpty) return false;
      final warcryDamage = id == 'warcry'
          ? p.skillDamage(skill, atRank: rank) *
                enemyGroupDamageScale(targets.length)
          : 0.0;
      for (final enemy in targets) {
        final state = _state(enemy);
        if (id == 'howl') {
          state.fearOrigin = at;
          state.fearUntil = _time + p.barbarianEffectDuration(id, atRank: rank);
          state.tauntUntil = 0;
        } else if (id == 'taunt') {
          state.tauntUntil =
              _time + p.barbarianEffectDuration(id, atRank: rank);
          state.fearUntil = 0;
          state.tauntOutgoing = 1 - (.08 + r * .01);
        } else if (id == 'battleCry') {
          state.cryUntil = _time + p.barbarianEffectDuration(id, atRank: rank);
          state.outgoing = p.battleCryOutgoingMultiplier(atRank: rank);
          state.incoming = p.battleCryIncomingMultiplier(atRank: rank);
        } else if (id == 'warcry') {
          if (session.hit(
            enemy,
            warcryDamage,
            ui.Offset.zero,
            origin: at,
            impactRank: r,
            hitStop: false,
          )) {
            enemy.applyStun(p.barbarianEffectDuration(id, atRank: rank));
          }
        }
      }
    }
    final kind = switch (id) {
      'warcry' => BarbarianVfxKind.warCry,
      _ => BarbarianVfxKind.values.firstWhere((v) => v.name == id),
    };
    session.game?.add(
      BarbarianUtilityVisual(
        session,
        kind,
        at,
        r,
        p.barbarianRadius(id, atRank: rank),
      ),
    );
    session.refresh();
    return true;
  }

  _WarcryState _state(HuntEnemy enemy) {
    if (!_enemies.containsKey(enemy) && _enemies.length >= enemyStateLimit) {
      _enemies.remove(_enemies.keys.first);
    }
    return _enemies.putIfAbsent(enemy, _WarcryState.new);
  }

  void _pulseWards() {
    for (final ward in _wards) {
      final targets =
          session.mobs
              .where(
                (enemy) =>
                    !enemy.boss &&
                    !enemy.isElite &&
                    !enemy.encounterDormant &&
                    session.canHitEnemy(enemy, origin: ward.at) &&
                    (enemy.body.center - ward.at).distance <= ward.radius &&
                    session.world.clearLine(
                      ward.at,
                      enemy.body.center,
                      const ui.Size(3, 3),
                    ),
              )
              .toList()
            ..sort(
              (a, b) => (a.body.center - ward.at).distanceSquared.compareTo(
                (b.body.center - ward.at).distanceSquared,
              ),
            );
      for (final enemy in targets.take(ward.targetLimit)) {
        final state = _state(enemy);
        state.fearOrigin = ward.at;
        state.fearUntil = _time + 1;
        state.tauntUntil = 0;
      }
    }
  }

  void _expire() {
    _corpses.removeWhere((corpse) {
      if (corpse.expires > _time && corpse.available) return false;
      corpse.available = false;
      return true;
    });
    _wards.removeWhere((ward) => ward.until <= _time);
    _enemies.removeWhere(
      (enemy, state) =>
          enemy.isDead ||
          enemy.isRemoving ||
          !session.mobs.contains(enemy) ||
          state.fearUntil <= _time &&
              state.tauntUntil <= _time &&
              state.cryUntil <= _time,
    );
  }

  void update(double dt) {
    if (session.disposed || _revision != session.buildRevision) {
      clear();
      return;
    }
    if (!session.active || !dt.isFinite || dt <= 0) return;
    _time += dt;
    _expire();
    _wardPulse -= dt;
    if (_wardPulse <= 0) {
      _wardPulse = .5;
      _pulseWards();
    }
  }

  /// Enemy dispels remove beneficial shouts, leaving corpse/ward ownership and
  /// already-applied hostile controls intact.
  void dispelBuffs() {
    _shoutUntil = _ordersUntil = _commandUntil = 0;
    _shoutArmor = _ordersPower = 1;
  }

  void clear() {
    for (final corpse in _corpses) {
      corpse.available = false;
    }
    _corpses.clear();
    _wards.clear();
    _enemies.clear();
    _recorded = Expando<bool>('barbarian corpse');
    _time = _wardPulse = 0;
    dispelBuffs();
    _revision = session.buildRevision;
  }
}

class BarbarianUtilityVisual extends GameComponent with EffectVisibility {
  BarbarianUtilityVisual(
    this.session,
    BarbarianVfxKind kind,
    ui.Offset at,
    this.rank,
    this.radius,
  ) : art = BarbarianVfxArt(kind),
      revision = session.buildRevision {
    position = Vector2(at.dx, at.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final BarbarianVfxArt art;
  final int rank, revision;
  final double radius;
  double age = 0;
  static const duration = .55;
  bool get finished =>
      session.disposed || revision != session.buildRevision || age >= duration;
  @override
  int get priority => 29;
  @override
  bool get isVisible => true;
  @override
  ui.Rect get effectBounds => art.bounds(position.toOffset(), radius);
  @override
  void update(double dt) {
    if (session.disposed || revision != session.buildRevision) {
      removeFromParent();
      return;
    }
    if (!session.active) return;
    age += dt;
    if (age >= duration) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    if (finished) {
      return;
    }
    art.paint(
      canvas,
      progress: age / duration,
      radius: radius,
      rank: rank,
      bearing: session.hero.bearing,
      protectBody: false,
    );
  }
}

class _WardMarker extends GameComponent with EffectVisibility {
  _WardMarker(this.owner, this.ward) : revision = owner.session.buildRevision {
    position = Vector2(ward.at.dx, ward.at.dy);
    size = Vector2.all(1);
  }
  final BarbarianUtilities owner;
  final _GrimWard ward;
  final int revision;
  final _paint = ui.Paint()
    ..color = const ui.Color(0xffc4af87)
    ..strokeWidth = 2.5
    ..strokeCap = ui.StrokeCap.round;
  bool get _present =>
      !owner.session.disposed &&
      revision == owner.session.buildRevision &&
      owner._wards.contains(ward);
  @override
  int get priority => 27;
  @override
  bool get isVisible => true;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromLTWH(ward.at.dx - 20, ward.at.dy - 44, 40, 52);
  @override
  void update(double dt) {
    if (!_present) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    if (!_present) return;
    canvas.drawLine(const ui.Offset(0, 3), const ui.Offset(0, -29), _paint);
    canvas.drawLine(
      const ui.Offset(-12, -23),
      const ui.Offset(12, -23),
      _paint,
    );
    canvas.drawOval(const ui.Rect.fromLTWH(-6, -39, 12, 13), _paint);
    canvas.drawLine(const ui.Offset(-4, -8), const ui.Offset(5, -14), _paint);
  }
}

class _CorpseMarker extends GameComponent with EffectVisibility {
  _CorpseMarker(this.owner, this.corpse)
    : revision = owner.session.buildRevision {
    position = Vector2(corpse.at.dx, corpse.at.dy);
    size = Vector2.all(1);
  }
  final BarbarianUtilities owner;
  final _Corpse corpse;
  final int revision;
  final _shadow = ui.Paint()..color = const ui.Color(0x550b1714);
  final _glint = ui.Paint()
    ..color = const ui.Color(0xffd8ce9d)
    ..strokeWidth = 1.5
    ..strokeCap = ui.StrokeCap.round;
  @override
  int get priority => 25;
  @override
  bool get isVisible => true;
  @override
  ui.Rect get effectBounds => ui.Rect.fromCircle(center: corpse.at, radius: 48);
  @override
  void update(double dt) {
    if (!corpse.available ||
        owner.session.disposed ||
        revision != owner.session.buildRevision) {
      removeFromParent();
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (!corpse.available ||
        owner.session.disposed ||
        revision != owner.session.buildRevision) {
      return;
    }
    canvas.drawOval(const ui.Rect.fromLTWH(-29, -9, 58, 20), _shadow);
    // Reuse each species' art in a quiet, collapsed ground pose: no blood or
    // extra decoded atlases. A small search glint distinguishes it from decor.
    canvas.save();
    canvas.scale(1, .55);
    canvas.rotate(-math.pi / 2);
    owner.session.art.actor(
      canvas,
      corpse.kind,
      const ui.Offset(-12, 27),
      math.pi / 2,
      0,
      64,
      opacity: .72,
    );
    canvas.restore();
    canvas.drawLine(const ui.Offset(25, -12), const ui.Offset(25, -4), _glint);
    canvas.drawLine(const ui.Offset(21, -8), const ui.Offset(29, -8), _glint);
  }
}

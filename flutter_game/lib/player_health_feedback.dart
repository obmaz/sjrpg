import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'adventure.dart';
import 'health_feedback.dart';
import 'hud_motion_clock.dart';
import 'player_afflictions.dart';

enum HealthDanger { none, low, critical }

@immutable
class HealthReading {
  const HealthReading(this.hp, this.maximum, {this.poisoned = false});
  final bool poisoned;
  final double hp, maximum;
  factory HealthReading.of(Adventure session) {
    final maximum = session.progress.maxHp;
    final safeMax = maximum.isFinite && maximum > 0 ? maximum : 1.0;
    final hp = session.progress.hp;
    return HealthReading(
      hp.isFinite ? hp.clamp(0, safeMax) : 0,
      safeMax,
      poisoned: session.afflictions.remaining(PlayerStatus.poison) > 0,
    );
  }
  double get ratio => hp / maximum;
  HealthDanger get danger => hp <= 0 || ratio > .30 && !poisoned
      ? HealthDanger.none
      : ratio < .10 || poisoned
      ? HealthDanger.critical
      : HealthDanger.low;
  String get label =>
      '생명 ${hp.ceil()} / ${maximum.ceil()}${poisoned ? ' · 중독' : ''}${switch (danger) {
        HealthDanger.none => '',
        HealthDanger.low => ' · 체력 낮음',
        HealthDanger.critical => ' · 위험',
      }}';
  @override
  bool operator ==(Object other) =>
      other is HealthReading &&
      other.hp == hp &&
      other.maximum == maximum &&
      other.poisoned == poisoned;
  @override
  int get hashCode => Object.hash(hp, maximum, poisoned);
}

/// Presentation only. Actual simulation time owns all motion; this never writes HP.
class PlayerHealthFeedback extends ChangeNotifier {
  PlayerHealthFeedback(this.session)
    : reading = ValueNotifier(HealthReading.of(session)) {
    _trail.update(0, reading.value.ratio);
    _wasVisible = visible;
  }
  final Adventure session;
  final ValueNotifier<HealthReading> reading;
  DamageTrail _trail = DamageTrail();
  double phase = 0, damageRemaining = 0, _damageStrength = 0;
  final _clock = HudMotionClock();
  bool _foreground = true, _reduced = false, _disposed = false;
  late bool _wasVisible;
  static const damageDuration = .45;
  bool get visible =>
      session.ready &&
      !session.disposed &&
      !session.defeated &&
      !session.won &&
      reading.value.hp > 0;
  bool get reducedMotion => _reduced;
  double get trailRatio => _trail.value;
  bool get needsFrames =>
      visible &&
      _clock.canObserve(
        session,
        foreground: _foreground,
        reducedMotion: _reduced,
        allowReducedMotion: true,
      ) &&
      ((!_reduced && reading.value.danger != HealthDanger.none) ||
          damageRemaining > 0 ||
          _trail.value > reading.value.ratio + .001);
  double get pulse => _reduced ? .5 : .5 - .5 * math.cos(phase * math.pi * 2);
  double get dangerOpacity {
    if (!visible) return 0;
    final low = switch (reading.value.danger) {
      HealthDanger.none => 0.0,
      HealthDanger.low => _reduced ? .065 : .055 + .045 * pulse,
      HealthDanger.critical => _reduced ? .11 : .10 + .13 * pulse,
    };
    final damage = damageRemaining <= 0
        ? 0.0
        : _damageStrength * (_reduced ? 1 : damageRemaining / damageDuration);
    return math.max(low, damage).clamp(0, .26);
  }

  /// Called by session notifications and a local ticker; notification is paint-only.
  void sample({bool foreground = true, bool reducedMotion = false}) {
    if (_disposed) return;
    final next = HealthReading.of(session), previous = reading.value;
    final foregroundChanged = foreground != _foreground;
    final active = session.active && foreground;
    final changed = next != previous;
    final maximumChanged = next.maximum != previous.maximum;
    final motionChanged = reducedMotion != _reduced;
    _foreground = foreground;
    _reduced = reducedMotion;
    var paintChanged = changed || motionChanged;
    if (changed) {
      // Equipment, checkpoint identity, hidden changes and healing never resemble a hit.
      final damage =
          !foregroundChanged &&
          active &&
          next.maximum == previous.maximum &&
          next.hp < previous.hp &&
          next.hp > 0;
      if (damage) {
        _trail.damage(previous.ratio, next.ratio);
        damageRemaining = damageDuration;
        _damageStrength = (.09 + (previous.ratio - next.ratio) * .12).clamp(
          .09,
          .14,
        );
      } else {
        _trail = DamageTrail()..update(0, next.ratio);
        if (maximumChanged || next.hp > previous.hp || foregroundChanged) {
          damageRemaining = 0;
        }
      }
      reading.value = next;
    }
    if (_reduced) _trail.update(1, next.ratio);
    final used = _clock.advance(
      session,
      foreground: foreground,
      reducedMotion: reducedMotion,
      allowReducedMotion: true,
    );
    if (used > 0) {
      final oldTrail = _trail.value, oldDamage = damageRemaining;
      if (!_reduced && next.danger != HealthDanger.none) {
        phase = (phase + used) % 1;
        paintChanged = true;
      }
      damageRemaining = math.max(0, damageRemaining - used);
      _trail.update(used, next.ratio);
      paintChanged |= oldTrail != _trail.value || oldDamage != damageRemaining;
    }
    final nowVisible = visible;
    paintChanged |= nowVisible != _wasVisible;
    _wasVisible = nowVisible;
    if (!nowVisible) {
      damageRemaining = 0;
      _clock.reset();
      paintChanged = true;
    }
    if (paintChanged) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    reading.dispose();
    super.dispose();
  }
}

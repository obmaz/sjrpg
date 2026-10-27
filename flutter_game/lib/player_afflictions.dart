import 'dart:math' as math;

enum PlayerStatus { root, freeze, poison, blind, attackSlow, moveSlow }

extension PlayerStatusInfo on PlayerStatus {
  double get duration => switch (this) {
    PlayerStatus.root => 1.4,
    PlayerStatus.freeze => .75,
    PlayerStatus.poison => 3.6,
    PlayerStatus.blind => 2.8,
    PlayerStatus.attackSlow || PlayerStatus.moveSlow => 2.6,
  };
  String get label => switch (this) {
    PlayerStatus.root => '속박',
    PlayerStatus.freeze => '빙결',
    PlayerStatus.poison => '중독',
    PlayerStatus.blind => '시야 제한',
    PlayerStatus.attackSlow => '공격 둔화',
    PlayerStatus.moveSlow => '이동 둔화',
  };
}

/// Simulation timers only. A crowd cannot refresh or alternate movement locks.
class PlayerAfflictions {
  final _remaining = {for (final status in PlayerStatus.values) status: 0.0};
  double controlGrace = 0, visionGrace = 0, poisonTick = .9, poisonPotency = 1;
  double attackGrace = 0, moveGrace = 0;
  double get attackTempo => remaining(PlayerStatus.attackSlow) > 0 ? .72 : 1;
  double get movementScale => remaining(PlayerStatus.moveSlow) > 0 ? .7 : 1;
  double remaining(PlayerStatus status) => _remaining[status]!;
  bool get frozen => remaining(PlayerStatus.freeze) > 0;
  bool get movementBlocked => frozen || remaining(PlayerStatus.root) > 0;
  Iterable<PlayerStatus> get active =>
      PlayerStatus.values.where((s) => remaining(s) > 0);

  bool apply(PlayerStatus status, {double potency = 1}) {
    if (remaining(status) > 0) return false;
    if (status == PlayerStatus.root || status == PlayerStatus.freeze) {
      if (controlGrace > 0 || movementBlocked) return false;
      controlGrace = status.duration + 1.5;
    }
    if (status == PlayerStatus.blind) {
      if (visionGrace > 0) return false;
      visionGrace = status.duration + 1.5;
    }
    if (status == PlayerStatus.attackSlow) {
      if (attackGrace > 0) return false;
      attackGrace = status.duration + .9;
    }
    if (status == PlayerStatus.moveSlow) {
      if (moveGrace > 0) return false;
      moveGrace = status.duration + .9;
    }
    if (status == PlayerStatus.poison) {
      poisonTick = .9;
      poisonPotency = potency.isFinite ? potency.clamp(1.0, 1.5).toDouble() : 1;
    }
    _remaining[status] = status.duration;
    return true;
  }

  /// Returns bounded poison ticks; the session owns mitigation and death.
  int update(double dt) {
    if (!dt.isFinite || dt <= 0) return 0;
    var ticks = 0;
    final poisoned = remaining(PlayerStatus.poison);
    if (poisoned > 0) {
      poisonTick -= math.min(dt, poisoned);
      while (poisonTick <= .00000001) {
        ticks++;
        poisonTick += .9;
      }
    }
    poisonTick = math.min(.9, poisonTick);
    for (final status in PlayerStatus.values) {
      _remaining[status] = math.max(0, remaining(status) - dt);
    }
    controlGrace = math.max(0, controlGrace - dt);
    visionGrace = math.max(0, visionGrace - dt);
    attackGrace = math.max(0, attackGrace - dt);
    moveGrace = math.max(0, moveGrace - dt);
    return ticks;
  }

  void clear() {
    for (final status in PlayerStatus.values) {
      _remaining[status] = 0;
    }
    controlGrace = visionGrace = attackGrace = moveGrace = 0;
    poisonTick = .9;
    poisonPotency = 1;
  }

  Map<String, dynamic> toSave() => {
    for (final status in PlayerStatus.values) status.name: remaining(status),
    'controlGrace': controlGrace,
    'visionGrace': visionGrace,
    'attackGrace': attackGrace,
    'moveGrace': moveGrace,
    'poisonTick': poisonTick,
    'poisonPotency': poisonPotency,
  };

  static PlayerAfflictions fromSave(Object? raw) {
    final result = PlayerAfflictions();
    if (raw == null) return result;
    const extras = {
      'controlGrace',
      'visionGrace',
      'attackGrace',
      'moveGrace',
      'poisonTick',
      'poisonPotency',
    };
    if (raw is! Map ||
        raw.keys.any(
          (key) =>
              !extras.contains(key) &&
              !PlayerStatus.values.any((s) => s.name == key),
        )) {
      throw const FormatException('Invalid player afflictions');
    }
    double read(String key, double maximum, [double fallback = 0]) {
      final value = raw[key] ?? fallback;
      if (value is! num || !value.isFinite || value < 0 || value > maximum) {
        throw const FormatException('Invalid affliction timer');
      }
      return value.toDouble();
    }

    for (final status in PlayerStatus.values) {
      result._remaining[status] = read(status.name, status.duration);
    }
    result.controlGrace = read('controlGrace', 2.9);
    result.visionGrace = read('visionGrace', 4.3);
    result.attackGrace = read('attackGrace', 3.5);
    result.moveGrace = read('moveGrace', 3.5);
    result.poisonTick = read('poisonTick', .9, .9);
    result.poisonPotency = read('poisonPotency', 1.5, 1);
    if (result.poisonPotency < 1) {
      throw const FormatException('Invalid poison potency');
    }
    if (result.poisonTick <= 0) {
      throw const FormatException('Invalid poison tick');
    }
    if (result.frozen && result.remaining(PlayerStatus.root) > 0) {
      throw const FormatException('Overlapping movement locks');
    }
    return result;
  }
}

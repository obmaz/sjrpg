import 'dart:ui';

import 'combat_balance.dart';
import 'stage_content.dart';

enum EnemyTier { normal, elite, unique }

/// Strength is sampled when an enemy appears, never while it follows the hero.
class EnemyPower {
  const EnemyPower(
    this.spawnDistance,
    this.healthMultiplier,
    this.damageMultiplier,
  );

  factory EnemyPower.forSpawn({
    required WorldStage stage,
    required Offset origin,
    required Offset at,
    EnemyTier tier = EnemyTier.normal,
    bool boss = false,
  }) => EnemyPower.atDistance(
    stage: stage,
    distance: (at - origin).distance,
    tier: tier,
    boss: boss,
  );

  factory EnemyPower.atDistance({
    required WorldStage stage,
    required double distance,
    EnemyTier tier = EnemyTier.normal,
    bool boss = false,
  }) {
    final chapter = switch (stage) {
      WorldStage.forest => 0,
      WorldStage.sands => 1,
      WorldStage.past || WorldStage.future => 2,
      WorldStage.tombs || WorldStage.foundry => 3,
      WorldStage.convergence => 4,
    };
    final sampled = distance.clamp(0.0, maximumDistance);
    // Leave the opening settlement/nearby fields gentle; outer regions ramp up.
    final outward = ((sampled - CombatBalance.nearTownRadius) / 24000).clamp(
      0.0,
      1.0,
    );
    final health = boss
        ? 1 + chapter * .12 + outward * .2
        : (1 + chapter * .18 + outward * .45) *
              (tier == EnemyTier.unique ? 1.45 : 1);
    final damage =
        (1 + chapter * .045 + outward * .12) *
        (boss || tier == EnemyTier.normal
            ? 1
            : tier == EnemyTier.unique
            ? 1.12
            : 1.06);
    final nearTown = !boss && sampled <= CombatBalance.nearTownRadius;
    return EnemyPower(
      sampled,
      health * (nearTown ? .5 : 1),
      damage.clamp(1.0, 1.5),
    );
  }

  static const maximumDistance = 43200.0;
  final double spawnDistance, healthMultiplier, damageMultiplier;
}

/// A compact immutable snapshot also survives dormant packs and stage travel.
extension EnemyPowerSave on EnemyPower {
  Map<String, double> toSave() => {
    'distance': spawnDistance,
    'health': healthMultiplier,
    'damage': damageMultiplier,
  };
  static EnemyPower fromSave(dynamic raw) {
    if (raw is! Map) throw const FormatException('Invalid enemy power');
    double read(String key, double min, double max) {
      final value = raw[key];
      if (value is! num || !value.isFinite || value < min || value > max) {
        throw const FormatException('Invalid enemy power');
      }
      return value.toDouble();
    }

    return EnemyPower(
      read('distance', 0, EnemyPower.maximumDistance),
      read('health', .5, 4),
      read('damage', 1, 1.5),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui';

import 'combat_balance.dart';
import 'stage_content.dart';

enum EnemyTier { normal, elite, unique }

/// Different species invest their growth in endurance, damage or armor.
class EnemyGrowth {
  const EnemyGrowth(this.endurance, this.offense, this.armor);
  final double endurance, offense, armor;
  static EnemyGrowth forKind(String kind, {bool boss = false}) => boss
      ? const EnemyGrowth(1.3, 1.05, .28)
      : switch (kind) {
          'troll' || 'mummy' => const EnemyGrowth(1.4, .8, .16),
          'skeleton' ||
          'cyber' ||
          'crystal-beetle' => const EnemyGrowth(1.05, .9, .35),
          'wolf' ||
          'boar' ||
          'viper' ||
          'bonehound' => const EnemyGrowth(.8, 1.25, 0),
          'cultist' ||
          'basilisk' ||
          'gunner' ||
          'drone' ||
          'clockwork-spider' => const EnemyGrowth(.85, 1.15, .10),
          'scorpion' => const EnemyGrowth(1.1, 1.0, .22),
          'wraith' => const EnemyGrowth(.9, 1.15, .18),
          _ => const EnemyGrowth(1, 1, 0),
        };
}

/// Strength is sampled when an enemy appears, never while it follows the hero.
class EnemyPower {
  const EnemyPower(
    this.spawnDistance,
    this.healthMultiplier,
    this.damageMultiplier, {
    this.level = 1,
    this.defense = 0,
  });

  static int chapter(WorldStage stage) => switch (stage) {
    WorldStage.forest => 1,
    WorldStage.sands => 2,
    WorldStage.past || WorldStage.future => 3,
    WorldStage.tombs || WorldStage.foundry => 4,
    WorldStage.convergence => 5,
  };
  static int maximumLevel(WorldStage stage) => chapter(stage) * 20;

  factory EnemyPower.forSpawn({
    required WorldStage stage,
    required Offset origin,
    required Offset at,
    EnemyTier tier = EnemyTier.normal,
    bool boss = false,
    String kind = 'goblin',
  }) => EnemyPower.atDistance(
    stage: stage,
    distance: (at - origin).distance,
    tier: tier,
    boss: boss,
    kind: kind,
  );

  factory EnemyPower.atDistance({
    required WorldStage stage,
    required double distance,
    EnemyTier tier = EnemyTier.normal,
    bool boss = false,
    String kind = 'goblin',
  }) {
    final sampled = distance.clamp(0.0, maximumDistance);
    final outward = ((sampled - 600) / 24000).clamp(0.0, 1.0);
    final cap = maximumLevel(stage);
    final level = boss ? cap : cap - 19 + (outward * 18).floor();
    final growth = EnemyGrowth.forKind(kind, boss: boss);
    final health =
        math.pow(1 + (level - 1) * .09, growth.endurance).toDouble() *
        (tier == EnemyTier.unique ? 1.45 : 1);
    final damage =
        math.pow(1 + (level - 1) * .035, growth.offense).toDouble() *
        (boss || tier == EnemyTier.normal
            ? 1
            : tier == EnemyTier.unique
            ? 1.12
            : 1.06);
    final nearTown = !boss && sampled <= CombatBalance.nearTownRadius;
    return EnemyPower(
      sampled,
      health * (nearTown ? .5 : 1),
      damage,
      level: level,
      defense: growth.armor * (level - 1) / 99,
    );
  }

  static const maximumDistance = 43200.0;
  final int level;

  /// Fraction of incoming damage absorbed by armor (0..1).
  final double defense;
  final double spawnDistance, healthMultiplier, damageMultiplier;
  double mitigate(double incoming) => incoming * (1 - defense);
}

/// A compact immutable snapshot also survives dormant packs and stage travel.
extension EnemyPowerSave on EnemyPower {
  Map<String, num> toSave() => {
    'version': 2,
    'distance': spawnDistance,
    'health': healthMultiplier,
    'damage': damageMultiplier,
    'level': level,
    'defense': defense,
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

    final legacy = raw['version'] == null;
    final level = legacy ? 1 : raw['level'];
    if ((!legacy && raw['version'] != 2) ||
        level is! int ||
        level < 1 ||
        level > 100) {
      throw const FormatException('Invalid enemy level');
    }
    return EnemyPower(
      read('distance', 0, EnemyPower.maximumDistance),
      read('health', .5, 100),
      read('damage', 1, 20),
      level: level,
      defense: legacy ? 0 : read('defense', 0, .65),
    );
  }
}

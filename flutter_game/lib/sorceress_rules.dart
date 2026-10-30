import 'dart:math' as math;

enum SorceressDamageType { none, cold, lightning, fire }

/// One cast's simulation-time parameters. Damage already includes global
/// balance, hard-point synergies and Fire/Lightning Mastery, exactly once.
/// Cold Mastery remains resistance penetration at the target, not raw damage.
class SorceressSpellStats {
  const SorceressSpellStats({
    required this.id,
    required this.rank,
    required this.damageType,
    this.manaCost = 0,
    this.manaPerSecond = 0,
    this.minimumStartMana = 0,
    this.castDelay = 0,
    this.motionTime = .48,
    this.minDamage = 0,
    this.maxDamage = 0,
    this.damagePerSecond = 0,
    this.minDamagePerSecond = 0,
    this.maxDamagePerSecond = 0,
    this.range = 500,
    this.radius = 0,
    this.projectileCount = 1,
    this.maxTargets = 1,
    this.duration = 0,
    this.groundDuration = 0,
    this.interval = 0,
    this.slowFraction = 0,
    this.freezeDuration = 0,
    this.chillDuration = 0,
    this.attackRatingBonus = 0,
    this.armorMultiplier = 1,
    this.damageAbsorb = 0,
    this.shieldManaPerDamage = 2,
    this.currentHpFraction = 0,
    this.staticBossFloor = .5,
    this.lightningBounces = 0,
    this.boltSpeed = 600,
    this.pierces = false,
    this.timerGroup = '',
  });

  final String id, timerGroup;
  final int rank, projectileCount, maxTargets, lightningBounces;
  final SorceressDamageType damageType;
  final double manaCost, manaPerSecond, minimumStartMana;
  final double castDelay, motionTime, minDamage, maxDamage;
  final double damagePerSecond, minDamagePerSecond, maxDamagePerSecond;
  final double range, radius, duration, interval, slowFraction, freezeDuration;
  final double groundDuration;
  final double chillDuration, attackRatingBonus;
  final double armorMultiplier, damageAbsorb, shieldManaPerDamage;
  final double currentHpFraction, staticBossFloor, boltSpeed;
  final bool pierces;

  int get orbBurstCount =>
      id == 'frozenOrb' ? (projectileCount * 16 / 46).round() : 0;
  int get orbTrailCount =>
      id == 'frozenOrb' ? projectileCount - orbBurstCount : 0;

  double get meanDamage => (minDamage + maxDamage) / 2;
  double get armorBonusPercent => (armorMultiplier - 1) * 100;
  double get shieldAbsorb => damageAbsorb;
  double get manaPerDamage => shieldManaPerDamage;
  double get retaliationDamage => meanDamage;
  double get enchantFireMin => id == 'enchant' ? minDamage : 0;
  double get enchantFireMax => id == 'enchant' ? maxDamage : 0;
  double get enchantFireDamage => (enchantFireMin + enchantFireMax) / 2;
}

class _SorceressRule {
  const _SorceressRule(
    this.mana,
    this.manaStep,
    this.manaShift,
    this.minimumMana,
    this.min,
    this.max,
    this.minSteps,
    this.maxSteps,
    this.hitShift,
    this.synergies,
  );
  final double mana, manaStep, minimumMana, min, max;
  final int manaShift, hitShift;
  final List<double> minSteps, maxSteps;
  final Map<String, double> synergies;
}

const _rules = <String, _SorceressRule>{
  "firebolt": _SorceressRule(
    5.0,
    0.0,
    7,
    1.0,
    6.0,
    12.0,
    [3.0, 4.0, 8.0, 18.0, 54.0],
    [3.0, 6.0, 10.0, 20.0, 56.0],
    7,
    {"fireball": 0.16, "meteor": 0.16},
  ),
  "warmth": _SorceressRule(
    0.0,
    0.0,
    8,
    0.0,
    0.0,
    0.0,
    [0.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0],
    8,
    {},
  ),
  "chargedBolt": _SorceressRule(
    24.0,
    4.0,
    5,
    1.0,
    4.0,
    8.0,
    [1.0, 1.0, 2.0, 3.0, 4.0],
    [1.0, 1.0, 2.0, 3.0, 4.0],
    7,
    {"lightning": 0.06},
  ),
  "iceBolt": _SorceressRule(
    3.0,
    0.0,
    8,
    1.0,
    6.0,
    10.0,
    [2.0, 4.0, 6.0, 8.0, 10.0],
    [3.0, 5.0, 7.0, 9.0, 11.0],
    7,
    {
      "frostNova": 0.15,
      "iceBlast": 0.15,
      "glacialSpike": 0.15,
      "blizzard": 0.15,
      "frozenOrb": 0.15,
    },
  ),
  "frozenArmor": _SorceressRule(
    7.0,
    0.0,
    8,
    1.0,
    0.0,
    0.0,
    [0.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0],
    8,
    {},
  ),
  "inferno": _SorceressRule(
    36.0,
    1.0,
    2,
    0.0,
    32.0,
    64.0,
    [24.0, 26.0, 28.0, 32.0, 36.0],
    [24.0, 27.0, 29.0, 33.0, 37.0],
    2,
    {"warmth": 0.13},
  ),
  "staticField": _SorceressRule(
    9.0,
    0.0,
    8,
    1.0,
    0.0,
    0.0,
    [0.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0],
    8,
    {},
  ),
  "telekinesis": _SorceressRule(
    7.0,
    0.0,
    8,
    1.0,
    1.0,
    2.0,
    [1.0, 1.0, 1.0, 1.0, 1.0],
    [1.0, 1.0, 1.0, 1.0, 1.0],
    8,
    {},
  ),
  "frostNova": _SorceressRule(
    9.0,
    1.0,
    8,
    1.0,
    4.0,
    8.0,
    [4.0, 6.0, 8.0, 10.0, 12.0],
    [5.0, 7.0, 9.0, 11.0, 13.0],
    7,
    {"blizzard": 0.1, "frozenOrb": 0.1},
  ),
  "iceBlast": _SorceressRule(
    12.0,
    1.0,
    7,
    1.0,
    16.0,
    24.0,
    [14.0, 28.0, 42.0, 56.0, 70.0],
    [15.0, 29.0, 43.0, 57.0, 71.0],
    7,
    {"iceBolt": 0.08, "blizzard": 0.08, "frozenOrb": 0.08},
  ),
  "blaze": _SorceressRule(
    22.0,
    1.0,
    7,
    1.0,
    4.0,
    8.0,
    [2.0, 3.0, 4.0, 6.0, 9.0],
    [2.0, 3.0, 4.0, 6.0, 9.0],
    4,
    {"warmth": 0.04, "firewall": 0.01},
  ),
  "fireball": _SorceressRule(
    10.0,
    1.0,
    7,
    1.0,
    12.0,
    28.0,
    [13.0, 23.0, 28.0, 33.0, 38.0],
    [15.0, 25.0, 30.0, 35.0, 40.0],
    7,
    {"firebolt": 0.14, "meteor": 0.14},
  ),
  "nova": _SorceressRule(
    15.0,
    1.0,
    8,
    1.0,
    1.0,
    20.0,
    [6.0, 7.0, 8.0, 9.0, 10.0],
    [8.0, 9.0, 10.0, 11.0, 12.0],
    8,
    {},
  ),
  "lightning": _SorceressRule(
    16.0,
    1.0,
    7,
    1.0,
    1.0,
    40.0,
    [0.0, 0.0, 0.0, 0.0, 0.0],
    [8.0, 12.0, 20.0, 28.0, 36.0],
    8,
    {"chargedBolt": 0.08, "chainLightning": 0.08, "nova": 0.08},
  ),
  "shiverArmor": _SorceressRule(
    11.0,
    0.0,
    8,
    1.0,
    12.0,
    16.0,
    [4.0, 6.0, 8.0, 10.0, 12.0],
    [5.0, 7.0, 9.0, 11.0, 13.0],
    7,
    {"frozenArmor": 0.09, "chillingArmor": 0.09},
  ),
  "firewall": _SorceressRule(
    22.0,
    1.0,
    8,
    1.0,
    15.0,
    20.0,
    [9.0, 14.0, 21.0, 21.0, 21.0],
    [9.0, 14.0, 21.0, 21.0, 21.0],
    4,
    {"warmth": 0.04, "inferno": 0.01},
  ),
  "enchant": _SorceressRule(
    25.0,
    1.0,
    8,
    1.0,
    16.0,
    20.0,
    [3.0, 7.0, 11.0, 15.0, 19.0],
    [5.0, 9.0, 13.0, 17.0, 21.0],
    7,
    {"warmth": 0.09},
  ),
  "chainLightning": _SorceressRule(
    9.0,
    1.0,
    8,
    1.0,
    1.0,
    40.0,
    [0.0, 0.0, 0.0, 0.0, 0.0],
    [11.0, 13.0, 15.0, 15.0, 15.0],
    8,
    {"chargedBolt": 0.04, "lightning": 0.04, "nova": 0.04},
  ),
  "blink": _SorceressRule(
    24.0,
    -1.0,
    8,
    1.0,
    0.0,
    0.0,
    [0.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0],
    8,
    {},
  ),
  "glacialSpike": _SorceressRule(
    20.0,
    1.0,
    7,
    1.0,
    32.0,
    48.0,
    [14.0, 26.0, 28.0, 30.0, 32.0],
    [15.0, 27.0, 29.0, 31.0, 33.0],
    7,
    {"iceBolt": 0.05, "iceBlast": 0.05, "frozenOrb": 0.05},
  ),
  "meteor": _SorceressRule(
    34.0,
    1.0,
    7,
    1.0,
    80.0,
    100.0,
    [23.0, 39.0, 79.0, 81.0, 83.0],
    [25.0, 41.0, 81.0, 83.0, 85.0],
    8,
    {"firebolt": 0.05, "fireball": 0.05},
  ),
  "thunderStorm": _SorceressRule(
    19.0,
    0.0,
    8,
    1.0,
    1.0,
    100.0,
    [10.0, 10.0, 11.0, 11.0, 11.0],
    [10.0, 10.0, 11.0, 11.0, 11.0],
    8,
    {},
  ),
  "energyShield": _SorceressRule(
    5.0,
    0.0,
    8,
    1.0,
    20.0,
    0.0,
    [5.0, 2.0, 1.0, 1.0, 1.0],
    [0.0, 0.0, 0.0, 0.0, 0.0],
    8,
    {},
  ),
  "blizzard": _SorceressRule(
    23.0,
    1.0,
    8,
    1.0,
    45.0,
    75.0,
    [15.0, 30.0, 45.0, 55.0, 65.0],
    [16.0, 31.0, 46.0, 56.0, 66.0],
    8,
    {"iceBolt": 0.05, "iceBlast": 0.05, "glacialSpike": 0.05},
  ),
  "chillingArmor": _SorceressRule(
    17.0,
    0.0,
    8,
    1.0,
    8.0,
    12.0,
    [2.0, 4.0, 6.0, 8.0, 10.0],
    [3.0, 5.0, 7.0, 9.0, 11.0],
    7,
    {"frozenArmor": 0.07, "shiverArmor": 0.07},
  ),
  "fireMastery": _SorceressRule(
    0.0,
    0.0,
    8,
    0.0,
    0.0,
    0.0,
    [0.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0],
    8,
    {},
  ),
  "hydra": _SorceressRule(
    40.0,
    1.0,
    7,
    1.0,
    28.0,
    39.0,
    [11.0, 15.0, 19.0, 23.0, 27.0],
    [13.0, 17.0, 21.0, 25.0, 29.0],
    7,
    {"firebolt": 0.03, "fireball": 0.03},
  ),
  "lightningMastery": _SorceressRule(
    0.0,
    0.0,
    8,
    0.0,
    0.0,
    0.0,
    [0.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0],
    8,
    {},
  ),
  "frozenOrb": _SorceressRule(
    50.0,
    1.0,
    7,
    1.0,
    80.0,
    90.0,
    [20.0, 24.0, 28.0, 29.0, 30.0],
    [21.0, 25.0, 29.0, 30.0, 31.0],
    7,
    {"iceBolt": 0.02},
  ),
  "coldMastery": _SorceressRule(
    0.0,
    0.0,
    8,
    0.0,
    0.0,
    0.0,
    [0.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0],
    8,
    {},
  ),
};

/// Original Skills.txt / Missiles.txt numbers use 25 simulation frames/second.
/// Source curves use one sub-tile per 24 world pixels. Mobile rank scaling
/// weakens one-point skills and reaches the source potency at rank twenty.
abstract final class SorceressRules {
  static const framesPerSecond = 25.0;
  static const worldSubtile = 24.0;

  static double _curve(double base, List<double> steps, int rank) {
    var remaining = math.max(0, rank - 1), result = base;
    const spans = [7, 8, 6, 6];
    for (var i = 0; i < steps.length; i++) {
      final count = i < spans.length
          ? math.min(remaining, spans[i])
          : remaining;
      result += count * steps[i];
      remaining -= count;
    }
    return result;
  }

  static double _diminishing(int rank, double minimum, double maximum) =>
      (minimum + (maximum - minimum) * (110 * rank ~/ (rank + 6)) / 100)
          .floorToDouble();

  // A learned skill starts useful without granting its fully trained utility.
  static double _rankProgress(int rank) => (rank.clamp(1, 20) - 1) / 19;
  static double _damagePotency(int rank) =>
      rank <= 0 ? 0 : .6 + .4 * _rankProgress(rank);
  static double _utilityPotency(int rank) =>
      rank <= 0 ? 0 : .4 + .6 * _rankProgress(rank);
  static double _reachPotency(int rank) => .75 + .25 * _rankProgress(rank);

  static double fireMastery(int rank) =>
      rank <= 0 ? 1 : 1 + (.30 + (rank - 1) * .07) * _utilityPotency(rank);
  static double lightningMastery(int rank) =>
      rank <= 0 ? 1 : 1 + (.50 + (rank - 1) * .12) * _utilityPotency(rank);
  static double coldPierce(int rank) =>
      rank <= 0 ? 0 : (.20 + (rank - 1) * .05) * _utilityPotency(rank);
  static double warmthMultiplier(int rank) =>
      rank <= 0 ? 1 : 1 + (.30 + (rank - 1) * .12) * _utilityPotency(rank);

  static SorceressSpellStats evaluate(
    String id, {
    required int rank,
    required Map<String, int> hardRanks,
    double damageScale = 1,
  }) {
    final rule = _rules[id];
    if (rule == null || rank <= 0) {
      return SorceressSpellStats(
        id: id,
        rank: 0,
        damageType: SorceressDamageType.none,
        projectileCount: 0,
        maxTargets: 0,
      );
    }
    final r = rank.clamp(1, 21), n = r - 1;
    int hard(String key) => (hardRanks[key] ?? 0).clamp(0, 20);
    final cold = const {
      'iceBolt',
      'frozenArmor',
      'frostNova',
      'iceBlast',
      'shiverArmor',
      'glacialSpike',
      'blizzard',
      'chillingArmor',
      'frozenOrb',
      'coldMastery',
    }.contains(id);
    final electric = const {
      'chargedBolt',
      'staticField',
      'telekinesis',
      'nova',
      'lightning',
      'chainLightning',
      'thunderStorm',
      'energyShield',
      'lightningMastery',
    }.contains(id);
    final type = id == 'blink' || id == 'warmth'
        ? SorceressDamageType.none
        : cold
        ? SorceressDamageType.cold
        : electric
        ? SorceressDamageType.lightning
        : SorceressDamageType.fire;
    final mastery = type == SorceressDamageType.fire
        ? fireMastery(hard('fireMastery'))
        : type == SorceressDamageType.lightning
        ? lightningMastery(hard('lightningMastery'))
        : 1.0;
    final synergy =
        1 +
        rule.synergies.entries.fold<double>(
          0,
          (sum, entry) => sum + hard(entry.key) * entry.value,
        );
    final scale =
        damageScale *
        _damagePotency(r) *
        mastery *
        synergy *
        math.pow(2, rule.hitShift - 8);
    var minDamage = _curve(rule.min, rule.minSteps, r) * scale;
    var maxDamage = _curve(rule.max, rule.maxSteps, r) * scale;
    var minDps = 0.0, maxDps = 0.0;
    if (const {'inferno', 'blaze', 'firewall'}.contains(id)) {
      final samples = id == 'inferno' ? 25.0 : 75.0;
      minDps = minDamage * samples;
      maxDps = maxDamage * samples;
      minDamage = maxDamage = 0;
    }
    if (id == 'meteor') {
      final burnScale =
          damageScale *
          _damagePotency(r) *
          mastery *
          (1 + hard('inferno') * .03) *
          75 /
          32;
      minDps = _curve(15, const [4, 5, 6, 6, 6], r) * burnScale;
      maxDps = _curve(25, const [4, 5, 6, 6, 6], r) * burnScale;
    }
    if (id == 'energyShield') minDamage = maxDamage = 0;
    final mana = math
        .max(
          rule.minimumMana,
          (rule.mana + rule.manaStep * n) * math.pow(2, rule.manaShift - 8),
        )
        .toDouble();
    final delay = switch (id) {
      'firewall' => 35 / 25,
      'meteor' => 30 / 25,
      'blizzard' => 45 / 25,
      'hydra' => 40 / 25,
      'frozenOrb' => 25 / 25,
      _ => 0.0,
    };
    final duration = switch (id) {
      'frozenArmor' =>
        (3000 + 300 * n + (hard('shiverArmor') + hard('chillingArmor')) * 250) /
            25,
      'shiverArmor' =>
        (3000 + 300 * n + (hard('frozenArmor') + hard('chillingArmor')) * 250) /
            25,
      'chillingArmor' =>
        (3600 + 150 * n + (hard('frozenArmor') + hard('shiverArmor')) * 250) /
            25,
      'enchant' => (3600 + 600 * n) / 25,
      'thunderStorm' => (800 + 200 * n) / 25,
      'energyShield' => (3600 + 1500 * n) / 25,
      'hydra' => 250 / 25,
      'blizzard' => 100 / 25,
      'firewall' => 90 / 25,
      'blaze' => _diminishing(r, 50, 500) / 25,
      'inferno' => .08,
      _ => 0.0,
    };
    final radius = switch (id) {
      'staticField' => (5 + n) * worldSubtile,
      'frostNova' => 9 * worldSubtile,
      'nova' => 12 * worldSubtile,
      'glacialSpike' => 4 * worldSubtile,
      'meteor' => 6 * worldSubtile,
      'blizzard' => 7 * worldSubtile,
      'thunderStorm' => 17 * worldSubtile,
      'fireball' => 4 * worldSubtile,
      'firewall' => 3 * worldSubtile,
      'blaze' => 2 * worldSubtile,
      'inferno' => 2 * worldSubtile,
      _ => 0.0,
    };
    final chill = switch (id) {
      'iceBolt' => (150 + n * 35) / 25,
      'frostNova' || 'frozenOrb' => (200 + n * 25) / 25,
      'shiverArmor' =>
        (100 + math.max(0, r - 8) * 25 + math.max(0, r - 16) * 25) / 25,
      'chillingArmor' => (100 + math.max(0, r - 8) * 25) / 25,
      'blizzard' => 100 / 25,
      _ => 0.0,
    };
    final freeze = switch (id) {
      'frozenArmor' =>
        (30 + n * 3) *
            (1 + (hard('shiverArmor') + hard('chillingArmor')) * .05) /
            25,
      'iceBlast' => (75 + n * 5) * (1 + hard('glacialSpike') * .10) / 25,
      'glacialSpike' => (50 + n * 3) * (1 + hard('blizzard') * .03) / 25,
      _ => 0.0,
    };
    final bolts = switch (id) {
      'chargedBolt' => math.min(24, 3 + n),
      'hydra' => 3,
      'frozenOrb' => 18 + (28 * _rankProgress(r)).round(),
      _ => 1,
    };
    final areaTargets = 3 + n;
    final bounces = id == 'chainLightning'
        ? math.min((26 + n) ~/ 5, areaTargets)
        : 0;
    final targets = switch (id) {
      'firebolt' ||
      'iceBolt' ||
      'iceBlast' ||
      'telekinesis' ||
      'thunderStorm' => 1,
      'chargedBolt' => bolts,
      'chainLightning' => bounces,
      'blink' ||
      'frozenArmor' ||
      'shiverArmor' ||
      'chillingArmor' ||
      'energyShield' ||
      'enchant' ||
      'warmth' ||
      'fireMastery' ||
      'lightningMastery' ||
      'coldMastery' => 0,
      _ => areaTargets,
    };
    return SorceressSpellStats(
      id: id,
      rank: r,
      damageType: type,
      manaCost: id == 'inferno' ? 0 : mana,
      manaPerSecond: id == 'inferno' ? mana * 25 * .5 : 0,
      minimumStartMana: id == 'inferno' ? 6 : mana,
      castDelay: delay,
      timerGroup: delay > 0 ? 'sorceress-delay' : '',
      motionTime: const {'lightning', 'chainLightning'}.contains(id)
          ? .76
          : .52,
      minDamage: minDamage,
      maxDamage: maxDamage,
      minDamagePerSecond: minDps,
      maxDamagePerSecond: maxDps,
      damagePerSecond: (minDps + maxDps) / 2,
      range:
          (switch (id) {
                'inferno' => (20 + n * 3) / 4 * worldSubtile,
                'frozenOrb' => 300.0,
                'blink' => 600.0,
                'telekinesis' => 25 * worldSubtile,
                _ => 600.0,
              }) *
              _reachPotency(r) -
          // Keep every rank's original increment after halving rank one's reach.
          (id == 'blink' ? 600 * _reachPotency(1) * .5 : 0),
      radius: radius * _reachPotency(r),
      projectileCount: bolts,
      maxTargets: targets,
      duration: duration,
      groundDuration: switch (id) {
        'meteor' => (30 + 15 * n) / 25,
        'blaze' => (90 + 25 * n) / 25,
        'firewall' => 90 / 25,
        _ => 0.0,
      },
      interval: switch (id) {
        'inferno' => .08,
        'blizzard' => 4 / 25,
        'hydra' => 1.0,
        'thunderStorm' => (125 - _diminishing(r, 0, 100)) / 25,
        _ => .2,
      },
      slowFraction: chill > 0 || freeze > 0 ? .55 : 0,
      chillDuration: chill * _utilityPotency(r),
      freezeDuration: freeze * _utilityPotency(r),
      armorMultiplier: switch (id) {
        'frozenArmor' => 1 + (.30 + n * .05) * _utilityPotency(r),
        'shiverArmor' => 1 + (.45 + n * .06) * _utilityPotency(r),
        'chillingArmor' => 1 + (.45 + n * .05) * _utilityPotency(r),
        _ => 1.0,
      },
      damageAbsorb: id == 'energyShield'
          ? (_curve(20, const [5, 2, 1, 1, 1], r) / 100 * _utilityPotency(r))
                .clamp(0.0, .95)
          : 0,
      shieldManaPerDamage: (32 - hard('telekinesis')) / 16,
      attackRatingBonus: id == 'enchant'
          ? (20.0 + n * 9) * _utilityPotency(r)
          : 0,
      currentHpFraction: id == 'staticField' ? .25 * _utilityPotency(r) : 0,
      lightningBounces: bounces,
      boltSpeed: switch (id) {
        'chargedBolt' || 'iceBolt' => 12 * 25,
        'glacialSpike' || 'hydra' => 16 * 25,
        'frozenOrb' => 10 * 25,
        _ => 20 * 25,
      },
      pierces: id == 'lightning',
    );
  }
}

import 'dart:math' as math;
import 'dart:ui';

import 'adventure.dart';
import 'rpg_model.dart';
import 'sorceress_rules.dart';
import 'sorceress_vfx.dart';

class _Defense {
  _Defense(this.stats, this.remaining);
  final SorceressSpellStats stats;
  double remaining;
}

/// Cast snapshots and simulation-time lifetimes for the Sorceress buffs.
/// Armor is a defense multiplier; Energy Shield consumes mana before armor.
class SorceressDefenses {
  SorceressDefenses(this.session);
  final Adventure session;
  final _buffs = <String, _Defense>{};
  double _time = 0, _thunderClock = 0;
  static const armorIds = {'frozenArmor', 'shiverArmor', 'chillingArmor'};
  static const skillIds = {
    ...armorIds,
    'energyShield',
    'enchant',
    'thunderStorm',
  };
  String? get armorId => _buffs.keys.where(armorIds.contains).firstOrNull;
  double get armorTime => _remaining(armorId);
  double get energyShieldTime => _remaining('energyShield');
  double get enchantTime => _remaining('enchant');
  double get thunderStormTime => _remaining('thunderStorm');
  bool get hasBuffs => _buffs.isNotEmpty;
  double _remaining(String? id) => _buffs[id]?.remaining ?? 0;
  double get enchantDamage => _buffs['enchant']?.stats.enchantFireDamage ?? 0;
  double get enchantMinDamage => _buffs['enchant']?.stats.enchantFireMin ?? 0;
  double get enchantMaxDamage => _buffs['enchant']?.stats.enchantFireMax ?? 0;
  double get armorMultiplier => _buffs[armorId]?.stats.armorMultiplier ?? 1;
  double get shieldAbsorb => _buffs['energyShield']?.stats.shieldAbsorb ?? 0;

  bool activate(String id, SorceressSpellStats stats) {
    if (!session.active ||
        session.progress.heroClass != HeroClass.mage ||
        !skillIds.contains(id) ||
        stats.id != id ||
        stats.rank <= 0 ||
        session.progress.rank(id) <= 0 ||
        !stats.duration.isFinite ||
        stats.duration <= 0) {
      return false;
    }
    _set(stats, stats.duration);
    return true;
  }

  void _set(SorceressSpellStats stats, double remaining) {
    if (armorIds.contains(stats.id)) {
      _buffs.removeWhere((id, _) => armorIds.contains(id));
    }
    _buffs[stats.id] = _Defense(stats, remaining);
    if (stats.id == 'thunderStorm') _thunderClock = stats.interval;
    _sync();
  }

  void _sync() {
    session.progress.sorceressArmorMultiplier = armorMultiplier;
  }

  void update(double dt) {
    if (!session.active || !dt.isFinite || dt <= 0) return;
    if (session.progress.heroClass != HeroClass.mage) {
      clear();
      return;
    }
    _time += dt;
    for (final buff in _buffs.values) {
      buff.remaining -= dt;
    }
    _buffs.removeWhere(
      (id, value) => value.remaining <= 0 || session.progress.rank(id) <= 0,
    );
    _sync();
    final storm = _buffs['thunderStorm'];
    if (storm == null) {
      _thunderClock = 0;
      return;
    }
    _thunderClock -= dt;
    if (_thunderClock > 0 || !session.combatAllowed) return;
    // One strike per engine update; do not replay a backlog after a long frame.
    _thunderClock = math.max(.1, storm.stats.interval);
    final candidates = session.mobs
        .where(
          (enemy) =>
              session.canHitEnemy(enemy) &&
              (enemy.body.center - session.hero.body.center).distance <=
                  (storm.stats.radius > 0
                      ? storm.stats.radius
                      : storm.stats.range) &&
              session.world.clearEnemyLine(
                session.hero.body.center,
                enemy.body.center,
                const Size(3, 3),
              ),
        )
        .toList();
    if (candidates.isNotEmpty) {
      session.hero.sorceressCombat.thunderStrike(
        candidates[session.random.nextInt(candidates.length)],
      );
    }
  }

  double modifyIncomingDamage(double damage, {bool periodic = false}) {
    if (!damage.isFinite || damage <= 0) return 0;
    final shield = _buffs['energyShield'];
    // Poison bypasses D2 Energy Shield. Player periodic damage is poison.
    if (periodic || shield == null || !session.active) return damage;
    final cost = shield.stats.manaPerDamage;
    if (!cost.isFinite || cost <= 0) return damage;
    final absorb = math
        .min(
          damage * shield.stats.shieldAbsorb.clamp(0, .95),
          session.progress.energy / cost,
        )
        .clamp(0.0, damage);
    session.progress.energy = math.max(
      0,
      session.progress.energy - absorb * cost,
    );
    if (session.progress.energy <= 1e-9) {
      session.progress.energy = 0;
      _buffs.remove('energyShield');
    }
    return damage - absorb;
  }

  void onMeleeHit(HuntEnemy enemy) {
    onMeleeAttempt(enemy);
    onHit(enemy, melee: true);
  }

  void onMeleeAttempt(HuntEnemy enemy) {
    final armor = _buffs['shiverArmor'];
    if (armor == null ||
        !session.canHitEnemy(enemy) ||
        !session.world.clearEnemyLine(
          session.hero.body.center,
          enemy.body.center,
          const Size(3, 3),
        )) {
      return;
    }
    session.hero.sorceressCombat.applyColdHit(
      enemy,
      armor.stats.retaliationDamage,
      slowDuration: armor.stats.chillDuration,
    );
  }

  void onHit(HuntEnemy enemy, {required bool melee}) {
    final id = armorId;
    final armor = _buffs[id];
    if (armor == null ||
        !session.canHitEnemy(enemy) ||
        !session.world.clearEnemyLine(
          session.hero.body.center,
          enemy.body.center,
          const Size(3, 3),
        )) {
      return;
    }
    final combat = session.hero.sorceressCombat;
    switch (id) {
      case 'frozenArmor' when melee:
        combat.applyColdHit(
          enemy,
          0,
          freezeDuration: armor.stats.freezeDuration,
          slowDuration: armor.stats.chillDuration,
        );
      case 'chillingArmor' when !melee:
        combat.retaliateIceBolt(enemy, amount: armor.stats.retaliationDamage);
    }
  }

  void drawBuff(Canvas canvas, Offset center) {
    for (final entry in _buffs.entries) {
      SorceressVfx.buff(
        canvas,
        entry.key,
        center,
        time: _time,
        rank: entry.value.stats.rank,
      );
    }
  }

  void clear() {
    _buffs.clear();
    _thunderClock = _time = 0;
    _sync();
  }

  Map<String, dynamic> captureState() => {
    'version': 1,
    'buffs': [
      for (final entry in _buffs.entries)
        {
          'id': entry.key,
          'rank': entry.value.stats.rank,
          'remaining': entry.value.remaining,
        },
    ],
    'thunderClock': _thunderClock,
  };

  /// Reject forged timers, unknown skills and simultaneous armor types.
  /// Only ranks and remaining lifetimes persist; damage is recomputed from
  /// validated character points rather than trusting arbitrary saved numbers.
  static Map<String, dynamic>? validateState(dynamic raw, Progress progress) {
    if (raw == null) {
      return {'version': 1, 'buffs': <dynamic>[], 'thunderClock': 0.0};
    }
    if (raw is! Map || raw['version'] != 1 || raw['buffs'] is! List) {
      return null;
    }
    final buffs = raw['buffs'] as List;
    if (buffs.length > 4 ||
        progress.heroClass != HeroClass.mage && buffs.isNotEmpty) {
      return null;
    }
    final ids = <String>{};
    var armors = 0;
    final validated = <Map<String, dynamic>>[];
    var interval = 0.0;
    for (final buff in buffs) {
      if (buff is! Map) return null;
      final id = buff['id'], rank = buff['rank'], remaining = buff['remaining'];
      if (id is! String ||
          !skillIds.contains(id) ||
          !ids.add(id) ||
          rank is! int ||
          rank <= 0 ||
          rank > progress.rank(id) ||
          remaining is! num ||
          !remaining.isFinite ||
          remaining <= 0) {
        return null;
      }
      final skill = progress.skills.where((s) => s.id == id).firstOrNull;
      if (skill == null || rank > skill.rankLimit) return null;
      final stats = progress.sorceressSpell(skill, atRank: rank);
      if (remaining > stats.duration + .0001) return null;
      if (armorIds.contains(id) && ++armors > 1) return null;
      if (id == 'thunderStorm') interval = stats.interval;
      validated.add({
        'id': id,
        'rank': rank,
        'remaining': remaining.toDouble(),
      });
    }
    final clock = raw['thunderClock'] ?? 0;
    if (clock is! num ||
        !clock.isFinite ||
        clock < 0 ||
        clock > interval + .0001) {
      return null;
    }
    return {'version': 1, 'buffs': validated, 'thunderClock': clock.toDouble()};
  }

  bool restoreState(Map<String, dynamic> raw) {
    final validated = validateState(raw, session.progress);
    if (validated == null) return false;
    clear();
    for (final value in validated['buffs'] as List) {
      final buff = value as Map;
      final skill = session.progress.skills.firstWhere(
        (s) => s.id == buff['id'],
      );
      _set(
        session.progress.sorceressSpell(skill, atRank: buff['rank'] as int),
        buff['remaining'] as double,
      );
    }
    _thunderClock = validated['thunderClock'] as double;
    return true;
  }
}

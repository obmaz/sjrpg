import 'combat_balance.dart';
import 'rpg_model.dart';
import 'sorceress_rules.dart';

class SkillPreviewValue {
  const SkillPreviewValue(
    this.label,
    this.current,
    this.next, {
    this.suffix = '',
    this.digits = 0,
    this.zeroAsDash = false,
  });
  final String label, suffix;
  final double current, next;
  final int digits;
  final bool zeroAsDash;
  String format(double value) {
    if (zeroAsDash && value == 0) return '—';
    final shown = switch (suffix) {
      '초' => CombatBalance.realSeconds(value),
      'px/초' || '/초' => value * CombatBalance.gameSpeed,
      _ => value,
    };
    return '${shown.toStringAsFixed(digits)}$suffix';
  }
}

Progress _nextRank(Progress p, SkillDef skill) {
  final rank = p.rank(skill.id);
  final next = Progress(heroClass: p.heroClass)
    ..level = p.level
    ..bonusAttack = p.bonusAttack
    ..bonusHealth = p.bonusHealth
    ..selectedBasic = p.selectedBasic
    ..activeSkillBonus = p.activeSkillBonus
    ..frenzyStacks = p.frenzyStacks
    ..activeLifeMultiplier = p.activeLifeMultiplier
    ..activeResourceMultiplier = p.activeResourceMultiplier
    ..activeArmorMultiplier = p.activeArmorMultiplier
    ..concentrateArmorMultiplier = p.concentrateArmorMultiplier
    ..berserkActive = p.berserkActive
    ..sorceressArmorMultiplier = p.sorceressArmorMultiplier;
  next.equipped
    ..clear()
    ..addAll(p.equipped);
  next.ranks
    ..clear()
    ..addAll(p.ranks)
    ..[skill.id] = (rank + 1).clamp(1, skill.rankLimit);
  return next;
}

List<SkillPreviewValue> _barbarianStats(Progress p, SkillDef skill) {
  final next = _nextRank(p, skill), id = skill.id;
  SkillPreviewValue value(
    String label,
    double Function(Progress) read, {
    String suffix = '',
    int digits = 1,
  }) => SkillPreviewValue(
    label,
    read(p),
    read(next),
    suffix: suffix,
    digits: digits,
  );
  double learned(Progress q, double Function() read) =>
      q.rank(id) == 0 ? 0 : read();
  if (const {
    'swordMastery',
    'axeMastery',
    'maceMastery',
    'polearmMastery',
    'throwingMastery',
    'spearMastery',
  }.contains(id)) {
    return [
      value('해당 무기 피해 증가', (q) => q.effectiveRank(id) * 2.0, suffix: '%'),
      value(
        '해당 무기 치명타',
        (q) => learned(
          q,
          () => (3 + q.effectiveRank(id) * .4).clamp(0, 15).toDouble(),
        ),
        suffix: '%',
      ),
    ];
  }
  switch (id) {
    case 'increasedStamina':
      return [
        value(
          '질주 지속 배율',
          (q) => q.staminaDurationMultiplier * 100,
          suffix: '%',
        ),
      ];
    case 'ironSkin':
      return [value('방어력', (q) => q.armor)];
    case 'increasedSpeed':
      return [
        value('도보 속도 배율', (q) => q.increasedSpeedMultiplier * 100, suffix: '%'),
      ];
    case 'naturalResistance':
      return [
        value(
          '상태 이상 시간 감소',
          (q) => q.barbarianStatusResistance * 100,
          suffix: '%',
        ),
      ];
    case 'findPotion':
    case 'findItem':
      return [
        value('발견 확률', (q) => q.barbarianFindChance(id) * 100, suffix: '%'),
        value(
          '시체 조사 거리',
          (q) => q.barbarianRadius(id),
          suffix: 'px',
          digits: 0,
        ),
      ];
    case 'shout':
      return [
        value(
          '방어력 증가',
          (q) => learned(q, () => (q.shoutArmorMultiplier() - 1) * 100),
          suffix: '%',
        ),
        value('지속 시간', (q) => q.barbarianBuffDuration(id), suffix: '초'),
      ];
    case 'battleOrders':
      return [
        value(
          '최대 생명·분노 증가',
          (q) => learned(q, () => (q.battleOrdersMultiplier() - 1) * 100),
          suffix: '%',
        ),
        value('지속 시간', (q) => q.barbarianBuffDuration(id), suffix: '초'),
      ];
    case 'battleCommand':
      return [
        value('배운 기술 등급 증가', (q) => q.rank(id) > 0 ? 1 : 0, digits: 0),
        value('지속 시간', (q) => q.barbarianBuffDuration(id), suffix: '초'),
      ];
    case 'battleCry':
      return [
        value(
          '적 공격 감소',
          (q) => learned(q, () => (1 - q.battleCryOutgoingMultiplier()) * 100),
          suffix: '%',
        ),
        value(
          '적 받는 피해 증가',
          (q) => learned(q, () => (q.battleCryIncomingMultiplier() - 1) * 100),
          suffix: '%',
        ),
        value('지속 시간', (q) => q.barbarianEffectDuration(id), suffix: '초'),
      ];
    case 'howl':
    case 'taunt':
    case 'grimWard':
      return [
        value('효과 반경', (q) => q.barbarianRadius(id), suffix: 'px', digits: 0),
        value(
          '지속 시간',
          (q) => id == 'grimWard'
              ? q.barbarianBuffDuration(id)
              : q.barbarianEffectDuration(id),
          suffix: '초',
        ),
      ];
    case 'leap':
      return [
        value('도약 거리', (q) => q.skillRange(skill), suffix: 'px', digits: 0),
        value(
          '착지 밀침 반경',
          (q) => q.barbarianRadius(id),
          suffix: 'px',
          digits: 0,
        ),
      ];
  }
  final result = <SkillPreviewValue>[
    value(
      id == 'doubleSwing' || id == 'doubleThrow' || id == 'frenzy'
          ? '한 타격 피해'
          : id == 'whirlwind'
          ? '회전 한 차례 피해'
          : '기술 피해',
      (q) => q.skillDamage(skill),
      digits: 2,
    ),
  ];
  if (const {'doubleSwing', 'doubleThrow', 'frenzy'}.contains(id)) {
    result.add(const SkillPreviewValue('연속 타격', 2, 2, suffix: '회'));
  }
  if (id == 'stun' || id == 'warcry') {
    result.add(
      value(
        '기절 시간',
        (q) => q.barbarianEffectDuration(id),
        suffix: '초',
        digits: 2,
      ),
    );
  }
  if (id == 'leapAttack' || id == 'doubleThrow') {
    result.add(
      value('사거리', (q) => q.skillRange(skill), suffix: 'px', digits: 0),
    );
  }
  if (id == 'concentrate') {
    result.add(
      value(
        '공격 중 방어 배율',
        (q) => q.concentrateDefenseMultiplier() * 100,
        suffix: '%',
      ),
    );
  }
  if (id == 'berserk') {
    result.add(const SkillPreviewValue('광폭화 중 방어력', 0, 0));
    result.add(
      value('방어력 상실 시간', (q) => q.barbarianEffectDuration(id), suffix: '초'),
    );
  }
  if (id == 'frenzy') {
    result.add(value('강화 유지', (q) => q.frenzyDuration, suffix: '초'));
    result.add(
      value(
        '최대 중첩 공격 속도 증가',
        (q) => 6 * (.02 + q.effectiveRank(id) * .001) * 100,
        suffix: '%',
      ),
    );
  }
  return result;
}

List<SkillPreviewValue> _sorceressStats(Progress p, SkillDef skill) {
  final next = _nextRank(p, skill), id = skill.id;
  final current = p.sorceressSpell(skill),
      upgraded = next.sorceressSpell(skill);
  SkillPreviewValue stat(
    String label,
    double Function(SorceressSpellStats) read, {
    String suffix = '',
    int digits = 2,
    bool zeroAsDash = false,
  }) => SkillPreviewValue(
    label,
    read(current),
    read(upgraded),
    suffix: suffix,
    digits: digits,
    zeroAsDash: zeroAsDash,
  );
  SkillPreviewValue passive(
    String label,
    double Function(Progress) read, {
    String suffix = '%',
    int digits = 1,
  }) => SkillPreviewValue(
    label,
    read(p),
    read(next),
    suffix: suffix,
    digits: digits,
  );
  switch (id) {
    case 'warmth':
      return [
        passive(
          '마나 회복 증가',
          (q) =>
              (SorceressRules.warmthMultiplier(q.effectiveRank(id)) - 1) * 100,
        ),
        passive('마나 회복', (q) => q.manaRecovery, suffix: '/초', digits: 2),
      ];
    case 'fireMastery':
      return [passive('화염 피해 증가', (q) => (q.fireDamageMultiplier - 1) * 100)];
    case 'lightningMastery':
      return [
        passive('번개 피해 증가', (q) => (q.lightningDamageMultiplier - 1) * 100),
      ];
    case 'coldMastery':
      return [passive('냉기 저항 관통', (q) => q.sorceressColdPierce * 100)];
  }
  final rows = <SkillPreviewValue>[
    stat('마나 소모', (s) => s.manaCost),
    if (current.manaPerSecond > 0 || upgraded.manaPerSecond > 0) ...[
      stat('유지 마나', (s) => s.manaPerSecond, suffix: '/초'),
      stat('시작에 필요한 마나', (s) => s.minimumStartMana),
    ],
    stat('공통 시전 지연', (s) => s.castDelay, suffix: '초', zeroAsDash: true),
    SkillPreviewValue(
      '시전 동작',
      current.rank == 0 ? 0 : p.skillMotionTime(skill),
      next.skillMotionTime(skill),
      suffix: '초',
      digits: 3,
    ),
  ];
  if (current.maxDamage > 0 || upgraded.maxDamage > 0) {
    final prefix = id == 'enchant'
        ? '추가 화염'
        : const {'frozenArmor', 'shiverArmor', 'chillingArmor'}.contains(id)
        ? '반격'
        : '1회';
    rows.addAll([
      stat('$prefix 최소 피해', (s) => s.minDamage),
      stat('$prefix 최대 피해', (s) => s.maxDamage),
    ]);
  }
  if (skill.basic) {
    rows.addAll([
      stat(
        '발사 투사체',
        (s) => s.projectileCount.toDouble(),
        suffix: '개',
        digits: 0,
      ),
      SkillPreviewValue(
        '투사체 1개 초당 피해',
        current.rank == 0 ? 0 : current.meanDamage / p.attackIntervalFor(skill),
        upgraded.meanDamage / next.attackIntervalFor(skill),
        suffix: '/초',
        digits: 2,
      ),
    ]);
  } else if (id == 'hydra' || id == 'frozenOrb') {
    rows.add(
      stat(
        id == 'hydra' ? '불뱀 머리' : '얼음 파편',
        (s) => s.projectileCount.toDouble(),
        suffix: '개',
        digits: 0,
      ),
    );
  }
  if (current.maxDamagePerSecond > 0 || upgraded.maxDamagePerSecond > 0) {
    rows.addAll([
      stat('최소 지속 피해', (s) => s.minDamagePerSecond, suffix: '/초'),
      stat('최대 지속 피해', (s) => s.maxDamagePerSecond, suffix: '/초'),
    ]);
  }
  if (id == 'staticField') {
    rows.addAll([
      stat('현재 생명 피해', (s) => s.currentHpFraction * 100, suffix: '%'),
      stat(
        '보스 최소 남은 생명',
        (s) => s.rank == 0 ? 0 : s.staticBossFloor * 100,
        suffix: '%',
      ),
    ]);
  }
  if (current.lightningBounces > 0 || upgraded.lightningBounces > 0) {
    rows.add(
      stat(
        '연쇄 적중',
        (s) => s.lightningBounces.toDouble(),
        suffix: '명',
        digits: 0,
      ),
    );
  }
  if (current.maxTargets > 0 || upgraded.maxTargets > 0) {
    rows.add(
      stat(
        id == 'hydra' ? '한 차례 최대 대상' : '최대 대상',
        (s) =>
            (id == 'hydra' && s.projectileCount < s.maxTargets
                    ? s.projectileCount
                    : s.maxTargets)
                .toDouble(),
        suffix: '명',
        digits: 0,
      ),
    );
  }
  if (id == 'blink' ||
      const {
        'firebolt',
        'chargedBolt',
        'iceBolt',
        'iceBlast',
        'glacialSpike',
        'fireball',
        'frozenOrb',
        'hydra',
        'telekinesis',
        'lightning',
        'chainLightning',
        'inferno',
        'meteor',
        'blizzard',
        'firewall',
        'thunderStorm',
      }.contains(id)) {
    rows.add(
      stat(
        id == 'blink' ? '순간이동 거리' : '사거리',
        (s) => s.rank == 0 ? 0 : s.range,
        suffix: 'px',
        digits: 0,
      ),
    );
  }
  if ((current.radius > 0 || upgraded.radius > 0) && id != 'thunderStorm') {
    rows.add(stat('효과 반경', (s) => s.radius, suffix: 'px', digits: 0));
  }
  if (id != 'inferno' && (current.duration > 0 || upgraded.duration > 0)) {
    rows.add(stat('효과 지속', (s) => s.duration, suffix: '초'));
  }
  if (current.groundDuration > 0 || upgraded.groundDuration > 0) {
    rows.add(stat('바닥 불길 지속', (s) => s.groundDuration, suffix: '초'));
  }
  if (const {'inferno', 'blizzard', 'hydra', 'thunderStorm'}.contains(id)) {
    rows.add(
      stat(
        id == 'hydra' || id == 'thunderStorm' ? '공격 간격' : '피해 판정 간격',
        (s) => s.rank == 0 ? 0 : s.interval,
        suffix: '초',
        digits: 3,
      ),
    );
  }
  if (current.freezeDuration > 0 || upgraded.freezeDuration > 0) {
    rows.add(stat('빙결 시간', (s) => s.freezeDuration, suffix: '초'));
  }
  if (current.chillDuration > 0 || upgraded.chillDuration > 0) {
    rows.add(stat('냉기 감속 시간', (s) => s.chillDuration, suffix: '초'));
  }
  if (current.slowFraction > 0 || upgraded.slowFraction > 0) {
    rows.add(stat('냉기 감속', (s) => s.slowFraction * 100, suffix: '%'));
  }
  if (current.armorMultiplier > 1 || upgraded.armorMultiplier > 1) {
    rows.add(stat('방어력 증가', (s) => (s.armorMultiplier - 1) * 100, suffix: '%'));
  }
  if (id == 'energyShield') {
    rows.addAll([
      stat('피해 흡수율', (s) => s.damageAbsorb * 100, suffix: '%'),
      stat('피해 1당 마나', (s) => s.rank == 0 ? 0 : s.shieldManaPerDamage),
    ]);
  }
  return rows;
}

List<SkillPreviewValue> _previewStats(Progress p, SkillDef skill) {
  if (!p.skills.contains(skill)) return const [];
  if (p.isSorceressSpell(skill)) return _sorceressStats(p, skill);
  if (p.heroClass == HeroClass.warrior && skill.rankLimit == 20) {
    return _barbarianStats(p, skill);
  }
  final next = _nextRank(p, skill);
  SkillPreviewValue value(
    String label,
    double Function(Progress) read, {
    String suffix = '',
    int digits = 0,
  }) => SkillPreviewValue(
    label,
    read(p),
    read(next),
    suffix: suffix,
    digits: digits,
  );
  switch (skill.id) {
    case 'shadowAssault':
      return [
        value(
          '연속 타격 대상',
          (p) => p.skillTargetLimit(skill).toDouble(),
          suffix: '명',
        ),
        value(
          '첫 타격 피해',
          (p) => p.skillDamage(skill) * p.shadowAssaultStrikeScale(1),
          digits: 2,
        ),
        value(
          '마지막 타격 피해',
          (p) =>
              p.skillDamage(skill) *
              p.shadowAssaultStrikeScale(p.rank(skill.id)),
          digits: 2,
        ),
        const SkillPreviewValue('추가 피해 예산', 20, 20, suffix: '%'),
        const SkillPreviewValue('주변 추가 대상', 2, 2, suffix: '명'),
      ];
    case 'battleSprint':
      return [
        value(
          '질주 지속',
          (p) => p.rank(skill.id) == 0 ? 0 : p.mobilityDuration,
          suffix: '초',
          digits: 1,
        ),
        value(
          '이동 속도',
          (p) => p.rank(skill.id) == 0 ? 0 : CombatBalance.sprintMoveSpeed,
          suffix: 'px/초',
        ),
      ];
    default:
      return [value('기본 1타 피해', (p) => p.skillDamage(skill), digits: 2)];
  }
}

List<SkillPreviewValue> previewSkill(Progress p, SkillDef skill) {
  final rows = _previewStats(p, skill);
  if (rows.isEmpty || p.isSorceressSpell(skill)) return rows;
  final upgraded = _nextRank(p, skill), r = p.rank(skill.id);
  final next = (r + 1).clamp(1, skill.rankLimit);
  final basic = skill.basic;
  final priority = <SkillPreviewValue>[];
  if (p.heroClass == HeroClass.warrior && !skill.passive && !skill.mobility) {
    priority.add(
      SkillPreviewValue(
        '분노 소모',
        p.skillCost(skill),
        upgraded.skillCost(skill),
        digits: 2,
      ),
    );
  }
  if (basic) {
    priority.add(
      SkillPreviewValue(
        '기본 공격 간격',
        r == 0 ? 0 : p.attackIntervalFor(skill),
        upgraded.attackIntervalFor(skill),
        suffix: '초',
        digits: 3,
        zeroAsDash: true,
      ),
    );
  } else if (skill.mobility) {
    priority.add(
      SkillPreviewValue(
        '재사용 대기',
        p.mobilityCooldown,
        upgraded.mobilityCooldown,
        suffix: '초',
        digits: 2,
        zeroAsDash: true,
      ),
    );
  } else if (!skill.passive) {
    priority.add(
      SkillPreviewValue(
        '재사용 대기',
        p.skillCooldown(skill),
        upgraded.skillCooldown(skill),
        suffix: '초',
        digits: 2,
        zeroAsDash: true,
      ),
    );
    priority.add(
      SkillPreviewValue(
        skill.id == 'frenzy' ? '공격 속도' : '동작 속도',
        r == 0
            ? 0
            : (skill.id == 'frenzy'
                      ? p.frenzyAttackTempo
                      : p.skillTempo(skill)) *
                  100,
        (skill.id == 'frenzy'
                ? upgraded.frenzyAttackTempo
                : upgraded.skillTempo(skill)) *
            100,
        suffix: '%',
        zeroAsDash: true,
      ),
    );
    if (skill.id == 'crushingBlow') {
      priority.add(
        SkillPreviewValue(
          '완전 충전',
          r == 0 ? 0 : p.heavyChargeTime,
          upgraded.heavyChargeTime,
          suffix: '초',
          digits: 2,
          zeroAsDash: true,
        ),
      );
    }
  }
  if (basic ||
      !skill.passive &&
          !skill.mobility &&
          !const {
            'shout',
            'battleOrders',
            'battleCommand',
            'grimWard',
          }.contains(skill.id)) {
    priority.add(
      SkillPreviewValue(
        '최대 대상',
        (basic
                ? p.basicTargetLimitForRank(r, basic: skill)
                : p.skillTargetLimit(skill))
            .toDouble(),
        (basic
                ? p.basicTargetLimitForRank(next, basic: skill)
                : p.skillTargetLimit(skill, atRank: next))
            .toDouble(),
        suffix: '명',
      ),
    );
  }
  return [...priority, ...rows];
}

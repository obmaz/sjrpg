import 'combat_balance.dart';
import 'rpg_model.dart';

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
    ..berserkActive = p.berserkActive;
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

List<SkillPreviewValue> _previewStats(Progress p, SkillDef skill) {
  if (!p.skills.contains(skill)) return const [];
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
  final damage = value(
    skill.id == 'whirlwind'
        ? '회전 1회 피해'
        : skill.id == 'chainLightning'
        ? '첫 대상 피해'
        : skill.basic
        ? '기본 1타 피해'
        : '기술 피해',
    (p) => p.skillDamage(skill),
    digits: 2,
  );
  SkillPreviewValue protection() => value(
    '피해 감소',
    (p) => p.rank(skill.id) == 0 ? 0 : p.skillProtection(skill.id) * 100,
    suffix: '%',
    digits: 1,
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
    case 'blink':
      return [
        value(
          '이동 거리',
          (p) => p.rank(skill.id) == 0 ? 0 : p.mobilityRange,
          suffix: 'px',
        ),
      ];
    case 'rendingEdge':
      return [value('기본 1타 피해', (p) => p.basicDamage, digits: 2)];
    case 'stormOfSteel':
    case 'cinderReach':
    case 'forkedStorm':
      final ids = skill.id == 'stormOfSteel'
          ? ['whirlwind', 'seismicSlam']
          : [skill.id == 'cinderReach' ? 'meteor' : 'chainLightning'];
      return [
        for (final id in ids)
          value(
            '${p.skills.firstWhere((s) => s.id == id).name} 대상',
            (p) => p
                .skillTargetLimit(
                  p.skills.firstWhere((s) => s.id == id),
                  atRank: p.rank(id).clamp(1, 5),
                )
                .toDouble(),
            suffix: '명',
          ),
        for (final id in ids)
          value(
            '${p.skills.firstWhere((s) => s.id == id).shortName} 재사용',
            (p) => p.skillCooldown(
              p.skills.firstWhere((s) => s.id == id),
              atRank: p.rank(id).clamp(1, 5),
            ),
            suffix: '초',
            digits: 2,
          ),
        for (final id in ids)
          value(
            '${p.skills.firstWhere((s) => s.id == id).name} 피해${p.rank(id) == 0 ? ' · 1등급' : ''}',
            (p) => p.skillDamage(
              p.skills.firstWhere((s) => s.id == id),
              atRank: p.rank(id).clamp(1, SkillDef.maxRank),
            ),
            digits: 2,
          ),
      ];
    case 'weaponTempo':
      return [
        value('기본 공격 간격', (p) => p.attackInterval, suffix: '초', digits: 3),
      ];
    case 'veteranGuard':
      return [value('방어력', (p) => p.armor)];
    case 'secondWind':
    case 'phoenixHeart':
      return [value('최대 생명', (p) => p.maxHp)];
    case 'resoundingCry':
      return [
        value(
          '함성 피해',
          (p) => p.skillDamage(
            p.skills.firstWhere((s) => s.id == 'warcry'),
            atRank: p.rank('warcry').clamp(1, 5),
          ),
          digits: 2,
        ),
      ];
    case 'warDrums':
      return [
        value('보호 중 적중 분노', (p) => p.rageOnHit(protected: true), digits: 1),
      ];
    case 'unyieldingOath':
    case 'frozenAegis':
      final id = skill.id == 'unyieldingOath' ? 'warcry' : 'iceArmor';
      return [
        value(
          '피해 감소',
          (p) => p.skillProtection(id, atRank: p.rank(id).clamp(1, 5)) * 100,
          suffix: '%',
          digits: 1,
        ),
      ];
    case 'emberFocus':
      return [
        value('화염 피해 배율', (p) => p.fireDamageMultiplier * 100, suffix: '%'),
      ];
    case 'deepFreeze':
      return [
        value('냉기 피해 배율', (p) => p.coldDamageMultiplier * 100, suffix: '%'),
      ];
    case 'conductivity':
      return [
        value(
          '번개 피해 배율',
          (p) => p.lightningDamageMultiplier * 100,
          suffix: '%',
        ),
      ];
    case 'glacialReserve':
      return [value('최대 마나', (p) => p.maxEnergy)];
    case 'arcaneEconomy':
      return [
        value('최대 마나', (p) => p.maxEnergy),
        value('마나 회복', (p) => p.manaRecovery, suffix: '/초', digits: 1),
      ];
    case 'charge':
      return [damage];
    case 'crushingBlow':
      return [
        damage,
        value('최대 충전 피해', (p) => p.skillDamage(skill) * 1.8, digits: 2),
      ];
    case 'warcry':
      return [
        damage,
        protection(),
        value('보호 지속', (p) => p.warcryDuration, suffix: '초', digits: 2),
      ];
    case 'frenzy':
      return [
        damage,
        value('강화 지속', (p) => p.frenzyDuration, suffix: '초', digits: 2),
      ];
    case 'iceArmor':
      return [
        protection(),
        value('보호 지속', (p) => p.iceArmorDuration, suffix: '초', digits: 2),
      ];
    case 'frostNova':
      return [
        damage,
        value('감속 지속', (p) => p.novaSlowDuration, suffix: '초', digits: 2),
      ];
    case 'mastery':
    case 'arcaneMastery':
      return [
        value('기초 공격력', (p) => p.swordDamage, digits: 2),
        if (skill.id == 'arcaneMastery') value('최대 마나', (p) => p.maxEnergy),
      ];
    case 'ironSkin':
      return [value('방어력', (p) => p.armor), value('최대 생명', (p) => p.maxHp)];
    case 'battleFocus':
      return [
        value('기본 공격 간격', (p) => p.attackInterval, suffix: '초', digits: 3),
      ];
    case 'battleVigor':
      return [
        value('최대 생명', (p) => p.maxHp),
        value(
          '함성 피해 감소',
          (p) => p.rank('warcry') == 0 ? 0 : p.skillProtection('warcry') * 100,
          suffix: '%',
          digits: 1,
        ),
      ];
    case 'rallyingVoice':
      return [
        value('보호 중 적중 분노', (p) => p.rageOnHit(protected: true), digits: 1),
      ];
    case 'warmth':
      return [value('마나 회복', (p) => p.manaRecovery, suffix: '/초', digits: 1)];
    case 'coldMastery':
      return [
        value('냉기 피해 배율', (p) => p.coldDamageMultiplier * 100, suffix: '%'),
      ];
    case 'lightningMastery':
      return [
        value(
          '번개 피해 배율',
          (p) => p.lightningDamageMultiplier * 100,
          suffix: '%',
        ),
      ];
    default:
      return [damage];
  }
}

List<SkillPreviewValue> previewSkill(Progress p, SkillDef skill) {
  final rows = _previewStats(p, skill);
  if (rows.isEmpty) return rows;
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
          skill.id != 'iceArmor' &&
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

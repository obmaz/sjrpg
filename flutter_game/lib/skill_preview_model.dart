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
  String format(double value) => zeroAsDash && value == 0
      ? '—'
      : '${value.toStringAsFixed(digits)}$suffix';
}

Progress _nextRank(Progress p, SkillDef skill) {
  final rank = p.rank(skill.id);
  final next = Progress(heroClass: p.heroClass)
    ..level = p.level
    ..bonusAttack = p.bonusAttack
    ..bonusHealth = p.bonusHealth
    ..selectedBasic = p.selectedBasic;
  next.equipped
    ..clear()
    ..addAll(p.equipped);
  next.ranks
    ..clear()
    ..addAll(p.ranks)
    ..[skill.id] = (rank + 1).clamp(1, SkillDef.maxRank);
  return next;
}

List<SkillPreviewValue> _previewStats(Progress p, SkillDef skill) {
  if (!p.skills.contains(skill)) return const [];
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
    digits: 1,
  );
  SkillPreviewValue protection() => value(
    '피해 감소',
    (p) => p.rank(skill.id) == 0 ? 0 : p.skillProtection(skill.id) * 100,
    suffix: '%',
    digits: 1,
  );
  switch (skill.id) {
    case 'rendingEdge':
      return [value('기본 1타 피해', (p) => p.basicDamage, digits: 1)];
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
            digits: 1,
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
          digits: 1,
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
        value('최대 충전 피해', (p) => p.skillDamage(skill) * 1.8, digits: 1),
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
        value('기초 공격력', (p) => p.swordDamage, digits: 1),
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
  final next = (r + 1).clamp(1, SkillDef.maxRank);
  final basic = skill.basic;
  final priority = <SkillPreviewValue>[];
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
  if (basic || !skill.passive && skill.id != 'iceArmor') {
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

import 'rpg_model.dart';

class SkillPreviewValue {
  const SkillPreviewValue(
    this.label,
    this.current,
    this.next, {
    this.suffix = '',
    this.digits = 0,
  });
  final String label, suffix;
  final double current, next;
  final int digits;
  String format(double value) => '${value.toStringAsFixed(digits)}$suffix';
}

List<SkillPreviewValue> _previewStats(Progress p, SkillDef skill) {
  if (!p.skills.contains(skill)) return const [];
  final rank = p.rank(skill.id);
  final next = Progress(heroClass: p.heroClass)
    ..level = p.level
    ..bonusAttack = p.bonusAttack
    ..bonusHealth = p.bonusHealth;
  next.equipped
    ..clear()
    ..addAll(p.equipped);
  next.ranks
    ..clear()
    ..addAll(p.ranks)
    ..[skill.id] = (rank + 1).clamp(1, SkillDef.maxRank);
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
        : skill.id == 'cleave' || skill.id == 'firebolt'
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
    case 'warcry':
      return [
        damage,
        protection(),
        value('보호 지속', (p) => p.warcryDuration, suffix: '초', digits: 1),
      ];
    case 'iceArmor':
      return [protection()];
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
        value('함성 지속', (p) => p.warcryDuration, suffix: '초', digits: 1),
      ];
    case 'rallyingVoice':
      return [value('보호 중 적중 분노', (p) => p.rageOnHit(protected: true))];
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
  final basic = skill.id == 'cleave' || skill.id == 'firebolt';
  if (basic || !skill.passive && skill.id != 'iceArmor') {
    final r = p.rank(skill.id), next = (r + 1).clamp(1, SkillDef.maxRank);
    rows.add(
      SkillPreviewValue(
        '최대 대상',
        (basic ? p.basicTargetLimitForRank(r) : p.skillTargetLimit(skill))
            .toDouble(),
        (basic
                ? p.basicTargetLimitForRank(next)
                : p.skillTargetLimit(skill, atRank: next))
            .toDouble(),
        suffix: '명',
      ),
    );
  }
  return rows;
}

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

List<SkillPreviewValue> previewSkill(Progress p, SkillDef skill) {
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

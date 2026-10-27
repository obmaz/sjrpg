import 'dart:math' as math;

import 'combat_balance.dart';
import 'skill_growth.dart';
import 'stage_content.dart';

enum HeroClass { warrior, mage }

extension HeroClassInfo on HeroClass {
  String get title => this == HeroClass.warrior ? '전사' : '마법사';
  String get resource => this == HeroClass.warrior ? '분노' : '마나';
  String get subtitle => this == HeroClass.warrior ? '강철과 함성' : '화염 · 냉기 · 번개';
}

enum GearSlot { weapon, armor, charm }

enum Rarity { common, magic, rare, unique }

extension RarityInfo on Rarity {
  String get title => ['일반', '마법', '희귀', '고유'][index];
  int get color => [0xffe3dfce, 0xff82c9ff, 0xffffd877, 0xffefa971][index];
}

class GearDef {
  const GearDef(
    this.id,
    this.name,
    this.slot, {
    this.heroClass,
    this.attack = 0,
    this.armor = 0,
    this.health = 0,
    this.mana = 0,
    this.haste = 0,
    this.range = 115,
    this.tempo = .34,
    this.style = 'sword',
    this.value = 25,
  });
  final String id, name, style;
  final GearSlot slot;
  final HeroClass? heroClass;
  final double attack, armor, health, mana, haste, range, tempo;
  final int value;
  bool usable(HeroClass c) => heroClass == null || heroClass == c;
}

const gearCatalog = <GearDef>[
  GearDef(
    'shortsword',
    '수호자의 검',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 15,
  ),
  GearDef(
    'longsword',
    '기병의 장검',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 19,
    range: 135,
    tempo: .39,
    value: 50,
  ),
  GearDef(
    'axe',
    '전투 도끼',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 24,
    range: 108,
    tempo: .46,
    style: 'axe',
    value: 55,
  ),
  GearDef(
    'mace',
    '철퇴',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 22,
    range: 105,
    tempo: .42,
    style: 'hammer',
    value: 50,
  ),
  GearDef(
    'greatsword',
    '양손 대검',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 28,
    range: 150,
    tempo: .52,
    value: 80,
  ),
  GearDef(
    'twinaxes',
    '쌍날 도끼',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 17,
    range: 110,
    tempo: .25,
    style: 'axe',
    value: 75,
  ),
  GearDef(
    'spear',
    '강철 창',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 20,
    range: 175,
    tempo: .41,
    style: 'spear',
    value: 65,
  ),
  GearDef(
    'runeblade',
    '새벽의 룬검',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 25,
    range: 140,
    tempo: .32,
    value: 110,
  ),
  GearDef(
    'wand',
    '불씨 완드',
    GearSlot.weapon,
    heroClass: HeroClass.mage,
    range: 540,
    attack: 14,
    tempo: .42,
    style: 'fire',
    value: 25,
  ),
  GearDef(
    'oakstaff',
    '참나무 지팡이',
    GearSlot.weapon,
    heroClass: HeroClass.mage,
    range: 540,
    attack: 18,
    health: 10,
    tempo: .45,
    style: 'fire',
    value: 50,
  ),
  GearDef(
    'frostwand',
    '서리 완드',
    GearSlot.weapon,
    heroClass: HeroClass.mage,
    range: 540,
    attack: 16,
    mana: 15,
    tempo: .37,
    style: 'ice',
    value: 65,
  ),
  GearDef(
    'stormrod',
    '폭풍 마법봉',
    GearSlot.weapon,
    heroClass: HeroClass.mage,
    range: 540,
    attack: 20,
    tempo: .39,
    style: 'lightning',
    value: 70,
  ),
  GearDef(
    'emberstaff',
    '잿불 지팡이',
    GearSlot.weapon,
    heroClass: HeroClass.mage,
    range: 540,
    attack: 26,
    tempo: .52,
    style: 'fire',
    value: 80,
  ),
  GearDef(
    'crystalorb',
    '수정 홀',
    GearSlot.weapon,
    heroClass: HeroClass.mage,
    range: 540,
    attack: 21,
    mana: 25,
    tempo: .4,
    style: 'ice',
    value: 95,
  ),
  GearDef('linen', '여행자의 옷', GearSlot.armor, armor: 2, value: 20),
  GearDef(
    'leather',
    '강화 가죽갑옷',
    GearSlot.armor,
    armor: 6,
    health: 10,
    value: 45,
  ),
  GearDef(
    'chainmail',
    '사슬 갑옷',
    GearSlot.armor,
    heroClass: HeroClass.warrior,
    armor: 12,
    value: 70,
  ),
  GearDef(
    'plate',
    '수호 판금갑옷',
    GearSlot.armor,
    heroClass: HeroClass.warrior,
    armor: 17,
    health: 20,
    value: 100,
  ),
  GearDef(
    'silkrobe',
    '비전의 로브',
    GearSlot.armor,
    heroClass: HeroClass.mage,
    armor: 5,
    mana: 20,
    value: 65,
  ),
  GearDef(
    'frostrobe',
    '서리술사의 로브',
    GearSlot.armor,
    heroClass: HeroClass.mage,
    armor: 8,
    mana: 30,
    value: 95,
  ),
  GearDef('amber', '호박 부적', GearSlot.charm, health: 20, value: 40),
  GearDef('sapphire', '청금석 부적', GearSlot.charm, mana: 18, value: 45),
  GearDef('fang', '늑대 송곳니', GearSlot.charm, attack: 3, haste: .04, value: 60),
  GearDef(
    'sentinel',
    '파수꾼의 심장',
    GearSlot.charm,
    attack: 5,
    armor: 5,
    health: 25,
    mana: 10,
    value: 150,
  ),
];
GearDef gearById(String id) => gearCatalog.firstWhere((g) => g.id == id);

enum WeaponGift { frost, guardian, renewal }

extension WeaponGiftInfo on WeaponGift {
  String get title => ['서리의 낙인', '수호의 맹세', '생명의 수확'][index];
  String get description =>
      ['적중한 대상 둔화 0.8초', '받는 피해 8% 감소', '처치 시 생명 4 회복'][index];
}

// Options are fixed when acquired; levelling never rewrites owned equipment.
int gearAffixForLevel(int value, int acquiredLevel) =>
    value <= 0 ? value : value + (math.min(acquiredLevel, 81) - 1) ~/ 10;

class Gear {
  Gear(
    this.serial,
    this.base, {
    this.rarity = Rarity.common,
    this.power = 0,
    this.vitality = 0,
    this.focus = 0,
    this.locked = false,
    this.acquiredLevel = 1,
    this.affixVersion = 1,
    WeaponGift? gift,
    List<WeaponGift>? gifts,
    int? weaponLevel,
  }) : weaponLevel = base.slot == GearSlot.weapon ? (weaponLevel ?? 1) : null,
       gifts = List<WeaponGift>.unmodifiable(
         gifts ??
             (gift != null
                 ? [gift]
                 : _defaultGifts(serial, base, rarity, affixVersion)),
       ) {
    final expected = _giftCount(base, rarity, affixVersion);
    if (base.slot != GearSlot.weapon && weaponLevel != null ||
        this.weaponLevel != null && this.weaponLevel! < 1 ||
        acquiredLevel < 1 ||
        acquiredLevel > 10000 ||
        affixVersion < 0 ||
        affixVersion > 1 ||
        this.gifts.length != expected ||
        this.gifts.toSet().length != this.gifts.length ||
        gift != null && this.gifts.firstOrNull != gift) {
      throw ArgumentError('Invalid equipment abilities');
    }
  }
  final int serial;
  final GearDef base;
  final Rarity rarity;
  final int power, vitality, focus, acquiredLevel, affixVersion;
  final int? weaponLevel;
  static const weaponAttackPerLevel = 2.0;
  bool locked;
  final List<WeaponGift> gifts;
  // Keep the old single-gift accessor for existing callers and save compatibility.
  WeaponGift? get gift => gifts.isEmpty ? null : gifts.first;
  bool hasGift(WeaponGift ability) => gifts.contains(ability);
  static int _giftCount(GearDef base, Rarity rarity, int version) =>
      version == 0
      ? rarity == Rarity.rare && base.slot == GearSlot.weapon
            ? 1
            : 0
      : rarity == Rarity.unique
      ? 2
      : rarity == Rarity.rare
      ? 1
      : 0;
  static List<WeaponGift> _defaultGifts(
    int serial,
    GearDef base,
    Rarity rarity,
    int version,
  ) => [
    for (var i = 0; i < _giftCount(base, rarity, version); i++)
      WeaponGift.values[(serial + i) % WeaponGift.values.length],
  ];
  Map<String, dynamic> toSave() => {
    'serial': serial,
    'base': base.id,
    'rarity': rarity.name,
    'power': power,
    'vitality': vitality,
    'focus': focus,
    'locked': locked,
    'gift': rarity == Rarity.rare && base.slot == GearSlot.weapon
        ? gift?.name
        : null,
    'gifts': gifts.map((ability) => ability.name).toList(),
    'acquiredLevel': acquiredLevel,
    'affixVersion': affixVersion,
    'weaponLevel': weaponLevel,
  };
  factory Gear.fromSave(Map<String, dynamic> data) {
    int stat(String key) {
      final value = data[key];
      if (value is! int || value < 0 || value > 1000000) {
        throw const FormatException('Invalid equipment value');
      }
      return value;
    }

    final serial = stat('serial');
    if (serial == 0) throw const FormatException('Invalid equipment identity');
    final base = gearCatalog.where((g) => g.id == data['base']).firstOrNull;
    final rarity = Rarity.values
        .where((r) => r.name == data['rarity'])
        .firstOrNull;
    if (base == null || rarity == null) {
      throw const FormatException('Invalid equipment kind');
    }
    final locked = data['locked'] ?? false;
    if (locked is! bool) throw const FormatException('Invalid equipment lock');
    final version = data['affixVersion'] ?? 0,
        acquiredLevel = data['acquiredLevel'] ?? 1;
    if (version is! int ||
        version < 0 ||
        version > 1 ||
        acquiredLevel is! int ||
        acquiredLevel < 1 ||
        acquiredLevel > 10000) {
      throw const FormatException('Invalid equipment acquisition');
    }
    WeaponGift readGift(dynamic name) {
      final ability = WeaponGift.values
          .where((g) => g.name == name)
          .firstOrNull;
      if (name is! String || ability == null) {
        throw const FormatException('Invalid equipment ability');
      }
      return ability;
    }

    final legacyName = data['gift'];
    final legacyGift = legacyName == null ? null : readGift(legacyName);
    if (legacyGift != null &&
        (rarity != Rarity.rare || base.slot != GearSlot.weapon)) {
      throw const FormatException('Invalid legacy weapon gift');
    }
    final savedLevel = data['weaponLevel'];
    if (savedLevel != null &&
        (base.slot != GearSlot.weapon ||
            savedLevel is! int ||
            savedLevel < 1)) {
      throw const FormatException('Invalid weapon level');
    }
    final count = _giftCount(base, rarity, version);
    final raw = data['gifts'];
    late final List<WeaponGift> abilities;
    if (raw == null && version == 0) {
      abilities = legacyGift != null
          ? [legacyGift]
          : _defaultGifts(serial, base, rarity, 0);
    } else {
      if (raw is! List || raw.length != count) {
        throw const FormatException('Invalid equipment ability count');
      }
      abilities = raw.map(readGift).toList();
      if (abilities.toSet().length != count ||
          legacyGift != null &&
              (abilities.isEmpty || abilities.first != legacyGift)) {
        throw const FormatException('Conflicting equipment abilities');
      }
    }
    return Gear(
      serial,
      base,
      rarity: rarity,
      power: stat('power'),
      vitality: stat('vitality'),
      focus: stat('focus'),
      locked: locked,
      acquiredLevel: acquiredLevel,
      affixVersion: version,
      gifts: abilities,
      // Existing equipment starts at level one without changing its old attack.
      weaponLevel: savedLevel as int?,
    );
  }
  Gear withWeaponLevel(int level) => Gear(
    serial,
    base,
    rarity: rarity,
    power: power,
    vitality: vitality,
    focus: focus,
    locked: locked,
    acquiredLevel: acquiredLevel,
    affixVersion: affixVersion,
    gifts: gifts,
    weaponLevel: level,
  );
  String get name => rarity == Rarity.unique
      ? '${base.id == 'sentinel' ? '파수꾼' : '균열'}의 유산 · ${base.name}'
      : rarity == Rarity.common
      ? base.name
      : '${power > 0
            ? '맹공'
            : vitality > 0
            ? '생명'
            : '집중'}의 ${base.name}';
  double get attack =>
      base.attack + power + ((weaponLevel ?? 1) - 1) * weaponAttackPerLevel;
  double get armor =>
      base.armor + (base.slot == GearSlot.armor ? rarity.index * 2 : 0);
  double get health => base.health + vitality;
  double get mana => base.mana + focus;
  int get saleValue =>
      math.max(5, (base.value * (1 + rarity.index * .6) / 3).round());
  String get stats => [
    if (weaponLevel != null) '무기 Lv.$weaponLevel',
    if (attack > 0) '공격 +${attack.round()}',
    if (armor > 0) '방어 +${armor.round()}',
    if (health > 0) '생명 +${health.round()}',
    if (mana > 0) '자원 +${mana.round()}',
    if (base.haste > 0) '공격속도 +${(base.haste * 100).round()}%',
    for (final ability in gifts) '${ability.title} · ${ability.description}',
  ].join(' · ');
}

/// One immutable quotation owns the item identity and player-level context.
class SmithQuote {
  SmithQuote._(this._item, this.heroLevel)
    : serial = _item.serial,
      weaponLevel = _item.weaponLevel!,
      price = (25 + _item.weaponLevel! * 12.0 + _item.rarity.index * 15).ceil(),
      successChance = chance(_item.weaponLevel!, heroLevel),
      currentAttack = _item.attack,
      nextAttack = _item.attack + Gear.weaponAttackPerLevel;
  final Gear _item;
  final int serial, weaponLevel, heroLevel, price;
  final double successChance, currentAttack, nextAttack;

  static double chance(int weaponLevel, int heroLevel) =>
      switch (weaponLevel - heroLevel) {
        < 0 => .9,
        0 => .7,
        1 => .6,
        2 => .5,
        3 => .4,
        _ => .3,
      };
}

class SmithResult {
  const SmithResult({required this.succeeded, this.weapon});
  final bool succeeded;
  final Gear? weapon;
  bool get destroyed => !succeeded;
}

const _unarmedDef = GearDef(
  'unarmed',
  '맨손 전투',
  GearSlot.weapon,
  heroClass: HeroClass.warrior,
  attack: 4,
  range: 68,
  tempo: .4,
  value: 0,
);
const _innateMagicDef = GearDef(
  'innate-magic',
  '기초 마법',
  GearSlot.weapon,
  heroClass: HeroClass.mage,
  attack: 3,
  range: 420,
  tempo: .5,
  style: 'fire',
  value: 0,
);

class BasicAttackStats {
  const BasicAttackStats(this.damage, this.interval);
  final double damage, interval;
  double get dps => damage / interval;
}

class SkillDef {
  const SkillDef(
    this.id,
    this.name,
    this.branch,
    this.description,
    this.requiredLevel,
    this.cost,
    this.cooldown, {
    this.passive = false,
    this.basic = false,
    this.basicDamageScale = 1,
    this.basicTempoScale = 1,
    this.requires = const {},
  });
  final String id, name, branch, description;
  final int requiredLevel;
  final double cost, cooldown;
  final bool passive, basic;
  final double basicDamageScale, basicTempoScale;
  final Map<String, int> requires;
  static const maxRank = 5;
  String get shortName =>
      {
        'rendingEdge': '칼날 강화',
        'stormOfSteel': '강철 폭풍',
        'weaponTempo': '무기 리듬',
        'veteranGuard': '수호 숙련',
        'secondWind': '두번째 숨',
        'resoundingCry': '공명 함성',
        'warDrums': '전쟁 북',
        'unyieldingOath': '불굴 맹세',
        'emberFocus': '잿불 집중',
        'cinderReach': '화염 확산',
        'phoenixHeart': '불사조',
        'deepFreeze': '심연 냉기',
        'frozenAegis': '빙하 방벽',
        'glacialReserve': '빙하 샘',
        'conductivity': '마력 전도',
        'forkedStorm': '갈래 번개',
        'arcaneEconomy': '비전 순환',
        'warcry': '함성',
        'whirlwind': '소용돌이',
        'frenzy': '격노',
        'seismicSlam': '강타',
        'charge': '돌진',
        'crushingBlow': '집중 강타',
        'iceArmor': '얼음 갑옷',
        'chainLightning': '번개',
        'meteor': '유성',
      }[id] ??
      name;
}

const warriorSkills = [
  SkillDef(
    'cleave',
    '연속 베기',
    '전투 기술',
    '기본 공격은 1명을 벱니다. 등급마다 공격 속도가 빨라지고 최대 대상 +1명으로 5명까지 증가합니다. 피해는 조금씩 증가합니다. 세 번째 공격은 강타합니다.',
    1,
    0,
    0,
    passive: true,
    basic: true,
  ),
  SkillDef(
    'warcry',
    '전장의 함성',
    '함성',
    '주변 적을 함성으로 기절시키고 잠시 피해를 줄입니다. 등급마다 대상 수·보호율·파동 속도가 늘고 재사용이 빨라집니다. 보호는 재사용 시간의 90% 안에서 끝납니다.',
    1,
    18,
    7,
  ),
  SkillDef(
    'mastery',
    '무기 숙련',
    '전투 숙련',
    '등급마다 모든 무기 피해 +6%.',
    2,
    0,
    0,
    passive: true,
  ),
  SkillDef(
    'ironSkin',
    '강철 피부',
    '전투 숙련',
    '등급마다 방어 +5, 최대 생명 +8.',
    2,
    0,
    0,
    passive: true,
    requires: {'mastery': 1},
  ),
  SkillDef(
    'whirlwind',
    '소용돌이',
    '전투 기술',
    '무기를 들고 직접 회전하며 세 차례 벱니다. 등급마다 회전·베기 속도와 대상 수가 늘고 재사용이 빨라지며 검 궤적과 파편이 화려해집니다.',
    3,
    30,
    5,
    requires: {'cleave': 1},
  ),
  SkillDef(
    'frenzy',
    '광전사의 격노',
    '전투 기술',
    '공격·이동 속도가 증가하고 발동 시 주변 적을 벱니다. 등급마다 공격 속도가 늘고 재사용이 빨라집니다. 강화는 재사용 시간의 90% 안에서 끝납니다.',
    4,
    28,
    12,
    requires: {'cleave': 2},
  ),
  SkillDef(
    'seismicSlam',
    '대지 강타',
    '전투 기술',
    '전방의 지면을 내리쳐 적을 잠시 기절시킵니다. 등급마다 동작과 재사용이 빨라지고 대상 수와 파편이 늘어납니다. 장애물 너머는 타격하지 않습니다.',
    5,
    24,
    8,
    requires: {'whirlwind': 1, 'frenzy': 1},
  ),
  SkillDef(
    'battleFocus',
    '전투 집중',
    '전투 숙련',
    '등급마다 기본 공격 간격이 2.5% 줄어듭니다.',
    5,
    0,
    0,
    passive: true,
    requires: {'ironSkin': 1, 'whirlwind': 1},
  ),
  SkillDef(
    'battleVigor',
    '전장의 맹세',
    '함성',
    '등급마다 최대 생명 +8, 전장의 함성 보호 중 피해 감소 +1%p.',
    3,
    0,
    0,
    passive: true,
    requires: {'warcry': 1},
  ),
  SkillDef(
    'rallyingVoice',
    '고양의 울림',
    '함성',
    '전장의 함성으로 보호받는 동안, 실제 기본 공격 적중 시 등급마다 분노 0.7을 추가로 얻습니다. 빗맞힌 공격에는 적용되지 않습니다.',
    6,
    0,
    0,
    passive: true,
    requires: {'battleVigor': 1, 'resoundingCry': 1, 'weaponTempo': 1},
  ),
  SkillDef(
    'rendingEdge',
    '예리한 칼날',
    '전투 기술',
    '등급마다 기본 공격 피해 +5%.',
    9,
    0,
    0,
    passive: true,
    requires: {'seismicSlam': 1, 'battleFocus': 1},
  ),
  SkillDef(
    'stormOfSteel',
    '강철 폭풍',
    '전투 기술',
    '등급마다 소용돌이·대지 강타 피해 +2%. 2등급마다 최대 대상 +1명, 최대 2명 추가.',
    16,
    0,
    0,
    passive: true,
    requires: {'rendingEdge': 2},
  ),
  SkillDef(
    'weaponTempo',
    '무기의 리듬',
    '전투 숙련',
    '등급마다 기본 공격 간격 1.5% 감소.',
    6,
    0,
    0,
    passive: true,
    requires: {'mastery': 2},
  ),
  SkillDef(
    'veteranGuard',
    '노련한 수호',
    '전투 숙련',
    '등급마다 방어 +2.',
    9,
    0,
    0,
    passive: true,
    requires: {'battleFocus': 1, 'weaponTempo': 1},
  ),
  SkillDef(
    'secondWind',
    '두 번째 숨결',
    '전투 숙련',
    '등급마다 최대 생명 +10.',
    12,
    0,
    0,
    passive: true,
    requires: {'veteranGuard': 1},
  ),
  SkillDef(
    'resoundingCry',
    '공명의 함성',
    '함성',
    '등급마다 전장의 함성 피해 +6%.',
    6,
    0,
    0,
    passive: true,
    requires: {'warcry': 2},
  ),
  SkillDef(
    'warDrums',
    '전쟁의 북소리',
    '함성',
    '함성 보호 중 실제 적중 시 등급마다 분노 +0.35.',
    9,
    0,
    0,
    passive: true,
    requires: {'rallyingVoice': 1},
  ),
  SkillDef(
    'unyieldingOath',
    '불굴의 맹세',
    '함성',
    '등급마다 전장의 함성 피해 감소 +2%p.',
    16,
    0,
    0,
    passive: true,
    requires: {'warDrums': 2, 'veteranGuard': 1},
  ),
  SkillDef(
    'charge',
    '맹렬한 돌진',
    '전투 기술',
    '끌어서 방향을 정한 뒤 몸을 던져 적을 밀칩니다. 벽에서 멈춥니다. 등급마다 돌진·재사용이 빨라지고 대상 수와 궤적이 늘어납니다.',
    6,
    16,
    5,
    requires: {'seismicSlam': 1},
  ),
  SkillDef(
    'crushingBlow',
    '집중 강타',
    '전투 기술',
    '길게 눌러 힘을 모은 뒤 놓으면 전방을 내려칩니다. 등급마다 충전·동작·재사용이 빨라지고 대상 수와 충격 파편이 늘어납니다. 완전 충전은 피해 +80%입니다.',
    7,
    22,
    6,
    requires: {'charge': 1},
  ),
  SkillDef(
    'quickCut',
    '속사 베기',
    '전투 기술',
    '빠른 두 자세로 한 명을 연속 공격합니다. 한 타격은 약하지만 동작이 짧습니다. 자원을 쓰지 않으며 등급마다 공격이 빨라집니다.',
    2,
    0,
    0,
    passive: true,
    basic: true,
    basicDamageScale: .76,
    basicTempoScale: 1.18,
    requires: {'cleave': 1},
  ),
  SkillDef(
    'heavyStrike',
    '무거운 일격',
    '전투 숙련',
    '한 명을 느리고 강하게 내려칩니다. 적중하면 짧게 기절시키며 큰 적에게는 짧게 적용됩니다. 자원을 쓰지 않으며 등급마다 공격과 타격감이 성장합니다.',
    3,
    0,
    0,
    passive: true,
    basic: true,
    basicDamageScale: 1.45,
    basicTempoScale: .72,
    requires: {'cleave': 2, 'mastery': 1},
  ),
];
const mageSkills = [
  SkillDef(
    'firebolt',
    '마력탄',
    '화염',
    '장착한 무기의 원소로 공격하는 기본 탄환입니다. 등급마다 공격과 발사가 빨라집니다. 3등급부터 적중 시 폭발하고 대상이 증가합니다.',
    1,
    0,
    0,
    passive: true,
    basic: true,
  ),
  SkillDef(
    'frostNova',
    '서릿발',
    '냉기',
    '주변 적을 냉기로 얼립니다. 등급마다 시전·재사용이 빨라지고 대상 수·얼음 결정이 늘어납니다. 감속은 재사용 시간의 90% 안에서 끝납니다.',
    1,
    18,
    6,
  ),
  SkillDef(
    'arcaneMastery',
    '원소 숙련',
    '번개',
    '등급마다 원소 피해 +7%, 최대 마나 +8.',
    2,
    0,
    0,
    passive: true,
  ),
  SkillDef(
    'iceArmor',
    '얼음 갑옷',
    '냉기',
    '얼음으로 몸을 보호하고 근접 공격자를 둔화합니다. 등급마다 감소율·결정 수가 늘고 시전과 재사용이 빨라집니다. 보호는 재사용 시간의 90% 안에서 끝납니다.',
    2,
    20,
    15,
    requires: {'frostNova': 1},
  ),
  SkillDef(
    'chainLightning',
    '연쇄 번개',
    '번개',
    '가까운 적들을 잇는 번개입니다. 등급마다 시전·재사용이 빨라지고 대상 수와 전류 갈래가 늘어납니다. 장애물 너머로는 전이하지 않습니다.',
    3,
    28,
    5,
    requires: {'arcaneMastery': 1},
  ),
  SkillDef(
    'meteor',
    '유성 낙하',
    '화염',
    '목표에 유성을 소환합니다. 등급마다 시전·낙하·재사용이 빨라지고 대상 수·불꽃·파편이 늘어납니다.',
    4,
    38,
    9,
    requires: {'warmth': 2, 'iceArmor': 1},
  ),
  SkillDef(
    'warmth',
    '온기',
    '화염',
    '등급마다 초당 마나 회복 +1.05.',
    2,
    0,
    0,
    passive: true,
    requires: {'firebolt': 1},
  ),
  SkillDef(
    'coldMastery',
    '냉기 숙련',
    '냉기',
    '등급마다 냉기 무기와 서릿발 피해 +8%.',
    5,
    0,
    0,
    passive: true,
    requires: {'iceArmor': 1},
  ),
  SkillDef(
    'lightningMastery',
    '번개 숙련',
    '번개',
    '등급마다 번개 무기와 연쇄 번개 피해 +8%.',
    6,
    0,
    0,
    passive: true,
    requires: {'chainLightning': 1, 'deepFreeze': 1},
  ),
  SkillDef(
    'emberFocus',
    '잿불 집중',
    '화염',
    '등급마다 화염 무기·유성 피해 +5%.',
    6,
    0,
    0,
    passive: true,
    requires: {'firebolt': 2},
  ),
  SkillDef(
    'cinderReach',
    '화염 확산',
    '화염',
    '등급마다 유성 피해 +2%. 2등급마다 최대 대상 +1명, 최대 2명 추가.',
    10,
    0,
    0,
    passive: true,
    requires: {'meteor': 1, 'emberFocus': 1},
  ),
  SkillDef(
    'phoenixHeart',
    '불사조의 심장',
    '화염',
    '등급마다 최대 생명 +8.',
    13,
    0,
    0,
    passive: true,
    requires: {'cinderReach': 1, 'frozenAegis': 1},
  ),
  SkillDef(
    'deepFreeze',
    '심연의 냉기',
    '냉기',
    '등급마다 냉기 무기·서릿발 피해 +5%.',
    6,
    0,
    0,
    passive: true,
    requires: {'frostNova': 2},
  ),
  SkillDef(
    'frozenAegis',
    '빙하의 방벽',
    '냉기',
    '등급마다 얼음 갑옷 피해 감소 +2%p.',
    10,
    0,
    0,
    passive: true,
    requires: {'coldMastery': 1, 'deepFreeze': 1, 'meteor': 1},
  ),
  SkillDef(
    'glacialReserve',
    '빙하의 샘',
    '냉기',
    '등급마다 최대 마나 +6.',
    13,
    0,
    0,
    passive: true,
    requires: {'frozenAegis': 2},
  ),
  SkillDef(
    'conductivity',
    '마력 전도',
    '번개',
    '등급마다 번개 무기·연쇄 번개 피해 +5%.',
    6,
    0,
    0,
    passive: true,
    requires: {'arcaneMastery': 2},
  ),
  SkillDef(
    'forkedStorm',
    '갈래 번개',
    '번개',
    '등급마다 연쇄 번개 피해 +2%. 2등급마다 최대 대상 +1명, 최대 2명 추가.',
    10,
    0,
    0,
    passive: true,
    requires: {'lightningMastery': 1, 'conductivity': 1},
  ),
  SkillDef(
    'arcaneEconomy',
    '비전 순환',
    '번개',
    '등급마다 최대 마나 +4, 초당 마나 회복 +0.35.',
    16,
    0,
    0,
    passive: true,
    requires: {'forkedStorm': 2},
  ),
  SkillDef(
    'iceShard',
    '서리 창',
    '냉기',
    '무기와 관계없이 냉기 결정창으로 한 명을 공격하고 느려지게 합니다. 한 타격이 강한 대신 발사가 느립니다. 자원을 쓰지 않으며 등급마다 공격과 결정이 성장합니다.',
    2,
    0,
    0,
    passive: true,
    basic: true,
    basicDamageScale: 1.1,
    basicTempoScale: .86,
    requires: {'firebolt': 1, 'frostNova': 1},
  ),
  SkillDef(
    'sparkBolt',
    '전격 탄',
    '번개',
    '무기와 관계없이 빠른 전격을 발사합니다. 한 타격은 약하며 3등급부터 가까운 적 한 명에게 약한 방전이 퍼집니다. 기본 대상은 한 명, 최대 두 명이며 자원을 쓰지 않습니다.',
    3,
    0,
    0,
    passive: true,
    basic: true,
    basicDamageScale: .84,
    basicTempoScale: 1.12,
    requires: {'firebolt': 2, 'arcaneMastery': 1},
  ),
];

const stageMemories = [
  (
    chest: 1,
    title: '끊어진 맹세',
    hint: '서쪽 숲길의 상자',
    story: '파수꾼은 한때 숲의 뿌리를 지키던 수호자였다. 마을의 종이 멎은 밤, 그가 지키던 맹세도 함께 깨졌다.',
  ),
  (
    chest: 2,
    title: '마지막 종소리',
    hint: '마을 북쪽 길의 상자',
    story: '옛 기록에는 숲보다 오래된 모래시계의 유적이 나온다. 파수꾼이 잠든 뒤 유적의 시간도 깨지기 시작했다.',
  ),
  (
    chest: 3,
    title: '물 아래의 문',
    hint: '동쪽 목교 앞 숲길의 상자',
    story:
        '수면 아래 수정에서 낯선 푸른 신호가 흐른다. 아직 세워지지 않은 도시가 도움을 청하고 있다. 유적의 균열은 과거와 미래를 함께 가리킨다.',
  ),
];
const stageKillGoal = 120;
const startingStageName = '십자로의 숲';

class Progress {
  Progress({this.heroClass = HeroClass.warrior}) {
    inventory.addAll([
      Gear(
        _serial++,
        gearById(heroClass == HeroClass.warrior ? 'shortsword' : 'wand'),
      ),
      Gear(_serial++, gearById('linen')),
    ]);
    for (final item in inventory) {
      equipped[item.base.slot] = item;
    }
    ranks[heroClass == HeroClass.warrior ? 'cleave' : 'firebolt'] = 1;
    ranks[heroClass == HeroClass.warrior ? 'warcry' : 'frostNova'] = 1;
    selectedBasic = defaultBasicId;
    selectedSkill = heroClass == HeroClass.warrior ? 'warcry' : 'frostNova';
    hp = maxHp;
    energy = heroClass == HeroClass.warrior ? 25 : maxEnergy;
  }
  final HeroClass heroClass;
  int kills = 0, gold = 0, level = 1, xp = 0, skillPoints = 1;
  int healingPotions = 3, energyPotions = 2;
  int _serial = 1;
  double hp = 100, energy = 0, bonusAttack = 0, bonusHealth = 0;
  bool bossDefeated = false;
  final _claimedResetStages = <WorldStage>{};
  int _spentSkillResets = 0;
  int get skillResetTickets => _claimedResetStages.length - _spentSkillResets;
  Set<WorldStage> get claimedResetStages =>
      Set.unmodifiable(_claimedResetStages);
  bool awardSkillResetTicket(WorldStage stage) =>
      _claimedResetStages.add(stage);
  String selectedBasic = '';
  String get defaultBasicId =>
      heroClass == HeroClass.warrior ? 'cleave' : 'firebolt';
  Iterable<SkillDef> get basicSkills => skills.where((s) => s.basic);
  SkillDef get basicSkill => skills.firstWhere((s) => s.id == selectedBasic);
  bool canSelectBasic(String id) =>
      skills.any((s) => s.id == id && s.basic && rank(id) > 0);
  bool selectBasic(String id) {
    if (!canSelectBasic(id)) return false;
    selectedBasic = id;
    return true;
  }

  String basicElementFor(SkillDef skill) => switch (skill.id) {
    'iceShard' => 'ice',
    'sparkBolt' => 'lightning',
    _ => weapon.base.style,
  };
  String get basicElement => basicElementFor(basicSkill);
  String selectedSkill = '';
  String? secondarySkill, tertiarySkill, quaternarySkill;
  List<String?> get skillSlots => [
    selectedSkill,
    secondarySkill,
    tertiarySkill,
    quaternarySkill,
  ];
  SkillDef? skillAt(int slot) {
    if (slot < 0 || slot >= 4) return null;
    final id = skillSlots[slot];
    return id == null ? null : skills.firstWhere((skill) => skill.id == id);
  }

  int get maxTrainingRank => 1 + (level - 1) ~/ 3;
  static const attackTrainingPower = 5.0;
  int get attackTrainingRank => (bonusAttack / attackTrainingPower).floor();
  double get attackTrainingGain => attackTrainingPower * attackMultiplier;
  int get vitalityTrainingRank => (bonusHealth / 20).floor();
  bool get canTrainAttack => attackTrainingRank < maxTrainingRank;
  bool get canTrainVitality => vitalityTrainingRank < maxTrainingRank;
  int get attackTrainingCost => 45 + attackTrainingRank * 35;
  int get vitalityTrainingCost => 60 + vitalityTrainingRank * 40;

  List<GearDef> get shopGear {
    final ids = heroClass == HeroClass.warrior
        ? [
            'longsword',
            'axe',
            'spear',
            'mace',
            if (level >= 5) ...['greatsword', 'twinaxes', 'runeblade'],
            'leather',
            'chainmail',
            if (level >= 5) 'plate',
            'amber',
            if (level >= 5) 'fang',
          ]
        : [
            'oakstaff',
            'frostwand',
            'stormrod',
            if (level >= 5) ...['emberstaff', 'crystalorb'],
            'silkrobe',
            'leather',
            if (level >= 5) 'frostrobe',
            'sapphire',
            if (level >= 5) ...['amber', 'fang'],
          ];
    return ids.map(gearById).toList();
  }

  final Map<String, int> ranks = {};
  final List<Gear> inventory = [];
  final Set<int> unseenGear = {};
  final Map<GearSlot, Gear> equipped = {};
  Map<String, dynamic> toSave() => {
    'heroClass': heroClass.name,
    'kills': kills,
    'gold': gold,
    'level': level,
    'xp': xp,
    'skillPoints': skillPoints,
    'healingPotions': healingPotions,
    'energyPotions': energyPotions,
    'serial': _serial,
    'hp': hp,
    'energy': energy,
    'bonusAttack': bonusAttack,
    'bonusHealth': bonusHealth,
    'bossDefeated': bossDefeated,
    'skillResetRewards': {
      'version': 1,
      'claimed': [
        for (final stage in WorldStage.values)
          if (_claimedResetStages.contains(stage)) stage.name,
      ],
      'spent': _spentSkillResets,
    },
    'selectedBasic': selectedBasic,
    'selectedSkill': selectedSkill,
    'secondarySkill': secondarySkill,
    'tertiarySkill': tertiarySkill,
    'quaternarySkill': quaternarySkill,
    'ranks': Map<String, int>.of(ranks),
    'inventory': inventory.map((g) => g.toSave()).toList(),
    'unseenGear': unseenGear.toList(),
    'equipped': equipped.map((slot, gear) => MapEntry(slot.name, gear.serial)),
    'weaponFallback': usingFallbackWeapon,
  };
  static Progress? fromSave(dynamic value) {
    try {
      final data = Map<String, dynamic>.from(value as Map);
      int integer(String key, {int max = 1000000000}) {
        final v = data[key];
        if (v is! int || v < 0 || v > max) {
          throw const FormatException('Invalid progress');
        }
        return v;
      }

      double decimal(String key) {
        final v = data[key];
        if (v is! num || !v.isFinite || v < 0 || v > 1000000000) {
          throw const FormatException('Invalid progress');
        }
        return v.toDouble();
      }

      final p = Progress(
        heroClass: HeroClass.values.firstWhere(
          (c) => c.name == data['heroClass'],
        ),
      );
      p.level = integer('level', max: 10000);
      if (p.level == 0) return null;
      p.kills = integer('kills');
      p.gold = integer('gold');
      p.xp = integer('xp');
      if (p.xp >= p.nextLevelXp) return null;
      p.skillPoints = integer('skillPoints');
      p.healingPotions = integer('healingPotions');
      p.energyPotions = integer('energyPotions');
      p.bonusAttack = decimal('bonusAttack');
      p.bonusHealth = decimal('bonusHealth');
      p.bossDefeated = data['bossDefeated'] as bool;
      if (data.containsKey('skillResetRewards')) {
        final rewards = data['skillResetRewards'];
        if (rewards is! Map || rewards['version'] != 1) return null;
        final claimed = rewards['claimed'], spent = rewards['spent'];
        if (claimed is! List ||
            claimed.length > WorldStage.values.length ||
            spent is! int ||
            spent < 0 ||
            spent > claimed.length) {
          return null;
        }
        for (final name in claimed) {
          final stage = WorldStage.values
              .where((s) => s.name == name)
              .firstOrNull;
          if (stage == null || !p._claimedResetStages.add(stage)) return null;
        }
        p._spentSkillResets = spent;
      }
      final items = data['inventory'] as List;
      final fallback = data['weaponFallback'] ?? false;
      if (fallback is! bool ||
          items.isEmpty && !fallback ||
          items.length > capacity) {
        return null;
      }
      p.inventory.clear();
      final identities = <int>{};
      for (final item in items) {
        final gear = Gear.fromSave(Map<String, dynamic>.from(item as Map));
        if (!identities.add(gear.serial)) return null;
        p.inventory.add(gear);
      }
      p.equipped.clear();
      final unseen = data['unseenGear'] ?? const <dynamic>[];
      if (unseen is! List ||
          unseen.length > capacity ||
          unseen.toSet().length != unseen.length ||
          unseen.any((id) => id is! int || !identities.contains(id))) {
        return null;
      }
      p.unseenGear.addAll(unseen.cast<int>());
      for (final entry in (data['equipped'] as Map).entries) {
        final slot = GearSlot.values.firstWhere((s) => s.name == entry.key);
        final item = p.inventory.firstWhere((g) => g.serial == entry.value);
        if (item.base.slot != slot ||
            (slot == GearSlot.weapon && item.base.heroClass != p.heroClass)) {
          return null;
        }
        p.equipped[slot] = item;
      }
      if (fallback == p.equipped.containsKey(GearSlot.weapon) ||
          fallback &&
              p.inventory.any(
                (g) =>
                    g.base.slot == GearSlot.weapon &&
                    g.base.usable(p.heroClass),
              )) {
        return null;
      }
      p.ranks.clear();
      for (final entry in (data['ranks'] as Map).entries) {
        final skill = p.skills.firstWhere((s) => s.id == entry.key);
        final rank = entry.value;
        if (rank is! int ||
            rank < 1 ||
            rank > 5 ||
            skill.requiredLevel > p.level) {
          return null;
        }
        p.ranks[skill.id] = rank;
      }
      if (p.rank(p.heroClass == HeroClass.warrior ? 'cleave' : 'firebolt') ==
          0) {
        return null;
      }
      final basic = data['selectedBasic'] ?? p.defaultBasicId;
      if (basic is! String || !p.canSelectBasic(basic)) return null;
      p.selectedBasic = basic;
      p.selectedSkill = data['selectedSkill'] as String;
      final active = p.skills.firstWhere((s) => s.id == p.selectedSkill);
      if (active.passive || p.rank(active.id) == 0) return null;
      p.secondarySkill = data['secondarySkill'] as String?;
      if (p.secondarySkill != null) {
        final secondary = p.skills.firstWhere((s) => s.id == p.secondarySkill);
        if (secondary.passive ||
            p.rank(secondary.id) == 0 ||
            secondary.id == active.id) {
          return null;
        }
      }
      p.tertiarySkill = data['tertiarySkill'] as String?;
      p.quaternarySkill = data['quaternarySkill'] as String?;
      if (!data.containsKey('tertiarySkill')) {
        final extras = p.skills
            .where(
              (s) =>
                  !s.passive &&
                  p.rank(s.id) > 0 &&
                  s.id != p.selectedSkill &&
                  s.id != p.secondarySkill,
            )
            .toList();
        if (extras.isNotEmpty) p.tertiarySkill = extras.first.id;
        if (extras.length > 1) p.quaternarySkill = extras[1].id;
      }
      final assigned = <String>{};
      for (var slot = 0; slot < 4; slot++) {
        final skill = p.skillAt(slot);
        if (skill == null) continue;
        if (skill.passive || p.rank(skill.id) == 0 || !assigned.add(skill.id)) {
          return null;
        }
      }
      p._serial = math.max(integer('serial'), identities.fold(0, math.max) + 1);
      p.hp = decimal('hp').clamp(0, p.maxHp);
      p.energy = decimal('energy').clamp(0, p.maxEnergy);
      return p;
    } catch (_) {
      return null;
    }
  }

  static const capacity = 24;
  List<SkillDef> get skills =>
      heroClass == HeroClass.warrior ? warriorSkills : mageSkills;
  SkillDef? get secondarySkillDef => secondarySkill == null
      ? null
      : skills.firstWhere((s) => s.id == secondarySkill);
  SkillDef get activeSkill => skills.firstWhere((s) => s.id == selectedSkill);
  int rank(String id) => ranks[id] ?? 0;
  int get nextLevelXp => CombatBalance.experienceForLevel(level);
  late final _fallbackWeapon = Gear(
    0,
    heroClass == HeroClass.warrior ? _unarmedDef : _innateMagicDef,
    locked: true,
  );
  bool get usingFallbackWeapon => !equipped.containsKey(GearSlot.weapon);
  Gear get weapon => equipped[GearSlot.weapon] ?? _fallbackWeapon;
  double get maxHp =>
      (heroClass == HeroClass.warrior ? 100 : 80) +
      (level - 1) * 10 +
      bonusHealth +
      equipped.values.fold(0.0, (v, g) => v + g.health) +
      rank('ironSkin') * 8 +
      rank('battleVigor') * 8 +
      rank('secondWind') * 10 +
      rank('phoenixHeart') * 8;
  set maxHp(double value) => bonusHealth += value - maxHp;
  double get maxEnergy =>
      (heroClass == HeroClass.warrior ? 100 : 90) +
      equipped.values.fold(0.0, (v, g) => v + g.mana) +
      rank('arcaneMastery') * 8 +
      rank('glacialReserve') * 6 +
      rank('arcaneEconomy') * 4;
  double get armor =>
      equipped.values.fold(0.0, (v, g) => v + g.armor) +
      rank('ironSkin') * 5 +
      rank('veteranGuard') * 2;
  static const playerDamageScale = .75 * CombatBalance.heroDamageScale;
  static const skillCooldownScale = .7;
  double get attackMultiplier =>
      (1 +
          rank('mastery') * CombatBalance.physicalMasteryGrowth +
          rank('arcaneMastery') * CombatBalance.arcaneMasteryGrowth) *
      playerDamageScale;
  double get swordDamage =>
      (bonusAttack +
          (level - 1) * 2 +
          equipped.values.fold(0.0, (v, g) => v + g.attack) +
          (usingFallbackWeapon ? weapon.attack : 0)) *
      attackMultiplier;
  set swordDamage(double value) =>
      bonusAttack += (value - swordDamage) / attackMultiplier;
  List<String> get skillBranches => heroClass == HeroClass.warrior
      ? const ['전투 기술', '전투 숙련', '함성']
      : const ['화염', '냉기', '번개'];
  double get manaRecovery =>
      (9 + rank('warmth') * 1.5 + rank('arcaneEconomy') * .5) *
      CombatBalance.resourceGainScale;
  double get fireDamageMultiplier => 1 + rank('emberFocus') * .05;
  double get coldDamageMultiplier =>
      1 + rank('coldMastery') * .08 + rank('deepFreeze') * .05;
  double get lightningDamageMultiplier =>
      1 + rank('lightningMastery') * .08 + rank('conductivity') * .05;
  int get basicTargetLimit => basicTargetLimitForRank(rank(selectedBasic));
  int basicTargetLimitForRank(int rank, {SkillDef? basic}) {
    final skill = basic ?? basicSkill;
    if (rank <= 0) return 0;
    return switch (skill.id) {
      'cleave' => rank.clamp(1, SkillDef.maxRank),
      'firebolt' => rank >= 3 ? rank.clamp(3, 5) : 1,
      'sparkBolt' => rank >= 3 ? 2 : 1,
      _ => 1,
    };
  }

  int skillTargetLimit(SkillDef skill, {int? atRank}) {
    final r = (atRank ?? rank(skill.id)).clamp(0, SkillDef.maxRank);
    if (r == 0 || !skills.contains(skill)) return 0;
    if (skill.basic) return basicTargetLimitForRank(r, basic: skill);
    return switch (skill.id) {
      'whirlwind' => 3 + r - 1 + rank('stormOfSteel') ~/ 2,
      'chainLightning' => 3 + r - 1 + rank('forkedStorm') ~/ 2,
      'warcry' || 'frostNova' => 3 + r - 1,
      'frenzy' || 'charge' => 3 + (r - 1) ~/ 2,
      'crushingBlow' => 3 + r - 1,
      'seismicSlam' => 3 + (r - 1) * 2 + rank('stormOfSteel') ~/ 2,
      'meteor' => 3 + (r - 1) * 2 + rank('cinderReach') ~/ 2,
      _ => 0,
    };
  }

  double skillCooldown(SkillDef skill, {int? atRank}) {
    final r = atRank ?? rank(skill.id);
    if (skill.passive || r <= 0 || !skills.contains(skill)) return 0;
    final specialty = switch (skill.id) {
      'whirlwind' || 'seismicSlam' => rank('stormOfSteel'),
      'meteor' => rank('cinderReach'),
      'chainLightning' => rank('forkedStorm'),
      _ => 0,
    };
    return skill.cooldown *
        skillCooldownScale *
        SkillGrowth.cooldown(r) *
        (1 - specialty * .02);
  }

  double skillTempo(SkillDef skill, {int? atRank}) =>
      SkillGrowth.tempo(atRank ?? rank(skill.id));
  double skillMotionTime(SkillDef skill, {int? atRank}) {
    final base = heroClass == HeroClass.mage
        ? .48
        : switch (skill.id) {
            'charge' => .36,
            'crushingBlow' => .42,
            'whirlwind' => .5,
            'seismicSlam' => .23,
            _ => .2,
          };
    return base / skillTempo(skill, atRank: atRank);
  }

  double basicTempoFor(SkillDef skill, {int? atRank}) =>
      CombatBalance.basicTempo(atRank ?? rank(skill.id)) *
      skill.basicTempoScale;
  double get basicTempo => basicTempoFor(basicSkill);
  double get heavyChargeTime => 1.2 / SkillGrowth.tempo(rank('crushingBlow'));
  double get frenzyAttackTempo => 1.65 + math.max(0, rank('frenzy') - 1) * .08;
  double get frenzyMoveSpeed => 310 + math.max(0, rank('frenzy') - 1) * 8;
  // Every temporary skill effect leaves at least ten percent of its actual
  // rank/perk-adjusted cooldown without that effect.
  static const skillEffectUptime = .9;
  double limitedSkillDuration(String id, double nominal, {int? atRank}) {
    final skill = skills.where((s) => s.id == id).firstOrNull;
    final r = atRank ?? rank(id);
    if (skill == null || skill.passive || r <= 0) return 0;
    return math.min(
      nominal,
      skillCooldown(skill, atRank: r) * skillEffectUptime,
    );
  }

  double get frenzyDuration =>
      limitedSkillDuration('frenzy', 7 + math.max(0, rank('frenzy') - 1) * .5);
  double get iceArmorDuration => limitedSkillDuration(
    'iceArmor',
    12 + math.max(0, rank('iceArmor') - 1) * 1.25,
  );
  double get novaSlowDuration => limitedSkillDuration(
    'frostNova',
    3 + math.max(0, rank('frostNova') - 1) * .2,
  );
  double get warcryStun =>
      limitedSkillDuration('warcry', 2 + math.max(0, rank('warcry') - 1) * .1);

  double get basicDamage => skillDamage(basicSkill);
  double skillDamage(SkillDef skill, {int? atRank}) {
    final r = (atRank ?? rank(skill.id)).clamp(0, SkillDef.maxRank);
    if (!skills.contains(skill) ||
        (r == 0 && skill.id != 'cleave' && skill.id != 'firebolt')) {
      return 0;
    }
    final factor = switch (skill.id) {
      'cleave' ||
      'firebolt' ||
      'quickCut' ||
      'heavyStrike' ||
      'iceShard' ||
      'sparkBolt' => (1 + math.max(0, r - 1) * .04) * skill.basicDamageScale,
      'warcry' => 1.25 + math.max(0, r - 1) * .04,
      'whirlwind' => 1.34 + math.max(0, r - 1) * .05,
      'frenzy' => 1.4 + math.max(0, r - 1) * .05,
      'charge' => 1.65 + math.max(0, r - 1) * .05,
      'crushingBlow' => 2.6 + math.max(0, r - 1) * .1,
      'seismicSlam' => 2.12 + math.max(0, r - 1) * .1,
      'frostNova' => 1.4 + math.max(0, r - 1) * .05,
      'chainLightning' => 1.85 + math.max(0, r - 1) * .1,
      'meteor' => 3.6 + math.max(0, r - 1) * .15,
      _ => 0.0,
    };
    final element =
        skill.id == 'frostNova' ||
            (skill.basic && basicElementFor(skill) == 'ice')
        ? coldDamageMultiplier
        : skill.id == 'chainLightning' ||
              (skill.basic && basicElementFor(skill) == 'lightning')
        ? lightningDamageMultiplier
        : 1;
    final fire =
        skill.id == 'meteor' ||
        (skill.basic && basicElementFor(skill) == 'fire');
    final specialization = switch (skill.id) {
      'cleave' || 'quickCut' || 'heavyStrike' => 1 + rank('rendingEdge') * .05,
      'warcry' => 1 + rank('resoundingCry') * .06,
      'whirlwind' || 'seismicSlam' => 1 + rank('stormOfSteel') * .02,
      'meteor' => 1 + rank('cinderReach') * .02,
      'chainLightning' => 1 + rank('forkedStorm') * .02,
      _ => 1.0,
    };
    return swordDamage *
        factor *
        element *
        (fire ? fireDamageMultiplier : 1) *
        specialization;
  }

  double skillProtection(String id, {int? atRank}) {
    final r = (atRank ?? rank(id)).clamp(0, SkillDef.maxRank);
    return id == 'warcry'
        ? .25 +
              r * .025 +
              rank('unyieldingOath') * .02 +
              rank('battleVigor') * .01
        : id == 'iceArmor'
        ? .25 + r * .05 + rank('frozenAegis') * .02
        : 0;
  }

  double get warcryDuration =>
      limitedSkillDuration('warcry', 6 + math.max(0, rank('warcry') - 1) * .35);
  double rageOnHit({required bool protected}) =>
      (3.0 + (protected ? rank('rallyingVoice') + rank('warDrums') * .5 : 0)) *
      CombatBalance.resourceGainScale;

  double attackIntervalFor(SkillDef skill, {int? atRank}) => math.max(
    CombatBalance.minimumBasicInterval,
    weapon.base.tempo /
        basicTempoFor(skill, atRank: atRank) *
        (1 - equipped.values.fold(0.0, (v, g) => v + g.base.haste)) *
        (1 - rank('battleFocus') * .025) *
        (1 - rank('weaponTempo') * .015),
  );
  double get attackInterval => attackIntervalFor(basicSkill);
  double get basicDps => basicDamage / attackInterval;
  BasicAttackStats? previewBasicAttack(Gear gear) {
    if (!gear.base.usable(heroClass)) return null;
    if (isEquipped(gear)) return BasicAttackStats(basicDamage, attackInterval);
    final next = Progress(heroClass: heroClass)
      ..level = level
      ..bonusAttack = bonusAttack
      ..bonusHealth = bonusHealth
      ..selectedBasic = selectedBasic;
    next.ranks
      ..clear()
      ..addAll(ranks);
    next.equipped
      ..clear()
      ..addAll(equipped)
      ..[gear.base.slot] = gear;
    return BasicAttackStats(next.basicDamage, next.attackInterval);
  }

  double mitigate(double damage, {double protection = 0}) =>
      damage * 100 / (100 + armor * 3) * (1 - protection.clamp(0, .75));
  void reward({bool boss = false, bool elite = false, bool unique = false}) {
    kills++;
    gold += boss
        ? 100
        : unique
        ? 35
        : elite
        ? 20
        : 8;
    bossDefeated |= boss;
    gainXp(
      boss
          ? 80
          : unique
          ? 26
          : elite
          ? 18
          : 8,
    );
  }

  void gainXp(int amount) {
    xp += amount;
    while (xp >= nextLevelXp) {
      xp -= nextLevelXp;
      level++;
      skillPoints++;
      hp = math.min(maxHp, hp + maxHp * .2);
      energy = math.min(
        maxEnergy,
        energy +
            (heroClass == HeroClass.mage
                ? maxEnergy * CombatBalance.levelManaFraction
                : CombatBalance.levelRageGain),
      );
    }
  }

  bool prerequisitesMet(SkillDef skill) =>
      skill.requires.entries.every((entry) => rank(entry.key) >= entry.value);
  bool canLearn(SkillDef s) =>
      skills.contains(s) &&
      level >= s.requiredLevel &&
      skillPoints > 0 &&
      rank(s.id) < SkillDef.maxRank &&
      (rank(s.id) > 0 || prerequisitesMet(s));
  int get investedSkillPoints {
    final basic = heroClass == HeroClass.warrior ? 'cleave' : 'firebolt';
    final starter = heroClass == HeroClass.warrior ? 'warcry' : 'frostNova';
    return ranks.entries.fold(
      0,
      (sum, entry) =>
          sum +
          math.max(
            0,
            entry.value - (entry.key == basic || entry.key == starter ? 1 : 0),
          ),
    );
  }

  bool get canResetSkills =>
      hp > 0 && investedSkillPoints > 0 && skillResetTickets > 0;

  bool resetSkills() {
    final refund = investedSkillPoints;
    if (!canResetSkills) return false;
    _spentSkillResets++;
    skillPoints += refund;
    final basic = heroClass == HeroClass.warrior ? 'cleave' : 'firebolt';
    final starter = heroClass == HeroClass.warrior ? 'warcry' : 'frostNova';
    selectedBasic = basic;
    ranks
      ..clear()
      ..[basic] = 1
      ..[starter] = 1;
    selectedSkill = starter;
    secondarySkill = tertiarySkill = quaternarySkill = null;
    hp = math.min(hp, maxHp);
    energy = math.min(energy, maxEnergy);
    return true;
  }

  bool learn(SkillDef skill) {
    if (!canLearn(skill)) return false;
    final previousRank = rank(skill.id);
    skillPoints--;
    ranks[skill.id] = previousRank + 1;
    if (skill.basic && previousRank == 0) selectedBasic = skill.id;
    if (!skill.passive && !skillSlots.contains(skill.id)) {
      if (secondarySkill == null) {
        secondarySkill = skill.id;
      } else if (tertiarySkill == null) {
        tertiarySkill = skill.id;
      } else {
        quaternarySkill ??= skill.id;
      }
    }
    hp = math.min(hp, maxHp);
    return true;
  }

  bool canSelectSkill(String id, {int slot = 0}) {
    if (slot < 0 ||
        slot > 3 ||
        !skills.any((s) => s.id == id && !s.passive && rank(id) > 0)) {
      return false;
    }
    final values = skillSlots;
    return values[0] != id || slot == 0 || values[slot] != null;
  }

  bool selectSkill(String id, {int slot = 0}) {
    if (!canSelectSkill(id, slot: slot)) return false;
    final values = skillSlots, previous = skillSlots.indexOf(id);
    if (previous >= 0 && previous != slot) values[previous] = values[slot];
    values[slot] = id;
    selectedSkill = values[0]!;
    secondarySkill = values[1];
    tertiarySkill = values[2];
    quaternarySkill = values[3];
    return true;
  }

  bool hasGift(WeaponGift ability) =>
      equipped.values.any((gear) => gear.hasGift(ability));

  bool equip(Gear item) {
    if (!inventory.contains(item) || !item.base.usable(heroClass)) return false;
    equipped[item.base.slot] = item;
    unseenGear.remove(item.serial);
    hp = math.min(hp, maxHp);
    energy = math.min(energy, maxEnergy);
    return true;
  }

  bool isEquipped(Gear item) => equipped[item.base.slot] == item;
  bool setGearLocked(Gear item, bool locked) {
    if (!inventory.contains(item)) return false;
    item.locked = locked;
    return true;
  }

  bool sell(Gear item) {
    if (item.locked || isEquipped(item) || !inventory.remove(item)) {
      return false;
    }
    unseenGear.remove(item.serial);
    gold += item.saleValue;
    return true;
  }

  Gear createGear(
    GearDef def, {
    Rarity rarity = Rarity.common,
    int power = 0,
    int vitality = 0,
    int focus = 0,
    int? acquiredLevel,
    List<WeaponGift>? gifts,
    int? weaponLevel,
  }) {
    if (!gearCatalog.contains(def)) {
      throw ArgumentError('Only real equipment can enter the inventory');
    }
    final acquisition = acquiredLevel ?? level;
    if (acquisition < 1 || acquisition > 10000) {
      throw RangeError.range(acquisition, 1, 10000, 'acquiredLevel');
    }
    return Gear(
      _serial++,
      def,
      rarity: rarity,
      power: gearAffixForLevel(power, acquisition),
      vitality: gearAffixForLevel(vitality, acquisition),
      focus: gearAffixForLevel(focus, acquisition),
      acquiredLevel: acquisition,
      gifts: gifts,
      weaponLevel: def.slot == GearSlot.weapon
          ? (weaponLevel ?? acquisition)
          : weaponLevel,
    );
  }

  Gear rollLoot(
    math.Random random, {
    bool boss = false,
    bool chest = false,
    bool elite = false,
    bool unique = false,
  }) {
    final pool = gearCatalog
        .where(
          (g) =>
              g.usable(heroClass) &&
              g.id != 'sentinel' &&
              g.id != 'linen' &&
              (!(boss || elite || unique) || g.slot == GearSlot.weapon),
        )
        .toList();
    final def = pool[random.nextInt(pool.length)];
    final rarity = unique
        ? Rarity.unique
        : boss || elite
        ? Rarity.rare
        : random.nextDouble() < (chest ? .45 : .2)
        ? Rarity.magic
        : Rarity.common;
    return createGear(
      def,
      rarity: rarity,
      power: rarity == Rarity.common
          ? 0
          : (def.slot == GearSlot.weapon
                ? 2 + random.nextInt(4) * rarity.index
                : random.nextInt(3)),
      vitality: rarity.index > 0 ? 4 + random.nextInt(6) * rarity.index : 0,
      focus: heroClass == HeroClass.mage && rarity.index > 0
          ? 3 + random.nextInt(5) * rarity.index
          : 0,
      weaponLevel: def.slot == GearSlot.weapon
          ? math.max(1, level + random.nextInt(5) - 2)
          : null,
    );
  }

  bool _canOwn(Gear item) =>
      item.serial > 0 &&
      gearCatalog.contains(item.base) &&
      !inventory.any((owned) => owned.serial == item.serial);

  bool addOwnedGear(Gear item) {
    if (!_canOwn(item) || inventory.length >= capacity) return false;
    inventory.add(item);
    _serial = math.max(_serial, item.serial + 1);
    unseenGear.add(item.serial);
    if (usingFallbackWeapon &&
        item.base.slot == GearSlot.weapon &&
        item.base.usable(heroClass)) {
      equip(item);
    }
    return true;
  }

  // Only common copies already outclassed by owned gear become gold.
  bool collect(Gear item) {
    if (!_canOwn(item)) return false;
    if (item.rarity == Rarity.common &&
        inventory.any(
          (g) =>
              g.base.id == item.base.id &&
              (g.weaponLevel ?? 0) >= (item.weaponLevel ?? 0) &&
              g.attack >= item.attack &&
              g.armor >= item.armor &&
              g.health >= item.health &&
              g.mana >= item.mana,
        )) {
      gold += item.saleValue;
      return false;
    }
    return addOwnedGear(item);
  }

  SmithQuote? smithQuote(Gear item) {
    if (hp <= 0 ||
        !inventory.contains(item) ||
        item.base.slot != GearSlot.weapon ||
        !item.base.usable(heroClass) ||
        item.locked ||
        item.weaponLevel! + 1 <= item.weaponLevel!) {
      return null;
    }
    return SmithQuote._(item, level);
  }

  SmithResult? enhanceWeapon(SmithQuote quote, math.Random random) {
    final current = smithQuote(quote._item);
    if (current == null ||
        current.heroLevel != quote.heroLevel ||
        current.weaponLevel != quote.weaponLevel ||
        current.price != quote.price ||
        current.successChance != quote.successChance ||
        gold < current.price) {
      return null;
    }
    final item = quote._item;
    final succeeded = random.nextDouble() < current.successChance;
    gold -= current.price;
    unseenGear.remove(item.serial);
    Gear? enhanced;
    if (succeeded) {
      enhanced = item.withWeaponLevel(item.weaponLevel! + 1);
      inventory[inventory.indexOf(item)] = enhanced;
      if (isEquipped(item)) equipped[GearSlot.weapon] = enhanced;
    } else {
      inventory.remove(item);
      if (isEquipped(item)) {
        equipped.remove(GearSlot.weapon);
        final alternatives =
            inventory
                .where(
                  (g) =>
                      g.base.slot == GearSlot.weapon &&
                      g.base.usable(heroClass),
                )
                .toList()
              ..sort((a, b) {
                final strength = b.attack.compareTo(a.attack);
                return strength == 0 ? a.serial.compareTo(b.serial) : strength;
              });
        if (alternatives.isNotEmpty) {
          equipped[GearSlot.weapon] = alternatives.first;
          unseenGear.remove(alternatives.first.serial);
        }
      }
    }
    hp = math.min(hp, maxHp);
    energy = math.min(energy, maxEnergy);
    return SmithResult(succeeded: succeeded, weapon: enhanced);
  }

  bool buy(int price, void Function() apply) {
    if (price < 0 || gold < price) return false;
    gold -= price;
    apply();
    return true;
  }
}

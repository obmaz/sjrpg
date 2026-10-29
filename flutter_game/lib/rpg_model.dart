import 'dart:math' as math;

import 'combat_balance.dart';
import 'mount_progress.dart';
import 'skill_growth.dart';
import 'sorceress_rules.dart';
import 'stage_content.dart';
import 'weapon_profiles.dart';

part 'barbarian_catalog.dart';
part 'sorceress_catalog.dart';

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
  WeaponComboProfile? get comboProfile => meleeWeaponProfiles[id];
  ThrownWeaponProfile? get throwingProfile => throwingWeaponProfiles[id];
  bool get isThrowingWeapon =>
      slot == GearSlot.weapon && style == 'throwing' && throwingProfile != null;
  double get contactRange => isThrowingWeapon ? 115 : range;

  /// Half of the forward hit arc; long thrusts trade width for reach.
  double get meleeHalfAngle => switch (id) {
    'rapier' => .32,
    'spear' => .42,
    'halberd' => .72,
    'glaive' => .95,
    'greatsword' || 'dualblades' || 'mace' || 'warhammer' => 1.05,
    'runeblade' => 1.10,
    'katana' => 1.15,
    'longsword' => 1.20,
    'flail' => 1.35,
    'falchion' => 1.40,
    _ =>
      style == 'spear'
          ? .5
          : style == 'axe'
          ? 1.5
          : 1.25,
  };
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
    range: 440,
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
    range: 560,
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
    range: 480,
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
    range: 500,
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
    range: 600,
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
    range: 520,
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
  // Append new definitions: the first 24 IDs retain their equipment-sheet cells.
  GearDef(
    'dualblades',
    '그림자 쌍검',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 16,
    range: 110,
    tempo: .28,
    value: 85,
  ),
  GearDef(
    'rapier',
    '결투사의 세검',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 18,
    range: 155,
    tempo: .32,
    style: 'spear',
    value: 65,
  ),
  GearDef(
    'katana',
    '달빛 외날검',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 23,
    range: 145,
    tempo: .40,
    value: 90,
  ),
  GearDef(
    'halberd',
    '성채의 할버드',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 27,
    range: 185,
    tempo: .51,
    style: 'spear',
    value: 110,
  ),
  GearDef(
    'warhammer',
    '산맥 파괴 망치',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 30,
    range: 120,
    tempo: .58,
    style: 'hammer',
    value: 120,
  ),
  GearDef(
    'flail',
    '사슬 철퇴',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 24,
    range: 140,
    tempo: .49,
    style: 'hammer',
    value: 95,
  ),
  GearDef(
    'glaive',
    '청옥 월도',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 25,
    range: 190,
    tempo: .46,
    style: 'spear',
    value: 115,
  ),
  GearDef(
    'falchion',
    '태양의 곡도',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 24,
    range: 135,
    tempo: .44,
    value: 85,
  ),
  GearDef(
    'throwingaxes',
    '투척 도끼',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 17,
    range: 390,
    tempo: .40,
    style: 'throwing',
    value: 70,
  ),
  GearDef(
    'javelin',
    '투창',
    GearSlot.weapon,
    heroClass: HeroClass.warrior,
    attack: 21,
    range: 470,
    tempo: .48,
    style: 'throwing',
    value: 85,
  ),
];
GearDef gearById(String id) => gearCatalog.firstWhere((g) => g.id == id);

enum WeaponGift { frost, guardian, renewal, comboFury, comboGuard }

extension WeaponGiftInfo on WeaponGift {
  static const comboRageGain = 6.0;
  static const comboGuardDuration = .9;
  static const comboGuardReduction = .25;

  String get title => switch (this) {
    WeaponGift.frost => '서리의 낙인',
    WeaponGift.guardian => '수호의 맹세',
    WeaponGift.renewal => '생명의 수확',
    WeaponGift.comboFury => '연격의 격정',
    WeaponGift.comboGuard => '연격의 수호',
  };
  String get description => switch (this) {
    WeaponGift.frost =>
      '적중한 대상 둔화 ${CombatBalance.realSeconds(.8).toStringAsFixed(2)}초',
    WeaponGift.guardian => '받는 피해 8% 감소',
    WeaponGift.renewal => '처치 시 생명 4 회복',
    WeaponGift.comboFury => '분신 연격 3연계마다 분노 6 회복',
    WeaponGift.comboGuard =>
      '분신 연격 3연계마다 ${CombatBalance.realSeconds(WeaponGiftInfo.comboGuardDuration).toStringAsFixed(2)}초간 받는 피해 25% 감소',
  };
  bool get isCombo =>
      this == WeaponGift.comboFury || this == WeaponGift.comboGuard;
  bool supports(GearDef base) {
    if (!isCombo) return true;
    final profile = base.comboProfile;
    return profile != null && (profile.endless || profile.chainLength! >= 3);
  }
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
        this.gifts.any(
          (ability) =>
              !ability.supports(base) || affixVersion == 0 && ability.isCombo,
        ) ||
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
  static const _legacyGifts = [
    WeaponGift.frost,
    WeaponGift.guardian,
    WeaponGift.renewal,
  ];
  static List<WeaponGift> _defaultGifts(
    int serial,
    GearDef base,
    Rarity rarity,
    int version,
  ) {
    final pool = version > 0 && WeaponGift.comboFury.supports(base)
        ? WeaponGift.values
        : _legacyGifts;
    return [
      for (var i = 0; i < _giftCount(base, rarity, version); i++)
        pool[(serial + i) % pool.length],
    ];
  }

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
    if (abilities.any(
      (ability) => !ability.supports(base) || version == 0 && ability.isCombo,
    )) {
      throw const FormatException('Unsupported equipment ability');
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
    if (base.isThrowingWeapon) '투척 · 단일 대상',
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
  const BasicAttackStats(this.damage, this.interval, {this.criticalChance = 0});

  /// Damage per hit and recovery in real seconds at the shared game speed.
  final double damage, interval, criticalChance;
  double get dps => damage * (1 + criticalChance) / interval;
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
    this.mobility = false,
    this.rankLimit = 5,
    this.basicDamageScale = 1,
    this.basicTempoScale = 1,
    this.requires = const {},
  });
  final String id, name, branch, description;
  final int requiredLevel;
  final int rankLimit;
  final double cost, cooldown;
  final bool passive, basic, mobility;
  final double basicDamageScale, basicTempoScale;
  final Map<String, int> requires;
  static const maxRank = 5;
  int requiredLevelForRank(int desiredRank) =>
      requiredLevel +
      (rankLimit == 20 ? (desiredRank - 1).clamp(0, rankLimit - 1) : 0);
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
        'frenzy': '광분',
        'seismicSlam': '강타',
        'charge': '돌진',
        'crushingBlow': '집중 강타',
        'shadowAssault': '분신 연격',
        'iceArmor': '얼음 갑옷',
        'battleSprint': '질주',
        'blink': '순간이동',
      }[id] ??
      name;
}

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
    ranks[heroClass == HeroClass.warrior ? 'howl' : 'sorceressAttack'] = 1;
    selectedBasic = defaultBasicId;
    selectedSkill = heroClass == HeroClass.warrior ? 'howl' : 'firebolt';
    hp = maxHp;
    energy = heroClass == HeroClass.warrior ? 25 : maxEnergy;
  }
  final HeroClass heroClass;
  int activeSkillBonus = 0, frenzyStacks = 0;
  double activeLifeMultiplier = 1,
      activeResourceMultiplier = 1,
      activeArmorMultiplier = 1,
      concentrateArmorMultiplier = 1;
  bool berserkActive = false;
  double sorceressArmorMultiplier = 1;
  MountProgress mountProgress = MountProgress();
  int kills = 0, gold = 0, level = 1, xp = 0, skillPoints = 2;
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
  Iterable<SkillDef> get basicSkills =>
      skills.where((s) => s.basic && s.id != 'sorceressAttack');
  SkillDef get basicSkill => skills.firstWhere((s) => s.id == selectedBasic);
  bool canSelectBasic(String id) =>
      basicSkills.any((s) => s.id == id && rank(id) > 0);
  bool selectBasic(String id) {
    if (!canSelectBasic(id)) return false;
    selectedBasic = id;
    return true;
  }

  String basicElementFor(SkillDef skill) => switch (skill.id) {
    'iceBolt' => 'ice',
    'chargedBolt' => 'lightning',
    'sorceressAttack' => 'physical',
    _ => heroClass == HeroClass.mage ? 'fire' : weapon.base.style,
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
            'dualblades',
            'rapier',
            'throwingaxes',
            if (level >= 3) ...['katana', 'flail'],
            if (level >= 3) 'javelin',
            if (level >= 5) ...['greatsword', 'twinaxes', 'runeblade'],
            if (level >= 5) ...['halberd', 'warhammer', 'glaive', 'falchion'],
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
    'mountProgress': mountProgress.toSave(),
    'kills': kills,
    'gold': gold,
    'level': level,
    'xp': xp,
    'skillPoints': skillPoints,
    'healingPotions': healingPotions,
    'energyPotions': energyPotions,
    'serial': _serial,
    // Long warcries are transient. Save their fill ratio against the unbuffed
    // maxima so restoring without a buff neither grants healing nor loses it.
    'hp': heroClass == HeroClass.warrior
        ? (hp * (baseMaxHp / maxHp)).clamp(0.0, baseMaxHp)
        : hp,
    'energy': heroClass == HeroClass.warrior
        ? (energy * (baseMaxEnergy / maxEnergy)).clamp(0.0, baseMaxEnergy)
        : energy,
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
    if (heroClass == HeroClass.warrior) 'barbarianTreeVersion': 1,
    if (heroClass == HeroClass.mage) 'sorceressTreeVersion': 1,
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
      if (p.heroClass == HeroClass.warrior &&
          data['barbarianTreeVersion'] != 1) {
        return null;
      }
      if (p.heroClass == HeroClass.mage && data['sorceressTreeVersion'] != 1) {
        return null;
      }
      p.level = integer('level', max: 10000);
      if (p.level == 0) return null;
      p.kills = integer('kills');
      p.gold = integer('gold');
      p.xp = integer('xp');
      if (p.xp >= p.nextLevelXp) return null;
      p.skillPoints = integer('skillPoints');
      p.mountProgress = MountProgress.fromSave(data['mountProgress']);
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
            rank > skill.rankLimit ||
            skill.requiredLevelForRank(rank) > p.level) {
          return null;
        }
        p.ranks[skill.id] = rank;
      }
      if (p.rank(p.heroClass == HeroClass.warrior ? 'cleave' : 'firebolt') ==
          0) {
        return null;
      }
      if (p.heroClass == HeroClass.warrior && p.rank('howl') == 0) return null;
      // Retain the retired rank only as a compatibility marker for old saves.
      if (p.heroClass == HeroClass.mage &&
          !p.ranks.containsKey('sorceressAttack')) {
        p.ranks['sorceressAttack'] = 1;
      }
      if (p.heroClass == HeroClass.mage && p.rank('sorceressAttack') != 1) {
        return null;
      }
      if (p.skills.any((s) => p.rank(s.id) > 0 && !p.prerequisitesMet(s))) {
        return null;
      }
      final storedBasic = data['selectedBasic'] ?? p.defaultBasicId;
      final basic =
          p.heroClass == HeroClass.mage && storedBasic == 'sorceressAttack'
          ? p.defaultBasicId
          : storedBasic;
      if (basic is! String || !p.canSelectBasic(basic)) return null;
      p.selectedBasic = basic;
      p.selectedSkill = data['selectedSkill'] as String;
      final active = p.skills.firstWhere((s) => s.id == p.selectedSkill);
      if (active.passive || active.mobility || p.rank(active.id) == 0) {
        return null;
      }
      p.secondarySkill = data['secondarySkill'] as String?;
      if (p.secondarySkill != null) {
        final secondary = p.skills.firstWhere((s) => s.id == p.secondarySkill);
        if (secondary.passive ||
            secondary.mobility ||
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
                  !s.mobility &&
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
        if (skill.passive ||
            skill.mobility ||
            p.rank(skill.id) == 0 ||
            !assigned.add(skill.id)) {
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
      heroClass == HeroClass.warrior ? allWarriorSkills : allSorceressSkills;
  SkillDef get mobilitySkill => skills.firstWhere((s) => s.mobility);
  double get mobilityCooldown => skillCooldown(mobilitySkill);
  double get mobilityDuration => heroClass == HeroClass.warrior
      ? limitedSkillDuration(
          'battleSprint',
          (2.4 + math.max(0, rank('battleSprint') - 1) * .1) *
              staminaDurationMultiplier,
        )
      : 0;
  double get mobilityRange => heroClass == HeroClass.mage && rank('blink') > 0
      ? sorceressSpell(mobilitySkill).range
      : 0;
  SkillDef? get secondarySkillDef => secondarySkill == null
      ? null
      : skills.firstWhere((s) => s.id == secondarySkill);
  SkillDef get activeSkill => skills.firstWhere((s) => s.id == selectedSkill);
  int rank(String id) => ranks[id] ?? 0;

  /// atRank always denotes invested points, before Battle Command.
  int effectiveRank(String id, {int? atRank}) {
    final def = skills.where((s) => s.id == id).firstOrNull;
    if (def == null) return 0;
    final invested = (atRank ?? rank(id)).clamp(0, def.rankLimit);
    return invested == 0
        ? 0
        : invested +
              (heroClass == HeroClass.warrior
                  ? activeSkillBonus.clamp(0, 1)
                  : 0);
  }

  static double _statMultiplier(double v) => v.isFinite ? v.clamp(1.0, 3.0) : 1;
  String get weaponMasteryId => usingFallbackWeapon
      ? ''
      : switch (weapon.base.id) {
          'halberd' || 'glaive' => 'polearmMastery',
          _ => switch (weapon.base.style) {
            'throwing' => 'throwingMastery',
            'axe' => 'axeMastery',
            'hammer' => 'maceMastery',
            'spear' => 'spearMastery',
            _ => 'swordMastery',
          },
        };
  double get weaponMasteryDamageMultiplier => heroClass == HeroClass.warrior
      ? 1 + effectiveRank(weaponMasteryId) * .02
      : 1;
  double get throwingMasteryDamageMultiplier =>
      1 + effectiveRank('throwingMastery') * .02;
  double get weaponCriticalChance =>
      _masteryCritical(effectiveRank(weaponMasteryId));
  double get throwingCriticalChance =>
      _masteryCritical(effectiveRank('throwingMastery'));
  static double _masteryCritical(int r) =>
      r == 0 ? 0 : (.03 + r * .004).clamp(0.0, .15);
  double get increasedSpeedMultiplier =>
      heroClass == HeroClass.warrior && effectiveRank('increasedSpeed') > 0
      ? 1.05 + effectiveRank('increasedSpeed') * .01
      : 1;
  double get staminaDurationMultiplier =>
      1 + effectiveRank('increasedStamina') * .04;
  double get barbarianStatusResistance =>
      effectiveRank('naturalResistance') == 0
      ? 0
      : (.08 + effectiveRank('naturalResistance') * .012).clamp(0.0, .35);
  double skillCost(SkillDef skill, {int? atRank}) => isSorceressSpell(skill)
      ? sorceressSpell(skill, atRank: atRank).manaCost
      : skill.id == 'doubleSwing'
      ? math.max(
          0.0,
          skill.cost -
              math.max(0, effectiveRank(skill.id, atRank: atRank) - 1) * .25,
        )
      : skill.cost;
  double skillRange(SkillDef skill, {int? atRank}) {
    if (isSorceressSpell(skill)) {
      return sorceressSpell(skill, atRank: atRank).range;
    }
    if (skill.id == 'sorceressAttack') return 100;
    final r = effectiveRank(skill.id, atRank: atRank);
    return switch (skill.id) {
      'leap' => 120.0 + r * 8,
      'leapAttack' => 180.0 + r * 8,
      'doubleThrow' => 420.0,
      _ => skill.basic ? weapon.base.range : weapon.base.contactRange,
    };
  }

  double barbarianRadius(String id, {int? atRank}) {
    final r = effectiveRank(id, atRank: atRank);
    return switch (id) {
      'leap' => 70.0 + r * 3,
      'howl' => 140.0 + r * 5,
      'taunt' => 280.0,
      'grimWard' => 160.0 + r * 4,
      'findPotion' || 'findItem' => 180.0,
      _ => 180.0 + r * 3,
    };
  }

  double barbarianBuffDuration(String id, {int? atRank}) {
    final r = effectiveRank(id, atRank: atRank);
    if (r == 0) return 0;
    final synergy = switch (id) {
      'shout' => rank('battleOrders') + rank('battleCommand'),
      'battleOrders' => rank('shout') + rank('battleCommand'),
      'battleCommand' => rank('shout') + rank('battleOrders'),
      _ => 0,
    };
    // Original long warcries are refreshable buffs, not cooldown-limited bursts.
    if (id == 'shout') return 20.0 + (r - 1) * 10 + synergy * 5;
    if (id == 'battleOrders') return 30.0 + (r - 1) * 10 + synergy * 5;
    if (id == 'battleCommand') return 5.0 + (r - 1) * 10 + synergy * 5;
    if (id == 'grimWard') return 40;
    // Frenzy refreshes on melee hits, allowing consecutive attacks to build stacks.
    if (id == 'frenzy') return 6;
    return limitedSkillDuration(id, 3.0 + r * .06, atRank: atRank);
  }

  double barbarianEffectDuration(String id, {int? atRank}) {
    final r = effectiveRank(id, atRank: atRank);
    final nominal = switch (id) {
      'berserk' => 1.5,
      'stun' => .6 + r * .025,
      'warcry' => .8 + r * .035,
      'battleCry' => 4.0 + r * .06,
      _ => 2.0 + r * .06,
    };
    return limitedSkillDuration(id, nominal, atRank: atRank);
  }

  double barbarianFindChance(String id, {int? atRank}) {
    final r = effectiveRank(id, atRank: atRank);
    return r == 0
        ? 0
        : (id == 'findPotion' ? .25 + r * .015 : .15 + r * .012).clamp(
            0.0,
            .65,
          );
  }

  double shoutArmorMultiplier({int? atRank}) =>
      1.25 + effectiveRank('shout', atRank: atRank) * .025;
  double battleOrdersMultiplier({int? atRank}) =>
      1.08 + effectiveRank('battleOrders', atRank: atRank) * .008;
  double battleCryOutgoingMultiplier({int? atRank}) =>
      .88 - effectiveRank('battleCry', atRank: atRank) * .008;
  double battleCryIncomingMultiplier({int? atRank}) =>
      1.06 + effectiveRank('battleCry', atRank: atRank) * .008;
  double concentrateDefenseMultiplier({int? atRank}) =>
      1.5 + effectiveRank('concentrate', atRank: atRank) * .1;

  int get nextLevelXp => CombatBalance.experienceForLevel(level);
  late final _fallbackWeapon = Gear(
    0,
    heroClass == HeroClass.warrior ? _unarmedDef : _innateMagicDef,
    locked: true,
  );
  bool get usingFallbackWeapon => !equipped.containsKey(GearSlot.weapon);
  Gear get weapon => equipped[GearSlot.weapon] ?? _fallbackWeapon;
  double get baseMaxHp =>
      (heroClass == HeroClass.warrior ? 100 : 80) +
      (level - 1) * 10 +
      bonusHealth +
      equipped.values.fold(0.0, (v, g) => v + g.health);
  double get maxHp =>
      baseMaxHp *
      (heroClass == HeroClass.warrior
          ? _statMultiplier(activeLifeMultiplier)
          : 1);
  set maxHp(double value) => bonusHealth +=
      (value - maxHp) /
      (heroClass == HeroClass.warrior
          ? _statMultiplier(activeLifeMultiplier)
          : 1);
  double get baseMaxEnergy =>
      (heroClass == HeroClass.warrior ? 100 : 90) +
      equipped.values.fold(0.0, (v, g) => v + g.mana);
  double get maxEnergy =>
      baseMaxEnergy *
      (heroClass == HeroClass.warrior
          ? _statMultiplier(activeResourceMultiplier)
          : 1);
  double get armor {
    final gearArmor = equipped.values.fold(0.0, (v, g) => v + g.armor);
    if (heroClass != HeroClass.warrior) {
      return gearArmor * _statMultiplier(sorceressArmorMultiplier);
    }
    if (berserkActive) return 0;
    final r = effectiveRank('ironSkin');
    return gearArmor *
        (r == 0 ? 1 : 1.25 + r * .05) *
        _statMultiplier(activeArmorMultiplier) *
        _statMultiplier(concentrateArmorMultiplier);
  }

  static const playerDamageScale = .75 * CombatBalance.heroDamageScale;
  static const skillCooldownScale = .9;
  double get attackMultiplier =>
      (heroClass == HeroClass.warrior ? weaponMasteryDamageMultiplier : 1.0) *
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
      : const ['냉기', '번개', '화염'];
  double get manaRecovery =>
      9 *
      CombatBalance.resourceGainScale *
      SorceressRules.warmthMultiplier(effectiveRank('warmth'));
  double get fireDamageMultiplier =>
      SorceressRules.fireMastery(effectiveRank('fireMastery'));
  double get coldDamageMultiplier => 1;
  double get lightningDamageMultiplier =>
      SorceressRules.lightningMastery(effectiveRank('lightningMastery'));
  double get sorceressColdPierce =>
      SorceressRules.coldPierce(effectiveRank('coldMastery'));

  bool isSorceressSpell(SkillDef skill) =>
      heroClass == HeroClass.mage && mageSkills.contains(skill);
  SorceressSpellStats sorceressSpell(SkillDef skill, {int? atRank}) =>
      SorceressRules.evaluate(
        skill.id,
        rank: isSorceressSpell(skill)
            ? effectiveRank(skill.id, atRank: atRank)
            : 0,
        hardRanks: ranks,
        damageScale: playerDamageScale * CombatBalance.skillDamageScale,
      );
  int get basicTargetLimit => basicTargetLimitForRank(rank(selectedBasic));
  int basicTargetLimitForRank(int rank, {SkillDef? basic}) {
    final skill = basic ?? basicSkill;
    if (rank <= 0) return 0;
    if (isSorceressSpell(skill)) {
      return sorceressSpell(skill, atRank: rank).maxTargets;
    }
    if (skill.id == 'sorceressAttack') return 1;
    if (heroClass == HeroClass.warrior && weapon.base.isThrowingWeapon) {
      return 1;
    }
    return switch (skill.id) {
      'cleave' || 'firebolt' || 'sparkBolt' => SkillGrowth.level(rank),
      _ => 1,
    };
  }

  int skillTargetLimit(SkillDef skill, {int? atRank}) {
    final r = effectiveRank(skill.id, atRank: atRank);
    if (r == 0 || !skills.contains(skill)) return 0;
    if (isSorceressSpell(skill)) {
      return sorceressSpell(skill, atRank: atRank).maxTargets;
    }
    if (skill.basic) return basicTargetLimitForRank(r, basic: skill);
    if (heroClass == HeroClass.warrior && skill.rankLimit == 20) {
      return switch (skill.id) {
        'leap' || 'howl' || 'warcry' || 'battleCry' || 'grimWard' => 3 + r - 1,
        'doubleThrow' => 2,
        'bash' ||
        'doubleSwing' ||
        'stun' ||
        'leapAttack' ||
        'concentrate' ||
        'frenzy' ||
        'berserk' ||
        'taunt' ||
        'findPotion' ||
        'findItem' => 1,
        'whirlwind' => 3 + r - 1,
        _ => 0,
      };
    }
    return switch (skill.id) {
      'shadowAssault' => r,
      'whirlwind' || 'seismicSlam' => 2 + r + rank('stormOfSteel'),
      'chainLightning' => 2 + r + rank('forkedStorm'),
      'meteor' => 2 + r + rank('cinderReach'),
      'warcry' ||
      'frostNova' ||
      'frenzy' ||
      'charge' ||
      'crushingBlow' => 2 + r,
      _ => 0,
    };
  }

  double skillCooldown(SkillDef skill, {int? atRank}) {
    final r = atRank ?? rank(skill.id);
    if (isSorceressSpell(skill)) {
      return sorceressSpell(skill, atRank: atRank).castDelay;
    }
    if (skill.passive || r <= 0 || !skills.contains(skill)) return 0;
    if (skill.rankLimit == 20) return skill.cooldown * skillCooldownScale;
    final specialty = switch (skill.id) {
      'whirlwind' || 'seismicSlam' => rank('stormOfSteel'),
      'meteor' => rank('cinderReach'),
      'chainLightning' => rank('forkedStorm'),
      _ => 0,
    };
    return skill.cooldown *
        skillCooldownScale *
        SkillGrowth.cooldown(r) *
        (1 - specialty * .005);
  }

  double skillTempo(SkillDef skill, {int? atRank}) => isSorceressSpell(skill)
      ? 1 + attackHaste
      : skill.rankLimit == 20
      ? .75 *
            (1 +
                math.max(0, effectiveRank(skill.id, atRank: atRank) - 1) * .005)
      : SkillGrowth.tempo(atRank ?? rank(skill.id));
  double skillMotionTime(SkillDef skill, {int? atRank}) {
    if (isSorceressSpell(skill)) {
      return sorceressSpell(skill, atRank: atRank).motionTime /
          skillTempo(skill, atRank: atRank);
    }
    final base = heroClass == HeroClass.mage
        ? .48
        : switch (skill.id) {
            'leap' || 'leapAttack' => .54,
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
  double shadowAssaultStrikeScale(int strike) => 1.1 + strike.clamp(1, 5) * .1;
  double get frenzyAttackTempo =>
      1 + frenzyStacks.clamp(0, 6) * (.02 + effectiveRank('frenzy') * .001);
  double get frenzyMoveSpeed =>
      CombatBalance.normalMoveSpeed *
      increasedSpeedMultiplier *
      (1 + frenzyStacks.clamp(0, 6) * (.025 + effectiveRank('frenzy') * .001));
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

  double get frenzyDuration => barbarianBuffDuration('frenzy');
  double get iceArmorDuration => limitedSkillDuration(
    'iceArmor',
    5 + math.max(0, rank('iceArmor') - 1) * .3,
  );
  double get novaSlowDuration => sorceressSpell(
    mageSkills.firstWhere((s) => s.id == 'frostNova'),
  ).chillDuration;
  double get warcryStun =>
      limitedSkillDuration('warcry', 1 + math.max(0, rank('warcry') - 1) * .05);

  double get basicDamage => skillDamage(basicSkill);
  double skillDamage(SkillDef skill, {int? atRank}) {
    if (isSorceressSpell(skill)) {
      final stats = sorceressSpell(skill, atRank: atRank);
      return stats.meanDamage > 0
          ? stats.meanDamage
          : stats.damagePerSecond * stats.interval;
    }
    if (heroClass == HeroClass.mage && skill.id == 'sorceressAttack') {
      return swordDamage * CombatBalance.skillDamageScale;
    }
    final r = effectiveRank(skill.id, atRank: atRank);
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
      'sparkBolt' => (1 + math.max(0, r - 1) * .01) * skill.basicDamageScale,
      'warcry' => 1.25 + math.max(0, r - 1) * .02,
      'bash' => 1.5 + math.max(0, r - 1) * .04,
      'doubleSwing' => .62 + math.max(0, r - 1) * .015,
      'stun' => 1.0 + math.max(0, r - 1) * .02,
      'doubleThrow' =>
        (.65 + math.max(0, r - 1) * .02) *
            throwingMasteryDamageMultiplier /
            weaponMasteryDamageMultiplier,
      'leapAttack' || 'berserk' => 2.0 + math.max(0, r - 1) * .05,
      'concentrate' => 1.6 + math.max(0, r - 1) * .035,
      'whirlwind' => 1.34 + math.max(0, r - 1) * .015,
      'frenzy' => .8 + math.max(0, r - 1) * .02,
      'charge' => 1.65 + math.max(0, r - 1) * .015,
      'crushingBlow' => 2.6 + math.max(0, r - 1) * .025,
      'shadowAssault' => 1.0,
      'seismicSlam' => 2.12 + math.max(0, r - 1) * .025,
      'frostNova' => 1.4 + math.max(0, r - 1) * .015,
      'chainLightning' => 1.85 + math.max(0, r - 1) * .025,
      'meteor' => 3.6 + math.max(0, r - 1) * .04,
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
      'cleave' || 'quickCut' || 'heavyStrike' => 1 + rank('rendingEdge') * .015,
      'warcry' => 1 + rank('resoundingCry') * .02,
      'whirlwind' || 'seismicSlam' => 1 + rank('stormOfSteel') * .005,
      'meteor' => 1 + rank('cinderReach') * .005,
      'chainLightning' => 1 + rank('forkedStorm') * .005,
      _ => 1.0,
    };
    final bonus = (element * (fire ? fireDamageMultiplier : 1) * specialization)
        .clamp(1.0, CombatBalance.maximumSkillDamageMultiplier);
    final source = skill.id == 'warcry'
        ? swordDamage / weaponMasteryDamageMultiplier
        : swordDamage;
    return source * factor * bonus * CombatBalance.skillDamageScale;
  }

  double skillProtection(String id, {int? atRank}) {
    final r = (atRank ?? rank(id)).clamp(0, SkillDef.maxRank);
    return id == 'warcry'
        ? (.12 +
                  r * .01 +
                  rank('unyieldingOath') * .005 +
                  rank('battleVigor') * .005)
              .clamp(0.0, .25)
        : id == 'iceArmor'
        ? (.15 + r * .015 + rank('frozenAegis') * .005).clamp(0.0, .30)
        : 0;
  }

  double get warcryDuration => limitedSkillDuration(
    'warcry',
    2.6 + math.max(0, rank('warcry') - 1) * .1,
  );
  double rageOnHit({required bool protected}) =>
      (3.0 +
          (protected
              ? rank('rallyingVoice') * .3 + rank('warDrums') * .15
              : 0)) *
      CombatBalance.resourceGainScale;

  double get attackHaste =>
      (equipped.values.fold(0.0, (v, g) => v + g.base.haste) +
              rank('battleFocus') * .006 +
              rank('weaponTempo') * .004)
          .clamp(0.0, CombatBalance.maximumAttackHaste);

  double attackIntervalFor(SkillDef skill, {int? atRank}) =>
      isSorceressSpell(skill)
      ? skillMotionTime(skill, atRank: atRank)
      : math.max(
          CombatBalance.minimumBasicInterval,
          weapon.base.tempo /
              basicTempoFor(skill, atRank: atRank) *
              (1 - attackHaste),
        );
  double get attackInterval => attackIntervalFor(basicSkill);

  /// Single-hit cadence shared by combat and equipment comparisons. Combo
  /// finishers/follow-ups and enemy damage sharing are separate hit rules.
  /// Returns simulation seconds; [basicAttackStats] converts to real seconds.
  double actualBasicInterval({double frenzyTempo = 1, double attackTempo = 1}) {
    if (!frenzyTempo.isFinite ||
        frenzyTempo <= 0 ||
        !attackTempo.isFinite ||
        attackTempo <= 0) {
      throw ArgumentError('Attack tempo must be positive and finite');
    }
    if (isSorceressSpell(basicSkill)) {
      return skillMotionTime(basicSkill) / attackTempo;
    }
    final recovery =
        math.max(
          CombatBalance.minimumStrikeInterval,
          attackInterval / frenzyTempo,
        ) /
        attackTempo;
    return heroClass == HeroClass.mage
        ? math.max(recovery, .26 / (basicTempo * attackTempo))
        : recovery;
  }

  BasicAttackStats basicAttackStats({
    double frenzyTempo = 1,
    double attackTempo = 1,
  }) => BasicAttackStats(
    basicDamage,
    CombatBalance.realSeconds(
      actualBasicInterval(frenzyTempo: frenzyTempo, attackTempo: attackTempo),
    ),
    criticalChance: heroClass == HeroClass.warrior ? weaponCriticalChance : 0,
  );
  double get basicDps => basicAttackStats().dps;
  BasicAttackStats? previewBasicAttack(
    Gear gear, {
    double frenzyTempo = 1,
    double attackTempo = 1,
  }) {
    if (!gear.base.usable(heroClass)) return null;
    if (isEquipped(gear)) {
      return basicAttackStats(
        frenzyTempo: frenzyTempo,
        attackTempo: attackTempo,
      );
    }
    final next = Progress(heroClass: heroClass)
      ..level = level
      ..bonusAttack = bonusAttack
      ..bonusHealth = bonusHealth
      ..selectedBasic = selectedBasic
      ..activeSkillBonus = activeSkillBonus
      ..frenzyStacks = frenzyStacks
      ..activeLifeMultiplier = activeLifeMultiplier
      ..activeResourceMultiplier = activeResourceMultiplier
      ..activeArmorMultiplier = activeArmorMultiplier
      ..concentrateArmorMultiplier = concentrateArmorMultiplier
      ..berserkActive = berserkActive
      ..sorceressArmorMultiplier = sorceressArmorMultiplier;
    next.ranks
      ..clear()
      ..addAll(ranks);
    next.equipped
      ..clear()
      ..addAll(equipped)
      ..[gear.base.slot] = gear;
    return next.basicAttackStats(
      frenzyTempo: frenzyTempo,
      attackTempo: attackTempo,
    );
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
      ((boss
                      ? 80
                      : unique
                      ? 26
                      : elite
                      ? 18
                      : 8) *
                  CombatBalance.enemyExperienceScale)
              .round() *
          CombatBalance.experienceRewardMultiplier,
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
      level >= s.requiredLevelForRank(rank(s.id) + 1) &&
      skillPoints > 0 &&
      rank(s.id) < s.rankLimit &&
      (rank(s.id) > 0 || prerequisitesMet(s));
  int get investedSkillPoints {
    final basic = heroClass == HeroClass.warrior ? 'cleave' : 'firebolt';
    final starter = heroClass == HeroClass.warrior ? 'howl' : 'sorceressAttack';
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
    final starter = heroClass == HeroClass.warrior ? 'howl' : 'sorceressAttack';
    selectedBasic = basic;
    ranks
      ..clear()
      ..[basic] = 1
      ..[starter] = 1;
    selectedSkill = heroClass == HeroClass.warrior ? starter : basic;
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
    if (!skill.passive && !skill.mobility && !skillSlots.contains(skill.id)) {
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
        !skills.any(
          (s) => s.id == id && !s.passive && !s.mobility && rank(id) > 0,
        )) {
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

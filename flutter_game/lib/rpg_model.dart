import 'dart:math' as math;

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

class Gear {
  Gear(
    this.serial,
    this.base, {
    this.rarity = Rarity.common,
    this.power = 0,
    this.vitality = 0,
    this.focus = 0,
    this.locked = false,
  });
  final int serial;
  final GearDef base;
  final Rarity rarity;
  final int power, vitality, focus;
  bool locked;
  Map<String, dynamic> toSave() => {
    'serial': serial,
    'base': base.id,
    'rarity': rarity.name,
    'power': power,
    'vitality': vitality,
    'focus': focus,
    'locked': locked,
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
    final locked = data['locked'] ?? false;
    if (locked is! bool) throw const FormatException('Invalid equipment lock');
    return Gear(
      serial,
      gearById(data['base'] as String),
      rarity: Rarity.values.firstWhere((v) => v.name == data['rarity']),
      power: stat('power'),
      vitality: stat('vitality'),
      focus: stat('focus'),
      locked: locked,
    );
  }
  String get name => rarity == Rarity.unique
      ? '파수꾼의 유산 · ${base.name}'
      : rarity == Rarity.common
      ? base.name
      : '${power > 0
            ? '맹공'
            : vitality > 0
            ? '생명'
            : '집중'}의 ${base.name}';
  double get attack => base.attack + power;
  double get armor =>
      base.armor + (base.slot == GearSlot.armor ? rarity.index * 2 : 0);
  double get health => base.health + vitality;
  double get mana => base.mana + focus;
  int get saleValue =>
      math.max(5, (base.value * (1 + rarity.index * .6) / 3).round());
  String get stats => [
    if (attack > 0) '공격 +${attack.round()}',
    if (armor > 0) '방어 +${armor.round()}',
    if (health > 0) '생명 +${health.round()}',
    if (mana > 0) '마나 +${mana.round()}',
    if (base.haste > 0) '공격속도 +${(base.haste * 100).round()}%',
  ].join(' · ');
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
  });
  final String id, name, branch, description;
  final int requiredLevel;
  final double cost, cooldown;
  final bool passive;
  static const maxRank = 5;
  String get shortName =>
      {
        'warcry': '함성',
        'whirlwind': '소용돌이',
        'frenzy': '격노',
        'seismicSlam': '강타',
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
    '기본 공격 피해가 등급마다 15% 증가합니다. 세 번째 공격은 강타합니다.',
    1,
    0,
    0,
    passive: true,
  ),
  SkillDef(
    'warcry',
    '전장의 함성',
    '함성',
    '주변 적에게 피해를 주고 2초간 기절시킵니다. 6초간 받는 피해도 줄어듭니다.',
    1,
    18,
    7,
  ),
  SkillDef(
    'mastery',
    '무기 숙련',
    '무기 숙련',
    '등급마다 모든 무기 피해 +8%.',
    2,
    0,
    0,
    passive: true,
  ),
  SkillDef(
    'ironSkin',
    '강철 피부',
    '무기 숙련',
    '등급마다 방어 +5, 최대 생명 +8.',
    2,
    0,
    0,
    passive: true,
  ),
  SkillDef(
    'whirlwind',
    '소용돌이',
    '전투 기술',
    '넓은 범위를 세 차례 베고 적을 밀어냅니다. 등급마다 피해가 증가합니다.',
    3,
    30,
    5,
  ),
  SkillDef(
    'frenzy',
    '광전사의 격노',
    '함성',
    '7초간 공격속도와 이동속도가 증가합니다. 발동 시 주변 적을 벱니다.',
    4,
    28,
    12,
  ),
  SkillDef(
    'seismicSlam',
    '대지 강타',
    '전투 기술',
    '전방의 지면을 내리쳐 피해를 주고 잠시 기절시킵니다. 장애물 너머에는 피해를 주지 않습니다.',
    5,
    24,
    8,
  ),
];
const mageSkills = [
  SkillDef(
    'firebolt',
    '화염탄',
    '화염',
    '기본 원거리 공격. 등급마다 피해 +18%, 3등급부터 적중 시 폭발합니다.',
    1,
    0,
    0,
    passive: true,
  ),
  SkillDef(
    'frostNova',
    '서릿발',
    '냉기',
    '주변 적에게 냉기 피해를 주고 2초간 빙결시킵니다. 등급마다 범위가 증가합니다.',
    1,
    18,
    6,
  ),
  SkillDef(
    'arcaneMastery',
    '원소 숙련',
    '번개',
    '등급마다 원소 피해 +9%, 최대 마나 +8.',
    2,
    0,
    0,
    passive: true,
  ),
  SkillDef(
    'iceArmor',
    '얼음 갑옷',
    '냉기',
    '12초간 피해를 줄이고 근접 공격자를 둔화합니다. 등급마다 방어가 증가합니다.',
    2,
    20,
    15,
  ),
  SkillDef(
    'chainLightning',
    '연쇄 번개',
    '번개',
    '가까운 적 사이를 최대 5회 튕기는 번개. 장애물 너머로는 전이되지 않습니다.',
    3,
    28,
    5,
  ),
  SkillDef(
    'meteor',
    '유성 낙하',
    '화염',
    '바라보는 방향의 적에게 유성을 떨어뜨려 넓은 화염 피해를 줍니다.',
    4,
    38,
    9,
  ),
];

class StageExit {
  const StageExit(
    this.direction,
    this.destination,
    this.x,
    this.y,
    this.description,
  );
  final String direction, destination, description;
  final double x, y;
}

const stageExits = [
  StageExit('북', '잊힌 대성당', 4650, 360, '지하로 내려가는 돌계단 · 다음 스테이지'),
  StageExit('동', '침수된 회랑', 7000, 4780, '무너진 수로 너머의 유적 · 다음 스테이지'),
  StageExit('남', '잿빛 탑', 3000, 5380, '층마다 시련이 이어지는 탑 · 다음 스테이지'),
  StageExit('서', '가시덤불 묘지', 420, 4640, '버려진 묘지와 지하 납골당 · 다음 스테이지'),
];
const stageMemories = [
  (
    chest: 1,
    title: '끊어진 맹세',
    hint: '서쪽 숲길의 상자',
    story: '파수꾼은 한때 네 갈래 길을 지키던 수호자였다. 마을의 종이 멎은 밤, 그가 지키던 맹세도 함께 깨졌다.',
  ),
  (
    chest: 2,
    title: '마지막 종소리',
    hint: '마을 북쪽 길의 상자',
    story:
        '대성당의 종은 지하의 어둠을 잠재우고 있었다. 마지막 종지기는 북쪽 계단 아래로 사라졌고, 그날부터 숲에 망자들이 나타났다.',
  ),
  (
    chest: 3,
    title: '물 아래의 문',
    hint: '동쪽 목교 앞 숲길의 상자',
    story:
        '회랑에 물이 차오르자 잊힌 문이 열렸다. 서쪽 묘지와 남쪽 탑에서도 같은 문장이 발견되었다. 네 길의 어둠은 하나로 이어져 있다.',
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
    'selectedSkill': selectedSkill,
    'secondarySkill': secondarySkill,
    'tertiarySkill': tertiarySkill,
    'quaternarySkill': quaternarySkill,
    'ranks': Map<String, int>.of(ranks),
    'inventory': inventory.map((g) => g.toSave()).toList(),
    'unseenGear': unseenGear.toList(),
    'equipped': equipped.map((slot, gear) => MapEntry(slot.name, gear.serial)),
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
      final items = data['inventory'] as List;
      if (items.isEmpty || items.length > capacity) return null;
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
      if (!p.equipped.containsKey(GearSlot.weapon)) return null;
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
      p._serial = math.max(integer('serial'), identities.reduce(math.max) + 1);
      p.hp = decimal('hp').clamp(0, p.maxHp);
      p.energy = decimal('energy').clamp(0, p.maxEnergy);
      return p;
    } catch (_) {
      return null;
    }
  }

  static const capacity = 24;
  int get stage => 1;
  List<SkillDef> get skills =>
      heroClass == HeroClass.warrior ? warriorSkills : mageSkills;
  SkillDef? get secondarySkillDef => secondarySkill == null
      ? null
      : skills.firstWhere((s) => s.id == secondarySkill);
  SkillDef get activeSkill => skills.firstWhere((s) => s.id == selectedSkill);
  int rank(String id) => ranks[id] ?? 0;
  int get nextLevelXp => 55 + (level - 1) * 30;
  Gear get weapon => equipped[GearSlot.weapon]!;
  double get maxHp =>
      (heroClass == HeroClass.warrior ? 100 : 80) +
      (level - 1) * 10 +
      bonusHealth +
      equipped.values.fold(0.0, (v, g) => v + g.health) +
      rank('ironSkin') * 8;
  set maxHp(double value) => bonusHealth += value - maxHp;
  double get maxEnergy =>
      (heroClass == HeroClass.warrior ? 100 : 90) +
      equipped.values.fold(0.0, (v, g) => v + g.mana) +
      rank('arcaneMastery') * 8;
  double get armor =>
      equipped.values.fold(0.0, (v, g) => v + g.armor) + rank('ironSkin') * 5;
  double get swordDamage =>
      (bonusAttack +
          (level - 1) * 2 +
          equipped.values.fold(0.0, (v, g) => v + g.attack)) *
      (1 + rank('mastery') * .08 + rank('arcaneMastery') * .09);
  set swordDamage(double value) => bonusAttack +=
      (value - swordDamage) /
      (1 + rank('mastery') * .08 + rank('arcaneMastery') * .09);
  double get basicDamage =>
      swordDamage *
      (1 +
          math.max(
                0,
                rank(heroClass == HeroClass.warrior ? 'cleave' : 'firebolt') -
                    1,
              ) *
              (heroClass == HeroClass.warrior ? .15 : .18));
  double get attackInterval => math.max(
    .16,
    weapon.base.tempo *
        (1 - equipped.values.fold(0.0, (v, g) => v + g.base.haste)),
  );
  double mitigate(double damage, {double protection = 0}) =>
      damage * 100 / (100 + armor * 3) * (1 - protection.clamp(0, .75));
  void reward({bool boss = false, bool elite = false}) {
    kills++;
    gold += boss
        ? 100
        : elite
        ? 20
        : 8;
    bossDefeated |= boss;
    gainXp(
      boss
          ? 100
          : elite
          ? 30
          : 18,
    );
  }

  void gainXp(int amount) {
    xp += amount;
    while (xp >= nextLevelXp) {
      xp -= nextLevelXp;
      level++;
      skillPoints++;
      hp = math.min(maxHp, hp + maxHp * .2);
      energy = heroClass == HeroClass.mage
          ? maxEnergy
          : math.min(maxEnergy, energy + 20);
    }
  }

  bool canLearn(SkillDef s) =>
      skills.contains(s) &&
      level >= s.requiredLevel &&
      skillPoints > 0 &&
      rank(s.id) < SkillDef.maxRank;
  static const skillResetPrice = 50;
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

  bool resetSkills() {
    final refund = investedSkillPoints;
    if (refund == 0 || gold < skillResetPrice) return false;
    gold -= skillResetPrice;
    skillPoints += refund;
    final basic = heroClass == HeroClass.warrior ? 'cleave' : 'firebolt';
    final starter = heroClass == HeroClass.warrior ? 'warcry' : 'frostNova';
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
    skillPoints--;
    ranks[skill.id] = rank(skill.id) + 1;
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

  bool selectSkill(String id, {int slot = 0}) {
    final found = skills.where((s) => s.id == id && !s.passive && rank(id) > 0);
    if (found.isEmpty || slot < 0 || slot > 3) return false;
    final values = skillSlots, previous = skillSlots.indexOf(id);
    if (previous >= 0 && previous != slot) values[previous] = values[slot];
    values[slot] = id;
    if (values[0] == null) return false;
    selectedSkill = values[0]!;
    secondarySkill = values[1];
    tertiarySkill = values[2];
    quaternarySkill = values[3];
    return true;
  }

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
  }) => Gear(
    _serial++,
    def,
    rarity: rarity,
    power: power,
    vitality: vitality,
    focus: focus,
  );
  Gear rollLoot(
    math.Random random, {
    bool boss = false,
    bool chest = false,
    bool elite = false,
  }) {
    if (boss) {
      return createGear(
        gearById('sentinel'),
        rarity: Rarity.unique,
        power: 3,
        vitality: 10,
      );
    }
    final pool = gearCatalog
        .where(
          (g) => g.usable(heroClass) && g.id != 'sentinel' && g.id != 'linen',
        )
        .toList();
    final def = pool[random.nextInt(pool.length)];
    final roll = random.nextDouble();
    final rarity = roll < (chest || elite ? .25 : .12)
        ? Rarity.rare
        : roll < .68 || elite
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
    );
  }

  // Common copies become gold; rolled gear keeps its own identity and options.
  bool collect(Gear item) {
    if (item.rarity == Rarity.common &&
        inventory.any((g) => g.base.id == item.base.id)) {
      gold += item.saleValue;
      return false;
    }
    if (inventory.length >= capacity) return false;
    inventory.add(item);
    unseenGear.add(item.serial);
    return true;
  }

  bool buy(int price, void Function() apply) {
    if (price < 0 || gold < price) return false;
    gold -= price;
    apply();
    return true;
  }
}

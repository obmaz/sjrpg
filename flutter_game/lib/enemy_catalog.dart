import 'dart:ui';

import 'player_afflictions.dart';
import 'stage_content.dart';

const monsterHealthScale = .8;

class EnemyDef {
  const EnemyDef(
    this.name,
    this.health,
    this.speed,
    this.pattern, {
    this.lowProfile = false,
    this.technological = false,
    this.renderHeight = 62,
    this.attackWarning,
    this.attackRange,
    this.attackSpeed,
    this.attackDamage,
    this.attackRecovery,
    this.attackColor,
    this.onHitStatus,
  });
  final String name, pattern;
  final double health, speed;
  // Presentation flags never alter the shared ground collision rules.
  final bool lowProfile, technological;
  final double renderHeight;
  // Optional overrides tune the primary pattern, not the fallback close bite.
  final double? attackWarning,
      attackRange,
      attackSpeed,
      attackDamage,
      attackRecovery;
  final Color? attackColor;
  final PlayerStatus? onHitStatus;
}

const enemyCatalog = {
  'goblin': EnemyDef('고블린', 28, 105, 'chase'),
  'wolf': EnemyDef('늑대', 38, 135, 'pounce', renderHeight: 55),
  'skeleton': EnemyDef('해골 전사', 52, 105, 'sweep'),
  'cultist': EnemyDef('광신도', 52, 105, 'bolt'),
  'scorpion': EnemyDef(
    '거대 전갈',
    52,
    105,
    'pounce',
    attackColor: Color(0xffb2df73),
    onHitStatus: PlayerStatus.poison,
  ),
  'mummy': EnemyDef('미라', 52, 105, 'chase'),
  'troll': EnemyDef('트롤', 52, 105, 'sweep', renderHeight: 80),
  'cyber': EnemyDef('검날 경비병', 52, 105, 'sweep'),
  'gunner': EnemyDef(
    '펄스 사수',
    52,
    105,
    'bolt',
    technological: true,
    attackWarning: .9,
    attackRecovery: 4.5,
    attackColor: Color(0xffc9b6ff),
    onHitStatus: PlayerStatus.blind,
  ),
  'boar': EnemyDef('멧돼지', 46, 145, 'pounce'),
  'basilisk': EnemyDef('바실리스크', 70, 92, 'bolt'),
  'wraith': EnemyDef(
    '왕국의 망령',
    58,
    115,
    'sweep',
    attackWarning: .75,
    attackRecovery: 3.2,
    attackColor: Color(0xff9cdeff),
    onHitStatus: PlayerStatus.freeze,
  ),
  'drone': EnemyDef(
    '정찰 드론',
    44,
    125,
    'bolt',
    technological: true,
    attackWarning: .85,
    attackRecovery: 4.5,
    attackColor: Color(0xffc9b6ff),
    onHitStatus: PlayerStatus.blind,
  ),
  'viper': EnemyDef(
    '독사',
    34,
    116,
    'pounce',
    lowProfile: true,
    renderHeight: 44,
    onHitStatus: PlayerStatus.poison,
  ),
  'bonehound': EnemyDef(
    '뼈 사냥개',
    46,
    124,
    'pounce',
    attackWarning: .6,
    attackRange: 220,
    attackSpeed: 500,
    attackDamage: 9,
    attackRecovery: 3.4,
    attackColor: Color(0xffffcf8a),
  ),
  'clockwork-spider': EnemyDef(
    '태엽 거미',
    46,
    104,
    'bolt',
    lowProfile: true,
    technological: true,
    renderHeight: 54,
    onHitStatus: PlayerStatus.root,
    attackWarning: .9,
    attackRange: 300,
    attackDamage: 8,
    attackRecovery: 4.5,
    attackColor: Color(0xff7feafa),
  ),
  'crystal-beetle': EnemyDef(
    '수정 갑충',
    60,
    100,
    'sweep',
    lowProfile: true,
    renderHeight: 58,
    attackWarning: .7,
    attackRange: 110,
    attackDamage: 9,
    attackRecovery: 2.3,
    attackColor: Color(0xffd0b0ff),
  ),
};

List<String> biomeEnemies(
  WorldStage stage, {
  bool sand = false,
  bool wooded = false,
  bool ruins = false,
}) => switch (stage) {
  WorldStage.future => const ['cyber', 'gunner', 'drone'],
  WorldStage.foundry => const ['clockwork-spider', 'gunner', 'cyber', 'drone'],
  WorldStage.tombs => const ['wraith', 'skeleton', 'bonehound', 'troll'],
  WorldStage.convergence =>
    wooded
        ? const ['crystal-beetle', 'wolf', 'wraith', 'boar']
        : ruins
        ? const ['crystal-beetle', 'skeleton', 'cyber', 'cultist']
        : const ['crystal-beetle', 'wraith', 'drone', 'goblin'],
  WorldStage.past =>
    wooded
        ? const ['wraith', 'skeleton', 'viper', 'troll']
        : const ['skeleton', 'wraith', 'cultist'],
  WorldStage.sands =>
    ruins
        ? const ['mummy', 'cultist', 'basilisk', 'viper']
        : const ['scorpion', 'viper', 'basilisk', 'scorpion'],
  WorldStage.forest =>
    sand
        ? const ['scorpion', 'basilisk', 'viper']
        : ruins
        ? const ['skeleton', 'cultist']
        : wooded
        ? const ['boar', 'wolf', 'viper', 'goblin']
        : const ['goblin', 'boar', 'wolf'],
};

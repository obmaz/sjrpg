import 'stage_content.dart';

class EnemyDef {
  const EnemyDef(this.name, this.health, this.speed, this.pattern);
  final String name, pattern;
  final double health, speed;
}

const enemyCatalog = {
  'goblin': EnemyDef('고블린', 28, 105, 'chase'),
  'wolf': EnemyDef('늑대', 38, 135, 'pounce'),
  'skeleton': EnemyDef('해골 전사', 52, 105, 'sweep'),
  'cultist': EnemyDef('광신도', 52, 105, 'bolt'),
  'scorpion': EnemyDef('거대 전갈', 52, 105, 'pounce'),
  'mummy': EnemyDef('미라', 52, 105, 'chase'),
  'troll': EnemyDef('트롤', 52, 105, 'sweep'),
  'cyber': EnemyDef('검날 경비병', 52, 105, 'sweep'),
  'gunner': EnemyDef('펄스 사수', 52, 105, 'bolt'),
  'boar': EnemyDef('멧돼지', 46, 145, 'pounce'),
  'basilisk': EnemyDef('바실리스크', 70, 92, 'bolt'),
  'wraith': EnemyDef('왕국의 망령', 58, 115, 'sweep'),
  'drone': EnemyDef('정찰 드론', 44, 125, 'bolt'),
};

List<String> biomeEnemies(
  WorldStage stage, {
  bool sand = false,
  bool wooded = false,
  bool ruins = false,
}) => switch (stage) {
  WorldStage.future => const ['cyber', 'gunner', 'drone'],
  WorldStage.past =>
    wooded
        ? const ['wraith', 'skeleton', 'troll']
        : const ['skeleton', 'wraith', 'cultist'],
  WorldStage.sands =>
    ruins
        ? const ['mummy', 'cultist', 'basilisk']
        : const ['scorpion', 'basilisk', 'scorpion'],
  WorldStage.forest =>
    sand
        ? const ['scorpion', 'basilisk']
        : ruins
        ? const ['skeleton', 'cultist']
        : wooded
        ? const ['boar', 'wolf', 'goblin']
        : const ['goblin', 'boar', 'wolf'],
};

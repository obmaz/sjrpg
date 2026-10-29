import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/combat_distance.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';

void main() {
  test('equipment and skill distances use the same hero-sized step', () {
    expect(CombatDistance.format(100), '2.5걸음');
    expect(
      const SkillPreviewValue('사거리', 100, 140, suffix: '걸음').format(100),
      CombatDistance.format(100),
    );
    expect(
      const SkillPreviewValue(
        '속도',
        100,
        140,
        suffix: '걸음/초',
        digits: 1,
      ).format(100),
      '3.0걸음/초',
    );
  });

  test('DPS divides actual hit damage by real attack interval', () {
    expect(const BasicAttackStats(35, .69).dps, closeTo(50.7246, .0001));
    final p = Progress();
    final stats = p.basicAttackStats();
    expect(stats.damage, p.skillDamage(p.basicSkill));
    expect(
      stats.dps,
      stats.damage * (1 + stats.criticalChance) / stats.interval,
    );
  });
}

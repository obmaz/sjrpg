import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree_layout.dart';

void main() {
  test(
    'Barbarian keeps all thirty original school cells and six level tiers',
    () {
      final p = Progress(heroClass: HeroClass.warrior),
          rows = skillTreeRows(HeroClass.warrior);
      expect(rows.length, 6);
      expect(warriorSchoolLabels, ['함성', '전투 숙련', '전투 기술']);
      expect(rows.expand((row) => row).length, 30);
      expect(warriorTreeIds.length, 30);
      final layout = SkillTreeLayout(p, 320, dense: false, textScale: 1.3);
      expect(layout.contentWidth, 900);
      final expected = {
        'bash': (0, 7),
        'leap': (1, 6),
        'doubleSwing': (1, 8),
        'stun': (2, 7),
        'doubleThrow': (2, 8),
        'leapAttack': (3, 6),
        'concentrate': (3, 7),
        'frenzy': (4, 8),
        'whirlwind': (5, 6),
        'berserk': (5, 7),
        'swordMastery': (0, 3),
        'axeMastery': (0, 4),
        'maceMastery': (0, 5),
        'polearmMastery': (1, 3),
        'throwingMastery': (1, 4),
        'spearMastery': (1, 5),
        'increasedStamina': (2, 3),
        'ironSkin': (3, 5),
        'increasedSpeed': (4, 3),
        'naturalResistance': (5, 5),
        'howl': (0, 0),
        'findPotion': (0, 2),
        'taunt': (1, 0),
        'shout': (1, 1),
        'findItem': (2, 2),
        'battleCry': (3, 0),
        'battleOrders': (4, 1),
        'grimWard': (4, 2),
        'warcry': (5, 0),
        'battleCommand': (5, 1),
      };
      for (final entry in expected.entries) {
        final (row, column) = entry.value;
        final rect = layout.rects[entry.key]!;
        expect(rect.center.dx, (column + .5) * 100, reason: entry.key);
        expect(
          rect.top,
          34 + row * (layout.nodeHeight + layout.rowGap),
          reason: entry.key,
        );
        expect(
          p.skills.firstWhere((s) => s.id == entry.key).requiredLevel,
          warriorSkillTiers[row],
          reason: entry.key,
        );
      }
      for (final extra in layout.rects.keys.where(
        (id) => !warriorTreeIds.contains(id),
      )) {
        expect(layout.rects[extra]!.top, greaterThan(layout.bonusTop!));
      }
    },
  );
  test('local prerequisite arrows never intersect a third skill node', () {
    final p = Progress(heroClass: HeroClass.warrior);
    for (final width in [274.0, 900.0, 1440.0]) {
      final layout = SkillTreeLayout(p, width, dense: false, textScale: 1.3);
      for (final child in p.skills.where(
        (s) => warriorTreeIds.contains(s.id),
      )) {
        for (final parent in child.requires.keys) {
          final points = skillTreeConnectionPoints(layout, parent, child.id);
          final a = layout.rects[parent]!, b = layout.rects[child.id]!;
          expect(
            (a.center.dx / (layout.contentWidth / 3)).floor(),
            (b.center.dx / (layout.contentWidth / 3)).floor(),
          );
          for (var segment = 1; segment < points.length; segment++) {
            for (var step = 0; step <= 30; step++) {
              final point = Offset.lerp(
                points[segment - 1],
                points[segment],
                step / 30,
              )!;
              for (final obstacle in layout.rects.entries) {
                if (obstacle.key == parent || obstacle.key == child.id) {
                  continue;
                }
                expect(
                  obstacle.value.inflate(2).contains(point),
                  false,
                  reason:
                      '$parent -> ${child.id} crosses ${obstacle.key} at $point',
                );
              }
            }
          }
        }
      }
    }
  });
  test('mage retains its five-row layout at the viewport width', () {
    final p = Progress(heroClass: HeroClass.mage),
        layout = SkillTreeLayout(
          Progress(heroClass: HeroClass.mage),
          320,
          dense: false,
          textScale: 1,
        );
    expect(layout.contentWidth, 320);
    expect(layout.bonusTop, null);
    expect(skillTreeRows(p.heroClass).length, 5);
    expect(layout.rects['firebolt']!.center.dx, 320 / 6);
  });
}

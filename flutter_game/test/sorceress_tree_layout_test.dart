import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree_layout.dart';

void main() {
  const positions = {
    'iceBolt': (0, 1),
    'frozenArmor': (0, 2),
    'frostNova': (1, 0),
    'iceBlast': (1, 1),
    'shiverArmor': (2, 2),
    'glacialSpike': (3, 1),
    'blizzard': (4, 0),
    'chillingArmor': (4, 2),
    'frozenOrb': (5, 0),
    'coldMastery': (5, 1),
    'chargedBolt': (0, 4),
    'staticField': (1, 3),
    'telekinesis': (1, 5),
    'nova': (2, 3),
    'lightning': (2, 4),
    'chainLightning': (3, 4),
    'blink': (3, 5),
    'thunderStorm': (4, 3),
    'energyShield': (4, 5),
    'lightningMastery': (5, 4),
    'firebolt': (0, 7),
    'warmth': (0, 8),
    'inferno': (1, 6),
    'blaze': (2, 6),
    'fireball': (2, 7),
    'firewall': (3, 6),
    'enchant': (3, 8),
    'meteor': (4, 7),
    'fireMastery': (5, 7),
    'hydra': (5, 8),
  };
  test('all30 Sorceress icons retain original SkillDesc tier and column', () {
    final rows = skillTreeRows(HeroClass.mage);
    expect(rows.length, 6);
    expect(mageTreeIds, positions.keys.toSet());
    for (var tier = 0; tier < rows.length; tier++) {
      for (final slot in rows[tier]) {
        expect(
          (tier, slot.column.toInt()),
          positions[slot.id],
          reason: slot.id,
        );
      }
    }
  });
  test(
    'all schools expose10 skills including every basic attack and rank20',
    () {
      final p = Progress(heroClass: HeroClass.mage);
      expect(skillTreeSchoolLabels(p), ['냉기 주문', '번개 주문', '화염 주문']);
      for (var school = 0; school < 3; school++) {
        final layout = SkillSchoolLayout(
          p,
          school,
          280,
          dense: false,
          textScale: 1.3,
        );
        expect(layout.skills.length, 10);
        for (final skill in layout.skills) {
          expect(skill.rankLimit, 20);
          expect(skillTreeSkillVisible(p, skill), isTrue);
          expect(
            skill.requiredLevel,
            [1, 6, 12, 18, 24, 30][positions[skill.id]!.$1],
          );
          final rect = layout.rects[skill.id]!;
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(280));
          expect(rect.width, greaterThanOrEqualTo(44));
        }
      }
      for (final id in ['firebolt', 'iceBolt', 'chargedBolt']) {
        expect(
          skillTreeSkillVisible(p, p.skills.firstWhere((s) => s.id == id)),
          isTrue,
        );
      }
      for (final skill in p.skills.where((s) => !mageTreeIds.contains(s.id))) {
        expect(skillTreeSkillVisible(p, skill), isFalse);
      }
    },
  );
  test(
    'every prerequisite arrow stays in its school and avoids unrelated nodes',
    () {
      final p = Progress(heroClass: HeroClass.mage);
      for (var school = 0; school < 3; school++) {
        final layout = SkillSchoolLayout(
          p,
          school,
          280,
          dense: false,
          textScale: 1.3,
        );
        for (final skill in layout.skills) {
          for (final parent in skill.requires.keys) {
            expect(
              layout.rects.containsKey(parent),
              isTrue,
              reason: '${skill.id}:$parent',
            );
            final points = skillTreeConnectionPoints(layout, parent, skill.id);
            expect(points.first.dy, lessThan(points.last.dy));
            for (final point in points) {
              expect(point.dx, inInclusiveRange(0, 280));
            }
            for (var i = 1; i < points.length; i++) {
              // Sample the actual polyline, rather than its diagonal bounding box.
              for (var step = 0; step <= 20; step++) {
                final point =
                    points[i - 1] + (points[i] - points[i - 1]) * (step / 20);
                for (final node in layout.rects.entries) {
                  if (node.key == parent || node.key == skill.id) continue;
                  expect(
                    node.value.inflate(1).contains(point),
                    isFalse,
                    reason:
                        '$parent -> ${skill.id} crosses ${node.key} at $point',
                  );
                }
              }
            }
          }
        }
      }
    },
  );
}

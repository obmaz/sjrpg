import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final hero in const [HeroClass.mage]) {
    test(
      '$hero prerequisites match adjacent nodes in the immediately preceding visual row',
      () {
        final p = Progress(heroClass: hero);
        final rows = skillTreeRows(hero);
        expect(rows.length, 5);
        final ids = rows.expand((row) => row.map((slot) => slot.id)).toList();
        expect(ids.toSet().length, ids.length);
        expect(
          ids.toSet(),
          p.skills
              .where((s) => !s.basic || s.id == p.defaultBasicId)
              .map((s) => s.id)
              .toSet(),
        );
        final rowOf = {
          for (var row = 0; row < rows.length; row++)
            for (final slot in rows[row]) slot.id: row,
        };
        for (var row = 0; row < rows.length; row++) {
          for (final slot in rows[row]) {
            final skill = p.skills.firstWhere((s) => s.id == slot.id);
            if (row == 0) {
              expect(skill.requires, isEmpty);
              continue;
            }
            expect(
              skill.requires.length,
              row == 1 || skill.mobility ? 1 : 2,
              reason: slot.id,
            );
            final previous = rows[row - 1].map((s) => s.id).toList();
            final parentIndices = <int>[];
            for (final parentId in skill.requires.keys) {
              expect(
                rowOf[parentId],
                row - 1,
                reason: '${slot.id} must not skip a row',
              );
              parentIndices.add(previous.indexOf(parentId));
              final parent = p.skills.firstWhere((s) => s.id == parentId);
              expect(
                parent.requiredLevel,
                lessThanOrEqualTo(skill.requiredLevel),
              );
            }
            if (parentIndices.length == 2) {
              expect(
                (parentIndices.first - parentIndices.last).abs(),
                1,
                reason: '${slot.id} cannot skip a neighbor on the same row',
              );
            }
          }
        }
        for (final extra in p.basicSkills.where(
          (s) => s.id != p.defaultBasicId,
        )) {
          final rootIds = rows.first.map((s) => s.id).toList();
          final parents = extra.requires.keys.map(rootIds.indexOf).toList();
          expect(parents.every((index) => index >= 0), true);
          if (parents.length == 2) {
            expect((parents.first - parents.last).abs(), 1);
          }
        }
      },
    );

    test('$hero all five rows remain learnable through real rank gates', () {
      final p = Progress(heroClass: hero)..gainXp(10000);
      p.skillPoints = 1000;
      for (final row in skillTreeRows(hero)) {
        for (final slot in row) {
          final skill = p.skills.firstWhere((s) => s.id == slot.id);
          for (final parent in skill.requires.entries) {
            final prerequisite = p.skills.firstWhere((s) => s.id == parent.key);
            while (p.rank(parent.key) < parent.value) {
              expect(p.learn(prerequisite), true, reason: '${slot.id} parent');
            }
          }
          if (p.rank(skill.id) == 0) {
            expect(p.learn(skill), true, reason: skill.id);
          }
        }
      }
    });

    for (final dense in [false, true]) {
      for (final width in [274.0, 346.0, 640.0]) {
        test(
          '$hero connectors stay in disjoint local gaps at width$width dense$dense',
          () {
            final p = Progress(heroClass: hero);
            final layout = SkillTreeLayout(
              p,
              width,
              dense: dense,
              textScale: 1.3,
            );
            expect(layout.rowGap, greaterThanOrEqualTo(48));
            final rects = layout.rects, rows = skillTreeRows(hero);
            for (final a in rects.entries) {
              expect(a.value.width, greaterThanOrEqualTo(44 - .00001));
              expect(a.value.left, greaterThanOrEqualTo(0));
              expect(a.value.right, lessThanOrEqualTo(width));
              for (final b in rects.entries) {
                if (a.key != b.key) {
                  expect(a.value.overlaps(b.value), false);
                }
              }
            }
            for (var row = 1; row < rows.length; row++) {
              final groups = <String, List<String>>{};
              for (final slot in rows[row]) {
                final s = p.skills.firstWhere((s) => s.id == slot.id);
                final parents = s.requires.keys.toList()..sort();
                (groups[parents.join(',')] ??= []).add(s.id);
                for (final parent in s.requires.keys) {
                  expect(
                    rects[s.id]!.top - rects[parent]!.bottom,
                    layout.rowGap,
                  );
                }
              }
              final spans = <({double left, double right})>[];
              for (final children in groups.values) {
                final first = p.skills.firstWhere(
                  (s) => s.id == children.first,
                );
                final xs = [
                  ...first.requires.keys,
                  ...children,
                ].map((id) => rects[id]!.center.dx);
                spans.add((
                  left: xs.reduce(math.min),
                  right: xs.reduce(math.max),
                ));
              }
              for (var i = 0; i < spans.length; i++) {
                for (var j = i + 1; j < spans.length; j++) {
                  final overlap =
                      math.min(spans[i].right, spans[j].right) -
                      math.max(spans[i].left, spans[j].left);
                  expect(
                    overlap,
                    lessThanOrEqualTo(.001),
                    reason: 'unrelated groups must not cross in row$row',
                  );
                }
              }
            }
          },
        );
      }
    }
  }

  test(
    'Barbarian matches the original six-tier catalogue and direct prerequisites',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/diablo2_barbarian_113.json',
                ).readAsStringSync(),
              )
              as Map;
      final expected = fixture['skills'] as Map;
      final rows = skillTreeRows(HeroClass.warrior);
      expect(rows.length, 6);
      expect(warriorSkills.map((s) => s.id).toSet(), expected.keys.toSet());
      expect(
        rows.expand((row) => row.map((s) => s.id)).toSet(),
        expected.keys.toSet(),
      );
      for (var row = 0; row < rows.length; row++) {
        for (final slot in rows[row]) {
          final data = expected[slot.id] as Map;
          final skill = warriorSkills.firstWhere((s) => s.id == slot.id);
          // Keep the source fixture in combat/masteries/warcries order;
          // the reference screen displays those three school blocks reversed.
          final sourceColumn = data['column'] as int;
          final displayColumn = (2 - sourceColumn ~/ 3) * 3 + sourceColumn % 3;
          expect(row, data['row'], reason: skill.id);
          expect(slot.column, displayColumn, reason: skill.id);
          expect(skill.requiredLevel, data['level'], reason: skill.id);
          expect(skill.requires, data['requires'], reason: skill.id);
          expect(skill.rankLimit, 20);
        }
      }
      final p = Progress()
        ..level = 100
        ..skillPoints = 1000;
      for (final row in rows) {
        for (final slot in row) {
          final skill = p.skills.firstWhere((s) => s.id == slot.id);
          if (p.rank(skill.id) == 0) {
            expect(p.learn(skill), true, reason: skill.id);
          }
        }
      }
      expect(Progress.fromSave(p.toSave()), isNotNull);
    },
  );

  test(
    'both original parents and the next-rank level gate remain mandatory',
    () {
      for (final id in ['whirlwind', 'warcry']) {
        final p = Progress()
          ..level = 30
          ..skillPoints = 20;
        final skill = p.skills.firstWhere((s) => s.id == id);
        final parents = skill.requires.keys.toList();
        expect(parents.length, 2);
        p.ranks[parents.first] = 1;
        expect(p.canLearn(skill), false);
        p.ranks[parents.last] = 1;
        expect(p.learn(skill), true);
        expect(p.rank(id), 1);
        expect(p.canLearn(skill), false, reason: 'rank2 requires level31');
        final points = p.skillPoints;
        expect(p.learn(skill), false);
        expect(p.skillPoints, points);
        p.level = 31;
        expect(p.learn(skill), true);
        expect(p.rank(id), 2);
      }
    },
  );

  test('shared parent pairs retain independent required ranks', () {
    final p = Progress(heroClass: HeroClass.mage)..gainXp(10000);
    p.ranks.addAll({'cinderReach': 1, 'frozenAegis': 1});
    final phoenix = p.skills.firstWhere((s) => s.id == 'phoenixHeart');
    final reserve = p.skills.firstWhere((s) => s.id == 'glacialReserve');
    expect(p.prerequisitesMet(phoenix), true);
    expect(p.prerequisitesMet(reserve), false);
    final points = p.skillPoints;
    expect(p.learn(reserve), false);
    expect(p.skillPoints, points);
    expect(p.learn(phoenix), true);
    p.ranks['frozenAegis'] = 2;
    expect(p.learn(reserve), true);
  });

  test('older Mage ranks, basic choice and active slots survive unchanged', () {
    for (final hero in const [HeroClass.mage]) {
      final p = Progress(heroClass: hero)..gainXp(10000);
      final id = hero == HeroClass.warrior ? 'crushingBlow' : 'meteor';
      final alternative = hero == HeroClass.warrior ? 'quickCut' : 'iceShard';
      p.ranks[id] = 1;
      p.ranks[alternative] = 1;
      p.selectedBasic = alternative;
      p.selectedSkill = id;
      final saved = p.toSave();
      final restored = Progress.fromSave(saved)!;
      expect(restored.ranks, p.ranks);
      expect(restored.selectedBasic, alternative);
      expect(restored.skillSlots, p.skillSlots);
      final skill = restored.skills.firstWhere((s) => s.id == id);
      expect(restored.prerequisitesMet(skill), false);
      expect(
        restored.learn(skill),
        true,
        reason: 'old learned skills stay upgradeable',
      );
    }
  });
}

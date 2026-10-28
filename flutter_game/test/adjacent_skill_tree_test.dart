import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void train(Progress p, String id, [int rank = 1]) {
    final def = p.skills.firstWhere((s) => s.id == id);
    for (final parent in def.requires.entries) {
      if (p.rank(parent.key) < parent.value) train(p, parent.key, parent.value);
    }
    while (p.rank(id) < rank) {
      expect(p.learn(def), true, reason: id);
    }
  }

  test(
    'Sorceress retains original six-tier source cells and direct ancestor gates',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/diablo2_sorceress_113.json',
                ).readAsStringSync(),
              )
              as Map;
      final expected = fixture['skills'] as Map;
      final p = Progress(heroClass: HeroClass.mage)
        ..level = 100
        ..skillPoints = 1000;
      final rows = skillTreeRows(HeroClass.mage);
      expect(rows.length, 6);
      final ids = rows.expand((row) => row.map((slot) => slot.id)).toList();
      expect(ids.length, 30);
      expect(ids.toSet(), expected.keys.toSet());
      for (var row = 0; row < rows.length; row++) {
        for (final slot in rows[row]) {
          final data = expected[slot.id] as Map;
          final def = p.skills.firstWhere((s) => s.id == slot.id);
          final block = switch (data['school']) {
            'cold' => 0,
            'lightning' => 3,
            'fire' => 6,
            _ => throw StateError('Unknown source school'),
          };
          expect(row, data['row'], reason: def.id);
          expect(slot.column, (data['column'] as num) + block, reason: def.id);
          expect(def.requires, data['requires'], reason: def.id);
          expect(def.requiredLevel, data['level'], reason: def.id);
          expect(def.rankLimit, 20);
          for (final parent in def.requires.keys) {
            final parentData = expected[parent] as Map;
            expect(
              parentData['row'],
              lessThan(row),
              reason: '$parent -> ${def.id}',
            );
            expect(parentData['school'], data['school']);
          }
          train(p, def.id);
        }
      }
      expect(Progress.fromSave(p.toSave()), isNotNull);
    },
  );

  for (final dense in [false, true]) {
    for (final width in [274.0, 346.0, 640.0]) {
      test(
        'Sorceress original long prerequisites avoid every other node at width$width dense$dense',
        () {
          final p = Progress(heroClass: HeroClass.mage);
          final layout = SkillTreeLayout(
            p,
            width,
            dense: dense,
            textScale: 1.3,
          );
          expect(layout.contentWidth, greaterThanOrEqualTo(900));
          expect(layout.rowGap, greaterThanOrEqualTo(48));
          expect(layout.rects.length, 30);
          for (final a in layout.rects.entries) {
            expect(a.value.width, greaterThanOrEqualTo(44));
            expect(a.value.left, greaterThanOrEqualTo(0));
            expect(a.value.right, lessThanOrEqualTo(layout.contentWidth));
            for (final b in layout.rects.entries) {
              if (a.key != b.key) expect(a.value.overlaps(b.value), false);
            }
            final def = p.skills.firstWhere((s) => s.id == a.key);
            for (final parent in def.requires.keys) {
              expect(layout.rects[parent]!.bottom, lessThan(a.value.top));
              final points = skillTreeConnectionPoints(layout, parent, def.id);
              for (var i = 1; i < points.length; i++) {
                for (var step = 0; step <= 20; step++) {
                  final point =
                      points[i - 1] + (points[i] - points[i - 1]) * (step / 20);
                  for (final other in layout.rects.entries) {
                    if (other.key == parent || other.key == def.id) continue;
                    expect(
                      other.value.inflate(1).contains(point),
                      false,
                      reason: '$parent -> ${def.id} crosses ${other.key}',
                    );
                  }
                }
              }
            }
          }
        },
      );
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

  test(
    'Sorceress shared parents never bypass each other missing direct parent',
    () {
      final p = Progress(heroClass: HeroClass.mage)
        ..level = 100
        ..skillPoints = 1000;
      train(p, 'fireball');
      final enchant = p.skills.firstWhere((s) => s.id == 'enchant');
      final meteor = p.skills.firstWhere((s) => s.id == 'meteor');
      expect(p.prerequisitesMet(enchant), false);
      expect(p.prerequisitesMet(meteor), false);
      final points = p.skillPoints;
      expect(p.learn(enchant), false);
      expect(p.learn(meteor), false);
      expect(p.skillPoints, points);
      train(p, 'warmth');
      expect(p.learn(enchant), true);
      expect(p.learn(meteor), false);
      train(p, 'firewall');
      expect(p.learn(meteor), true);
    },
  );

  test(
    'new Mage ranks, basics and slots round-trip while incompatible old trees are rejected',
    () {
      final p = Progress(heroClass: HeroClass.mage)
        ..level = 100
        ..skillPoints = 1000;
      train(p, 'meteor', 2);
      train(p, 'iceBolt', 3);
      expect(p.selectBasic('iceBolt'), true);
      expect(p.selectSkill('meteor'), true);
      final saved = p.toSave(), restored = Progress.fromSave(p.toSave())!;
      expect(restored.ranks, p.ranks);
      expect(restored.selectedBasic, 'iceBolt');
      expect(restored.skillSlots, p.skillSlots);
      expect(
        restored.learn(restored.skills.firstWhere((s) => s.id == 'meteor')),
        true,
      );
      final old = Map<String, dynamic>.from(saved)
        ..remove('sorceressTreeVersion');
      expect(Progress.fromSave(old), isNull);
      final broken = jsonDecode(jsonEncode(saved)) as Map<String, dynamic>;
      (broken['ranks'] as Map).remove('firewall');
      expect(
        Progress.fromSave(broken),
        isNull,
        reason: 'new saves cannot retain orphaned learned skills',
      );
    },
  );
}

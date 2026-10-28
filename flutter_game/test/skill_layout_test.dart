import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree.dart';
import 'package:guardian_new/skill_tree_layout.dart';
import 'support/test_game.dart';

void main() {
  for (final hero in HeroClass.values) {
    for (final size in [
      const Size(300, 450),
      const Size(370, 580),
      const Size(640, 90),
    ]) {
      testWidgets(
        '$hero school tabs keep every node inside width and separate at $size',
        (tester) async {
          final s = Adventure(GameArt(), heroClass: hero)..start(TestGame());
          s.pause();
          addTearDown(s.dispose);
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: SkillTree(
                      session: s,
                      controller: scroll,
                      focused: null,
                      onFocus: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (
            var school = 0;
            school < skillTreeSchoolLabels(s.progress).length;
            school++
          ) {
            await tester.tap(find.byKey(ValueKey('skill-school-tab-$school')));
            await tester.pumpAndSettle();
            final bounds = {
              for (final skill in s.progress.skills.where(
                (skill) =>
                    skillTreeSkillVisible(s.progress, skill) &&
                    skillTreeSchoolIndex(s.progress, skill.id) == school,
              ))
                skill.id: tester.getRect(
                  find.byKey(ValueKey('skill-node-${skill.id}')),
                ),
            };
            for (final a in bounds.entries) {
              expect(a.value.width, greaterThanOrEqualTo(44));
              expect(a.value.left, greaterThanOrEqualTo(0));
              expect(a.value.right, lessThanOrEqualTo(size.width));
              for (final b in bounds.entries) {
                if (a.key != b.key) {
                  expect(
                    a.value.overlaps(b.value),
                    false,
                    reason: '${a.key}/${b.key}',
                  );
                }
              }
              for (final parent
                  in s.progress.skills
                      .firstWhere((s) => s.id == a.key)
                      .requires
                      .keys) {
                if (bounds.containsKey(parent)) {
                  expect(bounds[parent]!.bottom, lessThan(a.value.top));
                }
              }
            }
            if (size.height == 90) {
              final viewport = tester.getRect(
                find.byKey(const ValueKey('skill-tree-vertical')),
              );
              expect(viewport.height, greaterThanOrEqualTo(44));
              final first = bounds.values.reduce(
                (a, b) => a.top < b.top ? a : b,
              );
              expect(
                first.intersect(viewport).height,
                greaterThanOrEqualTo(44),
              );
            }
            expect(tester.takeException(), null);
          }
          expect(
            find.byKey(const ValueKey('skill-tree-horizontal')),
            findsNothing,
          );
        },
      );
    }
  }
}

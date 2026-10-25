import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree.dart';
import 'support/test_game.dart';

void main() {
  for (final hero in HeroClass.values) {
    for (final size in [
      const Size(300, 450),
      const Size(370, 580),
      const Size(640, 90),
    ]) {
      testWidgets('$hero split and merge nodes remain separate at $size', (
        tester,
      ) async {
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
        final bounds = {
          for (final skill in s.progress.skills)
            skill.id: tester.getRect(
              find.byKey(ValueKey('skill-node-${skill.id}')),
            ),
        };
        for (final a in bounds.entries) {
          expect(a.value.width, greaterThanOrEqualTo(44));
          for (final b in bounds.entries) {
            if (a.key == b.key) {
              continue;
            }
            expect(
              a.value.overlaps(b.value),
              false,
              reason: '${a.key} / ${b.key}',
            );
          }
          final skill = s.progress.skills.firstWhere((s) => s.id == a.key);
          for (final parent in skill.requires.keys) {
            expect(bounds[parent]!.bottom, lessThan(a.value.top));
          }
        }
        expect(tester.takeException(), null);
      });
    }
  }
}

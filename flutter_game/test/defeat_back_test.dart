import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/back_actions.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/main.dart';
import 'support/test_game.dart';

void main() {
  testWidgets(
    'back can leave defeat within the game instead of trapping its popup',
    (tester) async {
      final art = (await tester.runAsync(GameArt.load))!,
          actions = BackActions();
      var menus = 0, restarts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            art: art,
            onRestart: () => restarts++,
            onReturnToMenu: () => menus++,
            backActions: actions,
          ),
        ),
      );
      try {
        for (var i = 0; i < 160; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        final hero =
            tester.widget<BonfireWidget>(find.byType(BonfireWidget)).player!
                as Guardian;
        expect(hero.session.ready, true);
        inCombatField(hero.session);
        hero.invulnerable = 0;
        hero.session.hurtHero(100000);
        await tester.pump();
        expect(find.text('쓰러진 수호자'), findsOneWidget);
        actions.dispatch();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        for (final shader in art.materials) {
          shader.dispose();
        }
        for (final image in art.images.values) {
          image.dispose();
        }
      }
      expect(menus, 1);
      expect(restarts, 0, reason: 'back must not clear the saved checkpoint');
      expect(tester.takeException(), null);
    },
  );
}

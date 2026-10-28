import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/back_actions.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/main.dart';
import 'support/test_game.dart';

void main() {
  for (final storageFails in [false, true]) {
    testWidgets(
      'death is committed once before retry, storagefails=$storageFails',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 420));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final art = (await tester.runAsync(GameArt.load))!;
        String? saved;
        var failing = false, retries = 0, menus = 0;
        final back = BackActions();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            ),
            home: GamePage(
              art: art,
              onRestart: () {},
              onReturnToMenu: () => menus++,
              backActions: back,
              onRetryCheckpoint: () => retries++,
              readCheckpoint: () => saved,
              writeCheckpoint: (value) {
                if (failing) return false;
                saved = value;
                return true;
              },
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
          final h =
                  tester
                          .widget<BonfireWidget>(find.byType(BonfireWidget))
                          .player!
                      as Guardian,
              s = h.session;
          expect(s.ready, true);
          inCombatField(s);
          s.progress.gold = 1000;
          failing = storageFails;
          h.invulnerable = 0;
          s.hurtHero(1000000, periodic: true);
          await tester.pump();
          expect(s.defeated, true);
          expect(s.deathLoss, isNotNull);
          final gold = s.progress.gold, serial = s.deathLoss!.weaponSerial;
          if (storageFails) {
            expect(find.text('체크포인트 재도전'), findsNothing);
            back.dispatch();
            await tester.pump();
            expect(
              menus,
              0,
              reason: 'failed death save cannot restore an old run',
            );
            failing = false;
            await tester.pump(const Duration(seconds: 6));
            await tester.pump();
          }
          final paid = GameCheckpoint.decode(saved)!;
          expect(paid.revival, true);
          expect(paid.progress.gold, gold);
          expect(paid.progress.inventory.any((g) => g.serial == serial), false);
          s.refresh();
          await tester.pump();
          expect(s.progress.gold, gold);
          expect(find.text('체크포인트 재도전'), findsOneWidget);
          await tester.tap(find.text('체크포인트 재도전'));
          await tester.pump();
          expect(retries, 1);
          expect(tester.takeException(), null);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          art.dispose();
        }
      },
    );
  }
}

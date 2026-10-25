import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_panels.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in const [Size(320, 420), Size(390, 844), Size(844, 390)]) {
    for (final path in [null, TimePath.past, TimePath.future]) {
      testWidgets(
        'next commission stays visible without scrolling at $size for $path',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final stage = path == null ? WorldStage.forest : WorldStage.sands;
          final s = Adventure(GameArt(), stage: stage);
          s.start(TestGame());
          s.pause();
          addTearDown(s.dispose);
          s.timePath = path;
          s.cleansedSites.addAll(
            path == null
                ? questSites.map((q) => q.id)
                : timeCommissions.where((q) => q.path == path).map((q) => q.id),
          );
          s.progress.bossDefeated = true;
          s.progress.kills = stage.killGoal;
          s.won = true;
          var close = 0;
          GameCheckpoint? next;
          await tester.pumpWidget(
            MaterialApp(
              home: AdventurePanel(
                session: s,
                name: 'victory',
                onClose: () => close++,
                onRestart: () {},
                onAdvance: () => next = GameCheckpoint.advance(s),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final target = find.text(
            path == null
                ? '제2장 의뢰 받기'
                : path == TimePath.past
                ? '태초의 왕국으로'
                : '네온의 심연으로',
          );
          expect(target, findsOneWidget);
          final initial = tester.getRect(target);
          expect(initial.bottom, lessThan(size.height - 12));
          expect(initial.top, greaterThan(0));
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(next!.data['stage'], path == null ? 'sands' : path.name);
          expect(close, 0);
          final explore = find.text('계속 탐험하기');
          await tester.scrollUntilVisible(
            explore,
            80,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(target), initial);
          next = null;
          await tester.tap(explore);
          await tester.pumpAndSettle();
          expect(next, null);
          expect(close, 1);
          expect(s.won, false);
          expect(tester.takeException(), null);
        },
      );
    }
  }
  for (final stage in [WorldStage.past, WorldStage.future]) {
    testWidgets(
      '$stage ending keeps exploration and does not offer a nonexistent chapter',
      (tester) async {
        final s = Adventure(GameArt(), stage: stage);
        s.start(TestGame());
        s.pause();
        addTearDown(s.dispose);
        s.cleansedSites.addAll(s.world.sites.map((q) => q.id));
        s.progress.bossDefeated = true;
        s.won = true;
        var close = 0, advances = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: AdventurePanel(
              session: s,
              name: 'victory',
              onClose: () => close++,
              onRestart: () {},
              onAdvance: () => advances++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('계속 탐험하기'), findsOneWidget);
        await tester.tap(find.text('계속 탐험하기'));
        await tester.pumpAndSettle();
        expect(close, 1);
        expect(advances, 0);
        expect(s.won, false);
        expect(tester.takeException(), null);
      },
    );
  }
  testWidgets(
    'large currency and timer fit one HUD row without a resource-like kill number',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final art = await tester.runAsync(() async {
        final loader = FontLoader('Guardian')
          ..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'));
        await loader.load();
        return GameArt.load();
      });
      final s = Adventure(art!);
      s.start(TestGame());
      addTearDown(s.dispose);
      s.progress.level = 31;
      s.progress.gold = 1234567;
      s.progress.kills = 820;
      s.elapsed = 59999;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Guardian'),
          home: Scaffold(body: GameHud(s)),
        ),
      );
      await tester.pumpAndSettle();
      final gold = find.text('1234567'), time = find.text('999:59');
      expect(gold, findsOneWidget);
      expect(time, findsOneWidget);
      expect(
        tester.getRect(gold).center.dy,
        closeTo(tester.getRect(time).center.dy, .01),
      );
      expect(tester.getRect(time).bottom, lessThan(105));
      expect(find.text('820'), findsNothing);
      expect(tester.takeException(), null);
    },
  );
}

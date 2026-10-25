import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_panels.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in const [Size(320, 420), Size(390, 844), Size(844, 390)]) {
    testWidgets(
      'both initial commissions can be reached and choice persists at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = Adventure(GameArt(), stage: WorldStage.sands);
        s.start(TestGame());
        s.pause();
        addTearDown(s.dispose);
        var commits = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: AdventurePanel(
              session: s,
              name: 'journal',
              onClose: () {},
              onRestart: () {},
              onCheckpoint: () => commits++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final close = find.text('모험 계속하기');
        final closeRect = tester.getRect(close);
        for (final name in ['모래에 묻힌 어제 수락', '아직 오지 않은 신호 수락']) {
          final target = find.text(name);
          await tester.scrollUntilVisible(
            target,
            100,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(target).bottom, lessThan(closeRect.top));
          expect(tester.getRect(close), closeRect);
        }
        await tester.tap(find.text('아직 오지 않은 신호 수락'));
        await tester.pumpAndSettle();
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          0,
          reason:
              'the newly accepted first commission starts at the top after leaving the choices',
        );
        expect(s.timePath, TimePath.future);
        expect(s.acceptedCommission, 'future-1');
        expect(commits, 1);
        expect(find.text('모래에 묻힌 어제 수락'), findsNothing);
        expect(s.acceptCommission(timeCommissions.first), false);
        expect(
          GameCheckpoint.decode(
            GameCheckpoint.capture(s)!.encode(),
          )!.data['timePath'],
          'future',
        );
        expect(tester.takeException(), null);
      },
    );
  }
  for (final size in const [Size(320, 420), Size(390, 844), Size(844, 390)]) {
    for (final path in TimePath.values) {
      testWidgets('$path keeps the next commission above history at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = Adventure(GameArt(), stage: WorldStage.sands)
          ..start(TestGame());
        s.pause();
        s.timePath = path;
        addTearDown(s.dispose);
        final quests = timeCommissions.where((q) => q.path == path).toList();
        s.cleansedSites.add(quests.first.id);
        for (var step = 1; step < 4; step++) {
          final quest = quests[step];
          await tester.pumpWidget(
            MaterialApp(
              home: AdventurePanel(
                key: ValueKey('$path-$step'),
                session: s,
                name: 'journal',
                onClose: () {},
                onRestart: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          final accept = find.text('${quest.title} 수락');
          final footer = tester.getRect(find.text('모험 계속하기'));
          expect(tester.getRect(accept).top, greaterThan(0));
          expect(tester.getRect(accept).bottom, lessThan(footer.top));
          expect(
            tester.getRect(find.text('${step + 1}. ${quest.title}')).top,
            lessThan(tester.getRect(find.text('1. ${quests.first.title}')).top),
          );
          final semantics = tester.ensureSemantics();
          await tester.tap(accept);
          await tester.pumpAndSettle();
          expect(s.acceptedCommission, quest.id);
          expect(find.text('진행 중 의뢰'), findsOneWidget);
          final history = find.text('1. ${quests.first.title}');
          await tester.ensureVisible(history);
          await tester.pumpAndSettle();
          if (find.text(quests.first.story).evaluate().isEmpty) {
            await tester.tap(history);
            await tester.pumpAndSettle();
          }
          expect(find.text(quests.first.story), findsOneWidget);
          expect(tester.takeException(), null);
          semantics.dispose();
          s.cleansedSites.add(quest.id);
          s.acceptedCommission = null;
        }
      });
    }
  }
}

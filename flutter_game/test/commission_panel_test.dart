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
    for (final path in TimePath.values) {
      testWidgets(
        '$path starts through its nearby NPC, not the journal, at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final s = Adventure(GameArt(), stage: WorldStage.sands)
            ..start(TestGame());
          s.pause();
          addTearDown(s.dispose);
          var commits = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: AdventurePanel(
                key: const ValueKey('journal'),
                session: s,
                name: 'journal',
                onClose: () {},
                onRestart: () {},
                onCheckpoint: () => commits++,
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final q in timeCommissions.where((q) => q.step == 0)) {
            expect(find.text('${q.title} 수락'), findsNothing);
          }
          expect(find.textContaining('의뢰인을 찾아 대화하세요'), findsOneWidget);
          expect(s.timePath, null);
          final giver = timeQuestGivers.firstWhere((g) => g.path == path);
          final giverAt = s.world.questGiverAt(path);
          s.hero.position.setValues(giverAt.dx - 14, giverAt.dy - 12);
          await tester.pumpWidget(
            MaterialApp(
              home: AdventurePanel(
                key: ValueKey(path),
                session: s,
                name: 'talk',
                offeredPath: path,
                onClose: () {},
                onRestart: () {},
                onCheckpoint: () => commits++,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final own = timeCommissions.firstWhere((q) => q.path == path);
          final other = timeCommissions.firstWhere((q) => q.path != path);
          expect(find.text('${other.title} 수락'), findsNothing);
          final accept = find.text('${own.title} 수락');
          final footer = tester.getRect(find.text('모험 계속하기'));
          await tester.scrollUntilVisible(
            accept,
            80,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(accept).bottom, lessThan(footer.top));
          await tester.tap(accept);
          await tester.pumpAndSettle();
          expect(s.timePath, path);
          expect(s.world.stage, WorldStage.sands);
          expect(s.acceptedCommission, own.id);
          expect(commits, 1);
          final saved = GameCheckpoint.decode(
            GameCheckpoint.capture(s)!.encode(),
          )!;
          expect(saved.data['timePath'], path.name);
          expect(saved.data['stage'], 'sands');
          final wrong = timeQuestGivers.firstWhere((g) => g.path != path);
          final wrongAt = s.world.questGiverAt(wrong.path);
          s.hero.position.setValues(wrongAt.dx - 14, wrongAt.dy - 12);
          await tester.pumpWidget(
            MaterialApp(
              home: AdventurePanel(
                key: const ValueKey('wrong'),
                session: s,
                name: 'talk',
                offeredPath: wrong.path,
                onClose: () {},
                onRestart: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining('이미 ${giver.name}의 의뢰를 시작했습니다'),
            findsOneWidget,
          );
          expect(find.text('${other.title} 수락'), findsNothing);
          expect(s.acceptCommission(other), false);
          expect(tester.takeException(), null);
        },
      );
    }
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

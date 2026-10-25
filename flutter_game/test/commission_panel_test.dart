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
}

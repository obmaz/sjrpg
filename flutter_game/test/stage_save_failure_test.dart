import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_panels.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in const [Size(320, 420), Size(390, 844), Size(844, 390)]) {
    testWidgets(
      'failed chapter save stays visible with an enabled retry at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = Adventure(GameArt())..start(TestGame());
        addTearDown(session.dispose);
        session.cleansedSites.addAll(
          session.world.sites.map((site) => site.id),
        );
        session.progress.bossDefeated = true;
        session.saveFailed = true;
        session.pause();
        var attempts = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdventurePanel(
                session: session,
                name: 'journal',
                onClose: () {},
                onRestart: () {},
                onAdvance: () => attempts++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final warning = find.text('진행을 저장하지 못했습니다. 공간을 확인한 뒤 다시 눌러 주세요.');
        final retry = find.text('제2장 의뢰 받기');
        expect(warning, findsOneWidget);
        expect(retry, findsOneWidget);
        final warningBounds = tester.getRect(warning),
            retryBounds = tester.getRect(retry);
        expect(warningBounds.top, greaterThan(0));
        expect(warningBounds.bottom, lessThan(retryBounds.top));
        expect(retryBounds.bottom, lessThan(size.height - 12));
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(warning), warningBounds);
        expect(tester.getRect(retry), retryBounds);
        await tester.tap(retry);
        expect(
          attempts,
          1,
          reason: 'a temporary storage failure must not disable retry',
        );
        expect(tester.takeException(), null);
      },
    );
  }
}

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/main.dart';

void main() {
  testWidgets('backgrounding preserves an open panel and keeps combat paused', (
    tester,
  ) async {
    final art = (await tester.runAsync(GameArt.load))!;
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(art: art, onRestart: () {}),
      ),
    );
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
    }
    final s =
        (tester.widget<BonfireWidget>(find.byType(BonfireWidget)).player!
                as Guardian)
            .session;
    final dynamic page = tester.state(find.byType(GamePage));
    for (final panel in ['settings', 'bag']) {
      page.open(panel);
      await tester.pump();
      final time = s.elapsed;
      page.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump();
      expect(page.panel, panel);
      expect(s.paused, true);
      await tester.pump(const Duration(seconds: 1));
      expect(s.elapsed, time);
      page.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(s.paused, true);
      page.close();
      await tester.pump();
      expect(s.active, true);
    }
    page.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    expect(page.panel, 'pause');
    expect(s.paused, true);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

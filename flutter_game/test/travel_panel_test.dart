import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/travel_panel.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in const [Size(320, 420), Size(390, 844), Size(844, 390)]) {
    testWidgets('well destinations use one tap and a pinned footer at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      for (final id in ['hub', 'roots', 'moon', 'sun']) {
        s.travelJournal.discover(WorldStage.forest, id);
      }
      s.pause();
      final trips = <(WorldStage, String)>[];
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TravelPanel(
            session: s,
            onClose: () => closed++,
            onTravel: (stage, id) => trips.add((stage, id)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      expect(find.text('우물 워프'), findsOneWidget);
      expect(find.text('현재 위치'), findsOneWidget);
      final destination = find.text('뿌리 우물');
      await tester.scrollUntilVisible(
        destination,
        70,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final footerBefore = tester.getRect(find.text('모험 계속하기'));
      expect(tester.getRect(destination).bottom, lessThan(footerBefore.top));
      await tester.tap(destination);
      expect(trips, [(WorldStage.forest, 'roots')]);
      expect(closed, 0);
      expect(tester.getRect(find.text('모험 계속하기')), footerBefore);
      await tester.tap(find.text('모험 계속하기'));
      expect(closed, 1);
      expect(tester.takeException(), null);
    });
  }
}

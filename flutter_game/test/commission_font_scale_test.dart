import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_panels.dart';
import 'package:guardian_new/interface_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Guardian',
    )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'))).load();
    await prepareInterfaceArtwork();
  });
  for (final size in const [Size(320, 420), Size(390, 844), Size(844, 390)]) {
    for (final path in TimePath.values) {
      testWidgets('first commission fits Guardian at $size / 1.3 / $path', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = Adventure(GameArt(), stage: WorldStage.sands)
          ..start(TestGame())
          ..pause();
        addTearDown(s.dispose);
        final at = s.world.questGiverAt(path);
        s.hero.position.setValues(at.dx - 14, at.dy - 12);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Guardian'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: AdventurePanel(
                session: s,
                name: 'talk',
                offeredPath: path,
                onClose: () {},
                onRestart: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final quest = timeCommissions.firstWhere((quest) => quest.path == path);
        final accept = find.bySemanticsLabel('${quest.title} 수락');
        await tester.scrollUntilVisible(
          accept,
          80,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(accept).bottom,
          lessThan(tester.getRect(find.bySemanticsLabel('모험 계속하기')).top),
        );
        await tester.tap(accept);
        await tester.pumpAndSettle();
        expect(s.timePath, path);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

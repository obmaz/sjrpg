import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/equipment_panel.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/interface_art.dart';
import 'package:guardian_new/panel_controls.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var fontLoaded = false;

  for (final (size, scale) in [
    (const Size(320, 420), 1.3),
    (const Size(390, 844), 1.0),
  ]) {
    testWidgets('bag tabs fit Guardian labels at $size and text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (!fontLoaded) {
        await tester.runAsync(() async {
          final loader = FontLoader('Guardian')
            ..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'));
          await loader.load();
          await prepareInterfaceArtwork();
        });
        fontLoaded = true;
      }
      final session = Adventure(GameArt())..start(TestGame());
      addTearDown(session.dispose);
      session.pause();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Guardian'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: EquipmentPanel(session: session, onClose: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabs = find.byType(GameTabs);
      final labels = tester.widget<GameTabs>(tabs).labels;
      expect(labels, hasLength(6));
      final heights = <double>[];
      for (final label in labels) {
        final text = find.descendant(of: tabs, matching: find.text(label));
        final paragraph = tester.renderObject<RenderParagraph>(text);
        final button = find.ancestor(of: text, matching: find.byType(InkWell));
        final buttonRect = tester.getRect(button);
        final textRect = tester.getRect(text);
        heights.add(buttonRect.height);
        expect(paragraph.text.style?.fontFamily, 'Guardian');
        expect(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width),
          lessThanOrEqualTo(paragraph.size.height + .01),
          reason: '$label must display every line',
        );
        expect(textRect.top, greaterThanOrEqualTo(buttonRect.top + 6));
        expect(textRect.bottom, lessThanOrEqualTo(buttonRect.bottom - 6));
      }
      for (final height in heights) {
        expect(height, heights.first);
      }
      if (scale == 1) expect(heights.first, 48);

      await tester.tap(find.descendant(of: tabs, matching: find.text('방어구')));
      await tester.pumpAndSettle();
      expect(tester.widget<GameTabs>(tabs).selected, labels.indexOf('방어구'));
      final footer = tester.getRect(find.text('모험 계속하기'));
      expect(footer.bottom, lessThan(size.height));
      expect(tester.takeException(), isNull);
    });
  }
}

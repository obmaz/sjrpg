import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/quest_guide.dart';
import 'package:guardian_new/rpg_widgets.dart';

void main() {
  for (final size in const [
    Size(390, 844),
    Size(320, 420),
    Size(600, 320),
    Size(844, 390),
  ]) {
    testWidgets(
      'nearby quest guidance avoids every battle control and opens journal at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
        expect(s.ready, true);
        s.progress.gainXp(8000);
        s.progress.ranks.addAll({
          'whirlwind': 1,
          'frenzy': 1,
          'warcry': 1,
          'seismicSlam': 1,
        });
        s.progress.selectSkill('whirlwind');
        s.progress.selectSkill('frenzy', slot: 1);
        s.progress.selectSkill('warcry', slot: 2);
        s.progress.selectSkill('seismicSlam', slot: 3);
        s.mobs.clear();
        s.hero.position.setValues(
          s.world.elderAt.dx + 50,
          s.world.elderAt.dy + 20,
        );
        s.refresh();
        await tester.pump();
        final card = find.byType(NearbyQuestCard), rect = tester.getRect(card);
        expect(
          Rect.fromLTWH(
            0,
            0,
            size.width,
            size.height,
          ).contains(rect.bottomRight),
          true,
        );
        for (final type in [GameStick, PotionBelt, ActionButton]) {
          final controls = find.byType(type);
          for (var i = 0; i < controls.evaluate().length; i++) {
            expect(
              rect.overlaps(tester.getRect(controls.at(i))),
              false,
              reason: '$type $i overlaps $rect',
            );
          }
        }
        final map = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == '지도 확대',
        );
        final mapRect = tester.getRect(map);
        final buttons = find.byType(ActionButton);
        for (var i = 0; i < buttons.evaluate().length; i++) {
          expect(
            mapRect.overlaps(tester.getRect(buttons.at(i))),
            false,
            reason: 'skill covers minimap',
          );
        }
        expect(
          tester
              .getRect(find.byType(PotionBelt))
              .overlaps(tester.getRect(find.byType(GameStick))),
          false,
        );
        await tester.tap(card);
        await tester.pump();
        expect(s.paused, true);
        expect(find.text('지금 할 일'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}

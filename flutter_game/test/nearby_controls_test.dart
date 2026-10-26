import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/nearby_controls.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/quest_guide.dart';
import 'package:guardian_new/rpg_widgets.dart';

import 'support/test_game.dart';

void besideWell(Adventure session) {
  final site = session.world.sites.first;
  session.hero.position.setValues(site.at.dx - 14, site.at.dy + 45);
  session.mounts.first.at = site.at + const Offset(65, 55);
  session.travelJournal.discover(session.world.stage, site.id);
  session.waveTime = 1000;
  session.lastPackSpawn = session.elapsed;
  session.refresh();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a well offers its quest and adjacent mount independently', () {
    final session = Adventure(GameArt())..start(TestGame());
    addTearDown(session.dispose);
    besideWell(session);
    expect(session.nearbySite, isNotNull);
    expect(session.nearbyQuestGuide?.action, QuestGuideAction.cleanse);
    expect(
      session.nearbyActions,
      containsAll([NearbyAction.mount, NearbyAction.shrine]),
    );
    expect(session.boardNearbyMount(), true);
    expect(session.nearbyActions, [NearbyAction.dismount]);
    expect(session.dismount(), true);
  });

  for (final size in [
    const Size(320, 420),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets(
      'well guide, boarding and warp have separate touch areas at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final art = await tester.runAsync(GameArt.load);
        await tester.pumpWidget(
          MaterialApp(
            home: GamePage(art: art!, onRestart: () {}, onTravel: (_) {}),
          ),
        );
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        final hero =
            tester.widget<BonfireWidget>(find.byType(BonfireWidget)).player!
                as Guardian;
        final session = hero.session;
        besideWell(session);
        await tester.pump();
        final guide = find.byType(NearbyQuestCard);
        final controls = find.byType(NearbyControls);
        final mount = find.widgetWithText(GameAction, '타기');
        final warp = find.widgetWithText(GameAction, '워프');
        expect(guide, findsOneWidget);
        expect(mount, findsOneWidget);
        expect(warp, findsOneWidget);
        expect(tester.getRect(guide).overlaps(tester.getRect(controls)), false);
        expect(
          tester
              .getRect(controls)
              .overlaps(tester.getRect(find.byType(PotionBelt))),
          false,
        );
        expect(
          tester
              .getRect(controls)
              .overlaps(tester.getRect(find.byType(GameStick))),
          false,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(mount);
        await tester.pump();
        expect(session.riding?.def.id, session.mounts.first.def.id);
        expect(find.text('워프'), findsNothing);
        await tester.tap(find.byType(NearbyQuestCard));
        await tester.pump();
        expect(session.riding, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}

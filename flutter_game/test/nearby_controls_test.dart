import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

void besideQuestGiver(Adventure session) {
  final site = session.world.sites.first;
  final npc = session.forestQuests.npcs.firstWhere((npc) => npc.key == 'elin');
  session.hero.position.setValues(npc.at.dx + 50 - 14, npc.at.dy - 12);
  final mount = withOwnedMounts(session).mounts.first;
  mount.at = [const Offset(65, 0), const Offset(0, 65), const Offset(-65, 0)]
      .map((d) => session.hero.body.center + d)
      .firstWhere(
        (at) =>
            !session.world.blocked(
              Rect.fromCenter(
                center: at,
                width: mount.def.bodySize.width,
                height: mount.def.bodySize.height,
              ),
            ) &&
            session.world.clearBoardingLine(session.hero.body.center, at),
      );
  session.travelJournal.discover(session.world.stage, site.id);
  session.waveTime = 1000;
  session.lastPackSpawn = session.elapsed;
  session.refresh();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var fontLoaded = false;
  Finder control(String label) => find.byWidgetPredicate(
    (widget) =>
        widget is GameAction && widget.label == label ||
        widget is GameIconButton && widget.label == label,
  );
  test(
    'an NPC gives the quest while nearby well and mount stay independent',
    () {
      final session = Adventure(GameArt())..start(TestGame());
      addTearDown(session.dispose);
      besideQuestGiver(session);
      expect(session.nearbySite, isNotNull);
      expect(session.nearbyQuestGuide?.action, QuestGuideAction.talk);
      expect(session.nearbyActions, contains(NearbyAction.mount));
      expect(session.nearbyActions, isNot(contains(NearbyAction.shrine)));
      expect(session.boardNearbyMount(), true);
      expect(session.nearbyActions, [NearbyAction.dismount]);
      expect(session.dismount(), true);
    },
  );

  for (final size in [
    const Size(320, 420),
    const Size(390, 844),
    const Size(844, 390),
    const Size(390, 420),
    const Size(568, 320),
  ]) {
    testWidgets(
      'scaled NPC guide and nearby actions preserve battle touch areas at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final art = await tester.runAsync(GameArt.load);
        if (!fontLoaded) {
          await tester.runAsync(() async {
            final font = FontLoader(
              'Guardian',
            )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'));
            await font.load();
          });
          fontLoaded = true;
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Guardian'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
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
        session.progress.gainXp(8000);
        const skills = ['whirlwind', 'frenzy', 'warcry', 'bash'];
        session.progress.ranks.addAll({for (final id in skills) id: 1});
        for (var slot = 0; slot < skills.length; slot++) {
          expect(session.progress.selectSkill(skills[slot], slot: slot), true);
        }
        session.progress.healingPotions = session.progress.energyPotions = 128;
        besideQuestGiver(session);
        await tester.pump();
        final guide = find.byType(NearbyQuestCard);
        final controls = find.byType(NearbyControls);
        final mount = control('타기');
        final warp = control('워프');
        expect(guide, findsOneWidget);
        expect(mount, findsOneWidget);
        expect(warp, findsOneWidget);
        expect(
          tester.getSize(guide).width,
          closeTo(tester.getSize(warp).width, .01),
        );
        expect(tester.getRect(guide).overlaps(tester.getRect(controls)), false);
        expect(
          tester
              .getRect(controls)
              .overlaps(tester.getRect(find.byType(PotionBelt))),
          false,
        );
        final nearbyButtons = find.descendant(
          of: controls,
          matching: find.byWidgetPredicate(
            (w) => w is GameAction || w is GameIconButton,
          ),
        );
        final potions = find.descendant(
          of: find.byType(PotionBelt),
          matching: find.byType(InkWell),
        );
        final targets = [
          tester.getRect(guide),
          for (var i = 0; i < nearbyButtons.evaluate().length; i++)
            tester
                .getRect(nearbyButtons.at(i))
                .intersect(tester.getRect(controls)),
          for (var i = 0; i < potions.evaluate().length; i++)
            tester.getRect(potions.at(i)),
        ];
        final battle = find.byType(ActionButton);
        for (var i = 0; i < battle.evaluate().length; i++) {
          final button = tester.widget<ActionButton>(battle.at(i));
          final center =
              tester.getRect(battle.at(i)).topLeft +
              Offset(button.size / 2, button.size / 2);
          for (final target in targets.where((r) => !r.isEmpty)) {
            final closest = Offset(
              center.dx.clamp(target.left, target.right),
              center.dy.clamp(target.top, target.bottom),
            );
            expect(
              (closest - center).distance,
              greaterThanOrEqualTo(button.size / 2),
              reason:
                  '${button.semanticLabel} is covered by another touch target',
            );
          }
        }
        expect(
          tester
              .getRect(controls)
              .overlaps(tester.getRect(find.byType(GameStick))),
          false,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(mount);
        await tester.pump();
        expect(
          session.riding?.def.id,
          withOwnedMounts(session).mounts.first.def.id,
        );
        expect(control('워프'), findsNothing);
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

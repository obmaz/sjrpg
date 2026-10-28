import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/quest_guide.dart';
import 'package:guardian_new/rpg_widgets.dart';

import 'support/test_game.dart';

void main() {
  testWidgets('focused field controls return keyboard movement to the game', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final art = (await tester.runAsync(GameArt.load))!;
    final seed = inCombatField(Adventure(art))..start(TestGame());
    seed.mobs.clear();
    withOwnedMounts(seed).mounts.first.at = const Offset(6050, 4212);
    final saved = GameCheckpoint.capture(seed)!;
    seed.dispose();
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(art: art, checkpoint: saved, onRestart: () {}),
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
    Future<void> activate(Finder control) async {
      final target = find.descendant(
        of: control,
        matching: find.byType(GestureDetector),
      );
      Focus.of(tester.element(target.first)).requestFocus();
      await tester.pump();
      await tester.tap(control);
      await tester.pump();
    }

    Future<void> move() async {
      inCombatField(hero.session);
      hero.session.riding?.at = hero.body.center;
      final before = hero.position.clone();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      expect(hero.position.x - before.x, greaterThan(15));
    }

    await activate(find.widgetWithText(GameAction, '타기'));
    expect(hero.session.riding, isNotNull);
    await move();
    await activate(find.widgetWithText(GameAction, '내리기'));
    expect(hero.session.riding, isNull);
    await move();
    hero.session.progress.hp = 60;
    hero.session.syncLife();
    final potions = hero.session.progress.healingPotions;
    await activate(
      find
          .descendant(
            of: find.byType(PotionBelt),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(hero.session.progress.healingPotions, potions - 1);
    await move();
    final site = hero.session.world.sites.first;
    hero.position.setValues(site.at.dx - 14, site.at.dy + 45);
    hero.session.waveTime = 1000;
    hero.session.refresh();
    await tester.pump();
    await activate(find.byType(NearbyQuestCard));
    expect(hero.session.cleansedSites, contains(site.id));
    await move();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

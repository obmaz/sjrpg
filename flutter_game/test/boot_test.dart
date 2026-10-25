import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/game_ui.dart';

void main() {
  testWidgets(
    'a zero-delta startup frame leaves the real Bonfire camera finite and the game playable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final art = await tester.runAsync(GameArt.load);
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(art: art!, onRestart: () {}),
        ),
      );
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
      }
      final widget = tester.widget<BonfireWidget>(find.byType(BonfireWidget));
      final hero = widget.player! as Guardian;
      expect(hero.session.ready, true);
      expect(hero.session.game!.camera.position.x.isFinite, true);
      expect(hero.session.game!.camera.position.y.isFinite, true);
      expect(hero.session.elapsed, greaterThan(0));
      expect(hero.session.world.blocked(hero.body), false);
      expect(
        hero.session.mobs
            .where((m) => !m.isDead)
            .any((m) => hero.session.world.blocked(m.body)),
        false,
      );
      expect(find.text('공격'), findsOneWidget);
      final before = hero.position.clone(), strikes = hero.strikes;
      final stick = await tester.startGesture(
        tester.getCenter(find.byType(GameStick)),
        pointer: 1,
      );
      final attack = await tester.startGesture(
        tester.getCenter(
          find.byWidgetPredicate(
            (w) => w is ActionButton && w.semanticLabel == '공격',
          ),
        ),
        pointer: 2,
      );
      await stick.moveBy(const Offset(35, 0));
      for (var i = 0; i < 32; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(hero.session.world.blocked(hero.body), false);
      }
      expect((hero.position - before).length, greaterThan(10));
      expect(hero.strikes, greaterThan(strikes));
      await stick.cancel();
      await tester.pump(const Duration(milliseconds: 16));
      expect(hero.session.attackSources.contains('touch'), true);
      await attack.up();
      await tester.pump();
      expect(hero.session.attackSources.contains('touch'), false);
      hero.dodge();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final camera = hero.session.game!.camera.position;
        expect(camera.x.isFinite && camera.y.isFinite, true);
        expect((camera - (hero.position + hero.size / 2)).length, lessThan(2));
        expect(hero.session.world.blocked(hero.body), false);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

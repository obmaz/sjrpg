import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/game_ui.dart';

void main() {
  for (final viewport in const [Size(390, 844), Size(320, 420)]) {
    testWidgets(
      'startup, touch controls and camera stay playable at ${viewport.width} x ${viewport.height}',
      (tester) async {
        tester.view.physicalSize = viewport;
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
          expect(
            (camera -
                    (hero.position +
                        hero.size / 2 +
                        Vector2(0, viewport.height < 520 ? 36 : 0)))
                .length,
            lessThan(2),
          );
          expect(hero.session.world.blocked(hero.body), false);
        }
        // A spell must not remove a queued actor while its hitbox is still loading.
        final pending = hero.session.spawnEnemy(
          'goblin',
          hero.position.toOffset() + const Offset(-100, 140),
        )!;
        expect(pending.combatReady, false);
        hero.session.hit(pending, 99999, Offset.zero);
        expect(pending.isDead, false);
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        expect(pending.combatReady, true);
        expect(pending.children.whereType<RectangleHitbox>(), isNotEmpty);
        hero.session.hit(pending, 99999, Offset.zero);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

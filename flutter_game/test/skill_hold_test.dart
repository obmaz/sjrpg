import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/encounters.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/main.dart';
import 'support/test_game.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(320, 420)]) {
    testWidgets(
      'real game buttons charge heavy attacks and aim dashes at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final art = (await tester.runAsync(GameArt.load))!;
        final source = Adventure(GameArt())..start(TestGame());
        source.mobs.clear();
        source.hero.position.setValues(6000, 4200);
        source.progress.gainXp(8000);
        source.progress.ranks.addAll({
          'charge': 1,
          'crushingBlow': size.width < 360 ? 5 : 3,
        });
        source.progress.selectSkill('crushingBlow');
        source.progress.selectSkill('charge', slot: 1);
        source.progress.energy = source.progress.maxEnergy;
        source.encounterAreas
          ..clear()
          ..['1:1'] = EncounterArea('1:1', const Offset(6100, 5000), waves: 3);
        final cp = GameCheckpoint.capture(source)!;
        source.dispose();
        await tester.pumpWidget(
          MaterialApp(
            home: GamePage(art: art, checkpoint: cp, onRestart: () {}),
          ),
        );
        for (var i = 0; i < 160; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        final hero =
            tester.widget<BonfireWidget>(find.byType(BonfireWidget)).player!
                as Guardian;
        final s = hero.session;
        expect(s.ready, true);
        s.combatTime = 20;
        Finder action(String name) => find.byWidgetPredicate(
          (w) => w is ActionButton && w.semanticLabel == name,
        );
        final energy = s.progress.energy;
        final hold = await tester.startGesture(
          tester.getCenter(action('집중 강타')),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(hero.aim?.id, 'crushingBlow');
        expect(hero.aim!.heldFor, greaterThan(.5));
        expect(hero.cooldowns['crushingBlow'], isNull);
        expect(s.progress.energy, energy);
        await hold.up();
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          hero.heavyPower,
          greaterThan(
            s.progress.skillDamage(
                  s.progress.skills.firstWhere((d) => d.id == 'crushingBlow'),
                ) *
                1.3,
          ),
        );
        expect(hero.cooldowns['crushingBlow'], greaterThan(0));
        expect(s.progress.energy, energy - 22);
        for (var i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final charge = action('보조 맹렬한 돌진'), before = hero.position.clone();
        final cancel = await tester.startGesture(tester.getCenter(charge));
        await cancel.moveBy(const Offset(35, 0));
        await cancel.cancel();
        await tester.pump();
        expect(hero.chargeTime, 0);
        expect(hero.cooldowns['charge'], isNull);
        final dash = await tester.startGesture(tester.getCenter(charge));
        await dash.moveBy(const Offset(35, 0));
        await dash.up();
        for (var i = 0; i < 35; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(hero.position.x - before.x, greaterThan(300));
        expect((hero.position.y - before.y).abs(), lessThan(2));
        expect(s.world.blocked(hero.body), false);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox.shrink());
        for (final shader in art.materials) {
          shader.dispose();
        }
        for (final image in art.images.values) {
          image.dispose();
        }
      },
    );
  }
}

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/barbarian_combat.dart';
import 'package:guardian_new/encounters.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/main.dart';
import 'support/test_game.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(320, 420)]) {
    testWidgets(
      'real game buttons hold leap aim and cancel manual throwing at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final art = (await tester.runAsync(GameArt.load))!;
        final source = Adventure(GameArt())..start(TestGame());
        source.mobs.clear();
        source.hero.position.setValues(6000, 4200);
        source.progress.level = 100;
        source.progress.skillPoints = 100;
        void learn(String id, int rank) {
          final def = source.progress.skills.firstWhere((v) => v.id == id);
          for (final requirement in def.requires.entries) {
            learn(requirement.key, requirement.value);
          }
          while (source.progress.rank(id) < rank) {
            expect(source.progress.learn(def), true);
          }
        }

        learn('leapAttack', size.width < 360 ? 5 : 3);
        learn('doubleThrow', 1);
        source.progress.selectSkill('leapAttack');
        source.progress.selectSkill('doubleThrow', slot: 1);
        source.hero.bearing = 0;
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
          tester.getCenter(action('도약 공격')),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(hero.aim?.id, 'leapAttack');
        expect(hero.aim!.heldFor, greaterThan(.5));
        expect(hero.cooldowns['leapAttack'], isNull);
        expect(s.progress.energy, energy);
        await hold.up();
        await tester.pump(const Duration(milliseconds: 16));
        expect(hero.barbarianCombat.airborne, true);
        expect(hero.cooldowns['leapAttack'], greaterThan(0));
        expect(s.progress.energy, energy - 12);
        for (var i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final throwing = action('보조 이중 투척'), before = hero.position.clone();
        final cancel = await tester.startGesture(tester.getCenter(throwing));
        await cancel.moveBy(const Offset(35, 0));
        await cancel.cancel();
        await tester.pump();
        expect(hero.barbarianCombat.busy, false);
        expect(hero.cooldowns['doubleThrow'], isNull);
        expect(hero.gameRef.query<BarbarianThrownAxe>(), isEmpty);
        final throwGesture = await tester.startGesture(
          tester.getCenter(throwing),
        );
        await throwGesture.moveBy(const Offset(35, 0));
        await throwGesture.up();
        var furthest = before.x;
        for (var i = 0; i < 35; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final axes = hero.gameRef.query<BarbarianThrownAxe>().toList();
          expect(axes.length, lessThanOrEqualTo(2));
          for (final axe in axes) {
            expect(axe.direction.dx, greaterThan(.99));
            if (axe.position.x > furthest) furthest = axe.position.x;
          }
        }
        expect(furthest - before.x, greaterThan(100));
        expect((hero.position.x - before.x).abs(), lessThan(1));
        expect((hero.position.y - before.y).abs(), lessThan(1));
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

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/encounters.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/main.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Guardian',
    )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'))).load();
  });
  testWidgets(
    'mobile resource cue dims the actual skill, keeps rejection feedback, and clears after a potion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final art = (await tester.runAsync(GameArt.load))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        for (final shader in art.materials) {
          shader.dispose();
        }
        for (final image in art.images.values) {
          image.dispose();
        }
      });
      final source = inCombatField(Adventure(GameArt()))..start(TestGame());
      source.mobs.clear();
      source.progress.ranks['bash'] = 1;
      expect(source.progress.selectSkill('bash'), true);
      source.progress.energy = 60;
      source.encounterAreas
        ..clear()
        ..['1:1'] = EncounterArea('1:1', const Offset(6100, 5000), waves: 3);
      final checkpoint = GameCheckpoint.capture(source)!;
      source.dispose();
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Guardian'),
          home: RepaintBoundary(
            key: boundaryKey,
            child: GamePage(art: art, checkpoint: checkpoint, onRestart: () {}),
          ),
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
      final skill = s.progress.skillAt(0)!;
      final cost = s.progress.skillCost(skill);
      final action = find.byWidgetPredicate(
        (w) => w is ActionButton && w.semanticLabel == skill.name,
      );
      final attack = find.byWidgetPredicate(
        (w) => w is ActionButton && w.semanticLabel == '공격',
      );
      final dodge = find.byWidgetPredicate(
        (w) => w is ActionButton && w.semanticLabel == '회피',
      );
      final semantics = tester.ensureSemantics();
      try {
        Future<Uint8List> capture(String phase) async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final result = Uint8List.fromList(data.buffer.asUint8List());
            final directory = Platform.environment['RESOURCE_CUE_PROOF_DIR'];
            if (directory != null) {
              await Directory(directory).create(recursive: true);
              final png = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File(
                '$directory/resource-cue-$phase.png',
              ).writeAsBytes(png.buffer.asUint8List());
            }
            image.dispose();
            return result;
          }))!;
        }

        List<int> pixels(Uint8List image, Finder target) {
          final rect = tester.getRect(target).deflate(6);
          return [
            for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++)
              for (var x = rect.left.ceil(); x < rect.right.floor(); x++)
                for (var channel = 0; channel < 3; channel++)
                  image[(y * 390 + x) * 4 + channel],
          ];
        }

        final ready = await capture('ready');
        expect(tester.widget<ActionButton>(action).insufficientResource, false);
        s.progress.energy = cost - 1;
        s.refresh();
        await tester.pump(const Duration(milliseconds: 16));
        final short = await capture('short');
        expect(tester.widget<ActionButton>(action).insufficientResource, true);
        final readyPixels = pixels(ready, action),
            shortPixels = pixels(short, action);
        final readyLight = readyPixels.reduce((a, b) => a + b);
        final shortLight = shortPixels.reduce((a, b) => a + b);
        expect(shortLight / readyLight, inExclusiveRange(.5, .75));
        expect(shortPixels.toSet().length, greaterThan(100));
        expect(pixels(short, attack), pixels(ready, attack));
        expect(pixels(short, dodge), pixels(ready, dodge));
        expect(find.bySemanticsLabel(skill.name), findsOneWidget);

        await tester.tap(action);
        await tester.pump(const Duration(milliseconds: 90));
        expect(s.progress.energy, cost - 1);
        expect(hero.cooldowns[skill.id], isNull);
        expect(s.texts.any((text) => text.label == '분노 부족'), true);

        final potions = s.progress.energyPotions;
        await tester.tap(find.bySemanticsLabel('분노 물약 $potions개'));
        await tester.pump(const Duration(milliseconds: 90));
        expect(s.progress.energyPotions, potions - 1);
        expect(s.progress.energy, greaterThanOrEqualTo(cost));
        expect(tester.widget<ActionButton>(action).insufficientResource, false);
        final restored = await capture('restored');
        expect(pixels(restored, action), readyPixels);

        final energy = s.progress.energy;
        await tester.tap(action);
        await tester.pump(const Duration(milliseconds: 16));
        expect(s.progress.energy, energy - cost);
        expect(hero.cooldowns[skill.id], greaterThan(0));
        expect(tester.takeException(), null);
      } finally {
        semantics.dispose();
      }
    },
  );
}

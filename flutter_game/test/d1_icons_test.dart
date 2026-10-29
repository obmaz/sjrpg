import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/barbarian_icon_art.dart';
import 'package:guardian_new/d1_icon_art.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/sorceress_icon_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all sixty class skills and thirty-two shared symbols have distinct fitted D1 artwork',
    () async {
      final art = await GameArt.loadMenu();
      addTearDown(art.dispose);
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.mage);
      expect(art.images.containsKey(D1IconArt.mageKey), isTrue);
      expect(art.images.containsKey(D1IconArt.warriorKey), isFalse);
      expect(art.images.containsKey(SorceressIconArt.imageKey), isFalse);
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      expect(art.images.containsKey(D1IconArt.warriorKey), isTrue);
      expect(art.images.containsKey(BarbarianIconArt.imageKey), isFalse);
      for (final (first, count) in [(100, 30), (200, 30), (0, 32)]) {
        final fingerprints = <int>{};
        for (var i = 0; i < count; i++) {
          final r = ui.PictureRecorder(), c = ui.Canvas(r);
          expect(
            D1IconArt.draw(
              c,
              art,
              first + i,
              const Rect.fromLTWH(4, 4, 48, 48),
            ),
            isTrue,
          );
          final picture = r.endRecording(),
              image = await picture.toImage(56, 56);
          picture.dispose();
          final pixels = (await image.toByteData())!.buffer.asUint8List();
          expect(pixels.where((v) => v > 0).length, greaterThan(100));
          var left = 56, top = 56, right = 0, bottom = 0;
          for (var y = 0; y < 56; y++) {
            for (var x = 0; x < 56; x++) {
              if (pixels[(y * 56 + x) * 4 + 3] > 128) {
                if (x < left) left = x;
                if (x > right) right = x;
                if (y < top) top = y;
                if (y > bottom) bottom = y;
              }
              if (x < 4 || x >= 52 || y < 4 || y >= 52) {
                expect(pixels[(y * 56 + x) * 4 + 3], 0);
              }
            }
          }
          expect(
            (left + right) / 2,
            closeTo(27.5, .8),
            reason: 'icon ${first + i} horizontal center',
          );
          expect(
            (top + bottom) / 2,
            closeTo(27.5, .8),
            reason: 'icon ${first + i} vertical center',
          );
          expect(
            right - left,
            greaterThanOrEqualTo(45),
            reason: 'icon ${first + i} complete rim width',
          );
          expect(
            bottom - top,
            greaterThanOrEqualTo(45),
            reason: 'icon ${first + i} complete rim height',
          );
          fingerprints.add(Object.hashAll(pixels));
          image.dispose();
        }
        expect(fingerprints.length, count);
      }
    },
  );
  testWidgets(
    'generated skill and dodge faces occupy the button frame without nested rims',
    (tester) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawCircle(const Offset(4, 4), 4, Paint()..color = Colors.white);
      final picture = recorder.endRecording();
      final image = await picture.toImage(8, 8);
      picture.dispose();
      final art = GameArt()..images[D1IconArt.interfaceKey] = image;
      addTearDown(art.dispose);
      for (final effect in [34, 35, 36, 7, null]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: ActionButton(
                art: art,
                sprite: 'roundEmpty',
                label: '',
                semanticLabel: 'test action',
                size: 80,
                showLabel: false,
                effect: effect,
                glyphIndex: effect == null ? MobileGlyph.dodge : null,
                onTap: () {},
              ),
            ),
          ),
        );
        final paint = find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              (w.painter is EffectIconPainter ||
                  w.painter is DodgeActionPainter),
        );
        expect(paint, findsOneWidget);
        expect(tester.getSize(paint), const Size.square(80));
        expect(
          tester.getCenter(paint),
          tester.getCenter(find.byType(ActionButton)),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'round identity and compact positive/negative status badges fit narrow scaled HUD',
    (tester) async {
      tester.view.physicalSize = const Size(320, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final art = GameArt();
      final s = Adventure(art)..start(TestGame());
      addTearDown(s.dispose);
      addTearDown(art.dispose);
      s.progress.level = 100;
      for (final id in ['shout', 'battleOrders', 'battleCommand']) {
        s.progress.ranks[id] = 1;
        expect(
          s.barbarianUtilities.activate(
            s.progress.skills.firstWhere((x) => x.id == id),
          ),
          isTrue,
        );
      }
      s.hero.frenzyTime = 4;
      s.hero.sprintTime = 2;
      s.afflictions.apply(PlayerStatus.poison);
      s.afflictions.apply(PlayerStatus.blind);
      s.afflictions.apply(PlayerStatus.attackSlow);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 520),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(body: GameHud(s)),
          ),
        ),
      );
      final portrait = tester.getSize(
        find.byKey(const ValueKey('hud-portrait')),
      );
      expect(portrait.width, portrait.height);
      expect(find.bySemanticsLabel(RegExp('전투 명령.*초')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('중독.*초')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}

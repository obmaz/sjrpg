import 'dart:io';
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/rpg_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GameArt? artwork;
  Future<GameArt> art(WidgetTester tester, HeroClass type) async {
    return (await tester.runAsync(() async {
      if (artwork == null) {
        final font = FontLoader('Guardian')
          ..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'));
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        artwork = await GameArt.load();
      }
      return artwork!;
    }))!;
  }

  tearDownAll(() => artwork?.dispose());
  for (final type in HeroClass.values) {
    for (final size in const [
      Size(390, 844),
      Size(320, 420),
      Size(320, 600),
      Size(844, 390),
      Size(915, 412),
    ]) {
      testWidgets('$type learned mobility fits full controls at $size text1.3', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final a = await art(tester, type);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Guardian'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: const ValueKey('mobility-proof'),
              child: GamePage(art: a, heroClass: type, onRestart: () {}),
            ),
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
        final mobility = s.progress.mobilitySkill;
        Finder button() => find.byWidgetPredicate(
          (w) => w is ActionButton && w.semanticLabel == mobility.name,
        );
        expect(
          button(),
          findsNothing,
          reason: 'unlearned movement has no phantom control',
        );
        s.progress.level = 30;
        s.progress.skillPoints = 400;
        for (var pass = 0; pass < 30; pass++) {
          for (final skill in s.progress.skills) {
            if (s.progress.rank(skill.id) < 5) s.progress.learn(skill);
          }
        }
        final choices = s.progress.skills
            .where((skill) => !skill.passive && !skill.mobility)
            .take(4)
            .toList();
        for (var i = 0; i < choices.length; i++) {
          s.progress.selectSkill(choices[i].id, slot: i);
        }
        expect(s.progress.rank(mobility.id), 5);
        s.refresh();
        await tester.pump();
        expect(button(), findsOneWidget);
        s.hero.spin = 1;
        s.refresh();
        await tester.pump();
        expect(tester.widget<ActionButton>(button()).enabled, false);
        expect(tester.widget<ActionButton>(button()).semanticHint, '기술 동작 중');
        await tester.tap(button());
        await tester.pump();
        expect(
          s.hero.mobilityClock,
          0,
          reason: 'an active physical skill cannot be interrupted by mobility',
        );
        s.hero.spin = 0;
        s.refresh();
        await tester.pump();
        final targets = find.byType(ActionButton);
        final rects = [
          for (var i = 0; i < targets.evaluate().length; i++)
            tester.getRect(targets.at(i)),
        ];
        final viewport = Offset.zero & size;
        final stick = tester.getRect(find.byType(GameStick));
        for (var i = 0; i < rects.length; i++) {
          expect(rects[i].width, greaterThanOrEqualTo(44));
          expect(rects[i].height, greaterThanOrEqualTo(44));
          expect(viewport.contains(rects[i].topLeft), true);
          expect(viewport.contains(rects[i].bottomRight), true);
          expect(
            rects[i].overlaps(stick),
            false,
            reason: 'control $i cannot cover movement joystick',
          );
          for (var j = i + 1; j < rects.length; j++) {
            expect(
              rects[i].overlaps(rects[j]),
              false,
              reason: 'battle controls $i and $j overlap',
            );
          }
        }
        final dodge = tester.getRect(
          find.byWidgetPredicate(
            (w) => w is ActionButton && w.semanticLabel == '회피',
          ),
        );
        final movement = tester.getRect(button());
        expect(
          (movement.center - dodge.center).distance,
          lessThan(120),
          reason: 'movement remains adjacent to dodge',
        );
        final proof = Platform.environment['SJRPG_MOBILITY_PROOF_DIR'];
        if (proof != null) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('mobility-proof')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            Directory(proof).createSync(recursive: true);
            File(
              '$proof/${type.name}-${size.width.toInt()}x${size.height.toInt()}-130.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(button());
        await tester.pump();
        expect(s.hero.mobilityClock, greaterThan(0));
        expect(tester.widget<ActionButton>(button()).enabled, false);
        final cooldown = s.hero.mobilityClock;
        await tester.tap(button());
        await tester.pump();
        expect(
          s.hero.mobilityClock,
          lessThanOrEqualTo(cooldown),
          reason:
              'a disabled movement button cannot restart or consume a cooldown',
        );
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}

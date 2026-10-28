import 'dart:io';
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/affliction_widgets.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/health_widgets.dart';
import 'package:guardian_new/main.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/resource_meter.dart';
import 'package:guardian_new/rpg_widgets.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Guardian',
    )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in const [Size(320, 420), Size(844, 390)]) {
    testWidgets(
      'vision affects only the world; status and touch controls fit $size / 1.3',
      (tester) async {
        tester.view.physicalSize = size;
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
        final source = inCombatField(Adventure(art))..start(TestGame());
        source.mobs.clear();
        final checkpoint = GameCheckpoint.capture(source)!;
        source.dispose();
        final key = GlobalKey();
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
              key: key,
              child: GamePage(
                art: art,
                checkpoint: checkpoint,
                onRestart: () {},
              ),
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
        Future<Uint8List> capture(
          String phase,
        ) async => (await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final pixels = Uint8List.fromList(data.buffer.asUint8List());
          final directory = Platform.environment['AFFLICTION_PROOF_DIR'];
          if (directory != null) {
            await Directory(directory).create(recursive: true);
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '$directory/${size.width.toInt()}x${size.height.toInt()}-$phase.png',
            ).writeAsBytes(png.buffer.asUint8List());
          }
          image.dispose();
          return pixels;
        }))!;
        List<int> crop(Uint8List pixels, Rect rect) => [
          for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++)
            for (var x = rect.left.ceil(); x < rect.right.floor(); x++)
              for (var c = 0; c < 3; c++)
                pixels[(y * size.width.toInt() + x) * 4 + c],
        ];
        final before = await capture('normal');
        final controls = [
          for (final node in find.byType(ActionButton).evaluate())
            tester.getRect(find.byWidget(node.widget)),
          tester.getRect(find.byType(PotionBelt)),
          tester.getRect(find.byType(HealthMeter)),
          tester.getRect(find.byType(ResourceMeter)),
        ];
        s.afflictions.apply(PlayerStatus.root);
        s.afflictions.apply(PlayerStatus.poison);
        s.afflictions.apply(PlayerStatus.blind);
        s.afflictions.apply(PlayerStatus.attackSlow);
        s.afflictions.apply(PlayerStatus.moveSlow);
        s.refresh();
        await tester.pump();
        final dark = await capture('five-statuses');
        final statusBounds = tester.getRect(find.byType(AfflictionIcons));
        expect(statusBounds.width, lessThanOrEqualTo(80));
        expect(statusBounds.height, 16);
        expect(
          statusBounds.overlaps(tester.getRect(find.byType(PotionBelt))),
          false,
        );
        expect(find.byType(NarrowVisionCurtain), findsOneWidget);
        // Transparent button corners correctly show the darkened world. Check
        // fully opaque foreground ink, rather than comparing those corners.
        var foreground = 0;
        for (final rect in controls) {
          final a = crop(before, rect), b = crop(dark, rect);
          for (var i = 0; i < a.length; i += 3) {
            if ((a[i] == 240 && a[i + 1] == 229 && a[i + 2] == 200) ||
                (a[i] == 255 && a[i + 1] == 255 && a[i + 2] == 255) ||
                (a[i] == 255 && a[i + 1] == 240 && a[i + 2] == 222)) {
              expect(b.sublist(i, i + 3), a.sublist(i, i + 3));
              foreground++;
            }
          }
        }
        expect(foreground, greaterThan(20));
        final overlay = tester.widget<Stack>(
          find
              .ancestor(
                of: find.byType(NarrowVisionCurtain),
                matching: find.byType(Stack),
              )
              .first,
        );
        final curtainIndex = overlay.children.indexWhere(
          (w) => w is Positioned && w.child is NarrowVisionCurtain,
        );
        for (final (index, widget) in overlay.children.indexed) {
          if (widget is Positioned && widget.child is ActionButton) {
            expect(index, greaterThan(curtainIndex));
          }
        }
        final sample = const Rect.fromLTWH(0, 0, 3, 3);
        expect(
          crop(dark, sample).reduce((a, b) => a + b),
          lessThan(crop(before, sample).reduce((a, b) => a + b)),
        );
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('속박 2초'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            '중독 ${CombatBalance.realSeconds(s.afflictions.remaining(PlayerStatus.poison)).ceil()}초',
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('시야 제한 3초'), findsOneWidget);
        expect(find.bySemanticsLabel('공격 둔화 3초'), findsOneWidget);
        expect(find.bySemanticsLabel('이동 둔화 3초'), findsOneWidget);
        semantics.dispose();
        // A held joystick still receives cancellation during root, so it cannot
        // silently resume a released input when the timer ends.
        final stick = await tester.startGesture(
          tester.getCenter(find.byType(GameStick)),
        );
        await stick.moveBy(const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 50));
        final rootedAt = hero.position.clone();
        await stick.cancel();
        s.tick(1.5);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect((hero.position - rootedAt).length, lessThan(.01));
        // A held attack also receives pointer-up while frozen.
        s.afflictions.clear();
        final attack = find.byWidgetPredicate(
          (w) => w is ActionButton && w.semanticLabel == '공격',
        );
        final held = await tester.startGesture(tester.getCenter(attack));
        s.hurtHero(1, status: PlayerStatus.freeze);
        await held.up();
        await tester.pump();
        expect(s.attackSources, isEmpty);
        final strikes = hero.strikes;
        s.tick(.8);
        await tester.pump(const Duration(milliseconds: 50));
        expect(hero.strikes, strikes);
        s.afflictions.clear();
        hero.hurtFlash = 0;
        s.afflictions.apply(PlayerStatus.freeze);
        s.afflictions.apply(PlayerStatus.blind);
        s.refresh();
        await tester.pump();
        await capture('freeze-blind');
        s.tick(3);
        s.refresh();
        await tester.pump();
        expect(find.byType(NarrowVisionCurtain), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

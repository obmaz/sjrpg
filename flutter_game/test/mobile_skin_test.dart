import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/rpg_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'simple icon fallbacks remain distinct and entirely inside their cells',
    () async {
      final art = GameArt();
      addTearDown(art.dispose);
      final frames = <String>{};
      for (var index = 0; index < 18; index++) {
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        canvas.translate(16, 16);
        MobileActionGlyphPainter(art, index).paint(canvas, const Size(64, 64));
        final picture = recorder.endRecording(),
            image = await picture.toImage(96, 96);
        picture.dispose();
        final bytes = Uint8List.fromList(
          (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List(),
        );
        image.dispose();
        frames.add(base64Encode(bytes));
        var visible = 0;
        for (var y = 0; y < 96; y++) {
          for (var x = 0; x < 96; x++) {
            final at = (y * 96 + x) * 4, alpha = bytes[at + 3];
            if (alpha > 0) {
              visible++;
              expect(x, inInclusiveRange(16, 79));
              expect(y, inInclusiveRange(16, 79));
            }
            if (alpha == 255) {
              expect(bytes[at + 2], greaterThanOrEqualTo(bytes[at]));
            }
          }
        }
        expect(
          visible,
          greaterThan(80),
          reason: 'glyph $index cannot disappear when art is unavailable',
        );
      }
      expect(frames, hasLength(18));
    },
  );

  testWidgets(
    'flat controls preserve hold, cancellation, disabled state and 44px targets',
    (tester) async {
      final art = GameArt();
      addTearDown(art.dispose);
      var taps = 0, held = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ActionButton(
                  art: art,
                  sprite: 'roundEmpty',
                  label: '회피',
                  semanticLabel: '회피',
                  glyphIndex: MobileGlyph.dodge,
                  showLabel: false,
                  size: 44,
                  onTap: () => taps++,
                  onHold: (value) => held = value,
                ),
                GameIconButton(
                  label: '닫기',
                  icon: Icons.close,
                  size: 32,
                  onTap: () => taps++,
                ),
                SizedBox(
                  width: 150,
                  child: GameAction(
                    '계속',
                    primary: true,
                    minHeight: 30,
                    onTap: () => taps++,
                  ),
                ),
                const SizedBox(
                  width: 150,
                  child: GameAction('비활성', onTap: null),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(ActionButton)), const Size(44, 44));
      expect(tester.getSize(find.byType(GameIconButton)), const Size(44, 44));
      expect(tester.getSize(find.widgetWithText(GameAction, '계속')).height, 44);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ActionButton)),
      );
      expect(taps, 1);
      expect(held, true);
      await gesture.cancel();
      await tester.pump();
      expect(held, false);
      await tester.tap(find.widgetWithText(GameAction, '비활성'));
      expect(taps, 1);
      await tester.tap(find.widgetWithText(GameAction, '계속'));
      expect(taps, 2);
      await tester.tap(find.byType(GameIconButton));
      expect(taps, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('custom counters and equipment artwork win over generic glyphs', (
    tester,
  ) async {
    final art = GameArt();
    addTearDown(art.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionButton(
            art: art,
            sprite: 'roundEmpty',
            label: '새 명칭',
            semanticLabel: 'Translated action',
            glyphIndex: MobileGlyph.motor,
            primary: true,
            showLabel: false,
            size: 80,
            artwork: const Text('탄약 7'),
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('탄약 7'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is MobileActionGlyphPainter,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'cooldown shows real seconds while retaining the simulation ratio',
    (tester) async {
      final art = GameArt();
      addTearDown(art.dispose);
      const remaining = 2.4, total = 4.8;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButton(
              art: art,
              sprite: 'roundEmpty',
              label: '함성',
              semanticLabel: '함성',
              showLabel: false,
              size: 64,
              effect: 0,
              remaining: remaining,
              total: total,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(
        find.text('${CombatBalance.realSeconds(remaining).ceil()}'),
        findsOneWidget,
      );
      final button = tester.widget<ActionButton>(find.byType(ActionButton));
      expect(button.remaining / button.total, .5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'the same flat panel surrounds common actions without loading ornate button images',
    (tester) async {
      final art = GameArt();
      addTearDown(art.dispose);
      for (final compact in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: FramedSurface(
                    art: art,
                    compact: compact,
                    child: Column(
                      children: [
                        GamePanelHeader(title: '장비', onClose: () {}),
                        GameAction('장착', primary: true, onTap: () {}),
                        GameAction('판매', onTap: () {}),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(Image), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(gameButtonDecoration(primary: true).image, isNull);
      expect(gameButtonDecoration(primary: true).gradient, isNull);
      expect(gameButtonDecoration(primary: true).border, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

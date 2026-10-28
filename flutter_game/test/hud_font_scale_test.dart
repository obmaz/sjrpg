import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/health_widgets.dart';
import 'package:guardian_new/nearby_controls.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/quest_guide.dart';
import 'package:guardian_new/resource_meter.dart';
import 'package:guardian_new/rpg_widgets.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Guardian')
      ..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'));
    await font.load();
  });
  Widget scaled(Widget child) => MaterialApp(
    theme: ThemeData(fontFamily: 'Guardian'),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.3)),
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets(
    'battle HUD hides elapsed time and gold without hiding resources',
    (tester) async {
      final session = Adventure(GameArt())..start(TestGame());
      addTearDown(session.dispose);
      session.progress.gold = 123456;
      session.elapsed = 79;
      await tester.pumpWidget(scaled(GameHud(session)));
      expect(find.byIcon(Icons.monetization_on_outlined), findsNothing);
      expect(find.byIcon(Icons.wb_sunny_outlined), findsNothing);
      expect(find.text('1:19'), findsNothing);
      expect(find.text('123456'), findsNothing);
      expect(find.byType(HealthMeter), findsWidgets);
      expect(find.byType(ResourceMeter), findsWidgets);
    },
  );

  testWidgets('attack captions preserve font scaling inside their touch area', (
    tester,
  ) async {
    var attacks = 0;
    for (final label in ['공격', '회피', '연속 공격']) {
      await tester.pumpWidget(
        scaled(
          ActionButton(
            art: _CaptionArt(),
            sprite: 'roundEmpty',
            label: label,
            semanticLabel: label,
            size: 90,
            onTap: () => attacks++,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), null);
      expect(tester.getSize(find.byType(ActionButton)), const Size(90, 112));
      final caption = tester.getRect(find.text(label));
      expect(
        tester.getRect(find.byType(ActionButton)).contains(caption.bottomRight),
        true,
      );
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(label))
            .didExceedMaxLines,
        false,
      );
      await tester.tap(find.byType(ActionButton));
    }
    expect(attacks, 3);
  });

  testWidgets(
    'compact quest action hides automatic descriptions and stays legible at font scale 1.3',
    (tester) async {
      var cleanses = 0;
      await tester.pumpWidget(
        scaled(
          SizedBox(
            width: 156,
            height: 44,
            child: NearbyQuestCard(
              const QuestGuide(
                '뿌리 우물 · 준비 완료',
                '주변이 안전합니다.',
                QuestGuideAction.cleanse,
                '정화하기',
              ),
              compact: true,
              onTap: () => cleanses++,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), null);
      final card = tester.getRect(find.byType(NearbyQuestCard));
      expect(card.height, 44);
      expect(find.text('주변이 안전합니다.'), findsNothing);
      expect(find.text('뿌리 우물 · 준비 완료'), findsNothing);
      expect(card.contains(tester.getRect(find.text('정화')).bottomRight), true);
      await tester.tap(find.byType(NearbyQuestCard));
      expect(cleanses, 1);
    },
  );

  for (final count in [99, 128, 9999]) {
    testWidgets('potion quantity $count stays within the bounded HUD belt', (
      tester,
    ) async {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      s.progress.healingPotions = s.progress.energyPotions = count;
      s.progress.hp = 50;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(scaled(PotionBelt(s)));
        await tester.pump();
        expect(tester.takeException(), null);
        final belt = tester.getSize(find.byType(PotionBelt));
        expect(belt.height, 44);
        expect(belt.width, lessThanOrEqualTo(150));
        if (count < 1000) {
          for (final text in find.text('$count').evaluate()) {
            expect(
              (text.renderObject! as RenderParagraph).didExceedMaxLines,
              false,
            );
          }
        }
        final heal = find.bySemanticsLabel('치유 물약 $count개');
        expect(heal, findsOneWidget);
        await tester.tap(heal);
        expect(s.progress.healingPotions, count - 1);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets(
    'four nearby actions keep 44px targets and remain reachable in a narrow HUD',
    (tester) async {
      final pressed = <String>[];
      final actions = ['타기', '상점', '대화', '워프'];
      await tester.pumpWidget(
        scaled(
          SizedBox(
            width: 146,
            child: NearbyControls(
              horizontal: true,
              actions: [
                for (final label in actions)
                  NearbyControl(
                    label: label,
                    icon: Icons.touch_app,
                    onTap: () => pressed.add(label),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final band = tester.getRect(find.byType(NearbyControls));
      expect(band.size, const Size(146, 44));
      for (final label in actions) {
        final button = find
            .widgetWithIcon(GameIconButton, Icons.touch_app)
            .evaluate()
            .where((e) => (e.widget as GameIconButton).label == label)
            .single;
        final target = find.byWidget(button.widget);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final rect = tester.getRect(target);
        expect(rect.size, const Size(44, 44));
        expect(band.contains(rect.center), true);
        await tester.tap(target);
      }
      expect(pressed, actions);
      expect(tester.takeException(), null);
    },
  );

  test(
    'tight HUD leading preserves every Korean glyph pixel at font scale 1.3',
    () async {
      Future<List<int>> raster(
        TextPainter text,
        Offset at, {
        double? clipHeight,
        double clipTop = 20,
        TextPainter? second,
        Offset? secondAt,
      }) async {
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        if (clipHeight != null) {
          canvas.clipRect(Rect.fromLTWH(0, clipTop, 200, clipHeight));
        }
        text.paint(canvas, at);
        if (second != null) second.paint(canvas, secondAt!);
        final picture = recorder.endRecording();
        final image = await picture.toImage(200, 80);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        image.dispose();
        picture.dispose();
        return bytes.buffer.asUint8List();
      }

      TextPainter paragraph(String label, double size, double? height) =>
          TextPainter(
            text: TextSpan(
              text: label,
              style: TextStyle(
                fontFamily: 'Guardian',
                fontSize: size,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: height,
              ),
            ),
            textDirection: TextDirection.ltr,
            textScaler: const TextScaler.linear(1.3),
            maxLines: 1,
          )..layout(maxWidth: 180);
      for (final label in ['공격', '회피', '연속 공격']) {
        final normal = paragraph(label, 13, null),
            tight = paragraph(label, 13, 1.1);
        final baseline =
            20 + tight.computeDistanceToActualBaseline(TextBaseline.alphabetic);
        final expected = await raster(
          normal,
          Offset(
            10,
            baseline -
                normal.computeDistanceToActualBaseline(TextBaseline.alphabetic),
          ),
        );
        final actual = await raster(
          tight,
          const Offset(10, 20),
          clipHeight: 22,
        );
        expect(
          actual,
          expected,
          reason:
              '$label keeps its full-size ink inside the HUD line allocation',
        );
        expect(actual.where((channel) => channel != 0), isNotEmpty);
        normal.dispose();
        tight.dispose();
      }

      // The compact guide clips the complete card, including its padding;
      // individual Text line boxes do not clip glyph ascenders.
      final title = paragraph('뿌리 우물', 12, 1.1),
          caption = paragraph('정화하기 ›', 12, 1.1),
          normalTitle = paragraph('뿌리 우물', 12, null),
          normalCaption = paragraph('정화하기 ›', 12, null);
      Offset referenceAt(TextPainter compact, TextPainter normal, double y) =>
          Offset(
            10,
            y +
                compact.computeDistanceToActualBaseline(
                  TextBaseline.alphabetic,
                ) -
                normal.computeDistanceToActualBaseline(TextBaseline.alphabetic),
          );
      final expected = await raster(
        normalTitle,
        referenceAt(title, normalTitle, 4),
        second: normalCaption,
        secondAt: referenceAt(caption, normalCaption, 4 + title.height),
      );
      final actual = await raster(
        title,
        const Offset(10, 4),
        second: caption,
        secondAt: Offset(10, 4 + title.height),
        clipTop: 0,
        clipHeight: 44,
      );
      expect(
        actual,
        expected,
        reason: 'both guide lines retain every glyph inside the 44px card',
      );
      for (final text in [title, caption, normalTitle, normalCaption]) {
        text.dispose();
      }
    },
  );
}

class _CaptionArt extends GameArt {
  @override
  void control(ui.Canvas canvas, String key, ui.Rect destination) {}
}

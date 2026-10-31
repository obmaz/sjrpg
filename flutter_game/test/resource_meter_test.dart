import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_numbers.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/resource_meter.dart';
import 'package:guardian_new/rpg_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final key = GlobalKey();
  Widget host(Adventure session, {double scale = 1}) => MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xff141a20),
      body: Center(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: key,
            child: SizedBox(width: 240, child: ResourceMeter(session)),
          ),
        ),
      ),
    ),
  );
  Future<List<int>> capture(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List().toList();
        image.dispose();
        return bytes;
      }))!;

  for (final hero in HeroClass.values) {
    testWidgets(
      '$hero flat resource meter stays slim, legible, and visually static',
      (tester) async {
        final s = Adventure(GameArt(), heroClass: hero)..start(TestGame());
        addTearDown(s.dispose);
        for (final ratio in [0.0, .5, 1.0]) {
          s.progress.energy = s.progress.maxEnergy * ratio;
          final state = jsonEncode(s.progress.toSave());
          await tester.pumpWidget(host(s));
          await tester.pump();
          expect(
            tester
                .getSize(find.byKey(const ValueKey('hud-resource-gauge')))
                .height,
            7,
          );
          final label =
              '${hero.resource} ${CombatNumbers.resource(s.progress.energy, rounding: CombatRounding.down)}';
          expect(find.text(label), findsOneWidget);
          final before = await capture(tester);
          s.elapsed += 1;
          await tester.pump(const Duration(seconds: 1));
          expect(await capture(tester), orderedEquals(before));
          expect(jsonEncode(s.progress.toSave()), state);
        }
        await tester.pumpWidget(host(s, scale: 1.8));
        expect(tester.takeException(), null);
      },
    );
  }
  testWidgets(
    'paused updates and clamped values refresh without a paint ticker',
    (tester) async {
      final s = Adventure(GameArt(), heroClass: HeroClass.mage)
        ..start(TestGame());
      addTearDown(s.dispose);
      s.pause();
      await tester.pumpWidget(host(s));
      s.progress.energy = 9.79;
      s.refresh();
      await tester.pump();
      expect(find.text('마나 97'), findsOneWidget);
      for (final energy in [-100.0, double.nan, double.infinity]) {
        s.progress.energy = energy;
        s.refresh();
        await tester.pump();
        expect(find.text('마나 0'), findsOneWidget);
        expect(tester.takeException(), null);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      s.progress.energy = 10;
      s.refresh();
      await tester.pump();
      expect(tester.takeException(), null);
    },
  );
}

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/resource_meter.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Guardian',
    )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'))).load();
  });
  final boundary = GlobalKey();
  Adventure scene([HeroClass hero = HeroClass.warrior]) {
    final s = Adventure(GameArt(), heroClass: hero)..start(TestGame());
    addTearDown(s.dispose);
    return s;
  }

  Widget host(
    Adventure s, {
    bool reduced = false,
    bool ticker = true,
    double scale = 1,
    Key? meterKey,
    double height = 17,
  }) => MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduced,
      textScaler: TextScaler.linear(scale),
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Guardian'),
        child: TickerMode(
          enabled: ticker,
          child: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: 133,
                child: ResourceMeter(s, key: meterKey, height: height),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Future<Uint8List> capture(
    WidgetTester tester, {
    bool paintOnly = false,
    String? proof,
  }) async {
    final render = paintOnly
        ? tester.renderObject<RenderRepaintBoundary>(
            find.descendant(
              of: find.byType(ResourceMeter),
              matching: find.byType(RepaintBoundary),
            ),
          )
        : boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() async {
      final image = await render.toImage();
      final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final bytes = Uint8List.fromList(raw.buffer.asUint8List());
      final dir = Platform.environment['RESOURCE_PROOF_DIR'];
      if (dir != null && proof != null) {
        await Directory(dir).create(recursive: true);
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('$dir/$proof.png').writeAsBytes(png.buffer.asUint8List());
      }
      image.dispose();
      return bytes;
    }))!;
  }

  Future<void> pumpEngine(
    WidgetTester tester,
    Adventure session,
    Duration duration,
  ) async {
    final game = session.game;
    if (session.active && game != null && !game.paused && game.timeScale > 0) {
      // Feed only the visual clock's real simulation timestamp. Do not tick
      // combat/resource recovery while checking a constant resource value.
      session.elapsed += duration.inMicroseconds / 1000000 * game.timeScale;
    }
    await tester.pump(duration);
  }

  int changes(Uint8List a, Uint8List b, {int left = 0}) {
    var n = 0;
    for (var y = 0; y < a.length ~/ (133 * 4); y++) {
      for (var x = left; x < 133; x++) {
        final i = (y * 133 + x) * 4;
        if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) {
          n++;
        }
      }
    }
    return n;
  }

  for (final hero in HeroClass.values) {
    testWidgets(
      '$hero fluid deforms at constant100/50; zero and outside fill stay empty',
      (tester) async {
        final s = scene(hero);
        final semantics = tester.ensureSemantics();

        for (final fraction in [1.0, .5, 0.0]) {
          s.progress.energy = s.progress.maxEnergy * fraction;
          await tester.pumpWidget(host(s, scale: 1.3));
          await tester.pump();
          final label = '${hero.resource} ${s.progress.energy.floor()}';
          expect(find.text(label), findsOneWidget);
          expect(
            find.bySemanticsLabel('$label / ${s.progress.maxEnergy.round()}'),
            findsOneWidget,
          );
          final text = tester.widget<Text>(find.text(label));
          final state = jsonEncode(s.progress.toSave());
          final first = await capture(tester, paintOnly: true);
          await tester.pump(const Duration(seconds: 2));
          expect(
            await capture(tester, paintOnly: true),
            orderedEquals(first),
            reason:
                'an active engine without simulation updates does not animate HUD',
          );
          await capture(
            tester,
            proof: '${hero.name}-${(fraction * 100).round()}-a',
          );
          for (var i = 0; i < 9; i++) {
            await pumpEngine(tester, s, const Duration(milliseconds: 34));
          }
          final later = await capture(tester, paintOnly: true);
          await capture(
            tester,
            proof: '${hero.name}-${(fraction * 100).round()}-b',
          );
          if (fraction > 0) {
            expect(changes(first, later), greaterThan(20));
          } else {
            expect(later, orderedEquals(first));
          }
          if (fraction == .5) {
            expect(
              changes(first, later, left: 68),
              0,
              reason: 'currents and embers never enter the empty half',
            );
          }
          expect(
            identical(tester.widget<Text>(find.text(label)), text),
            true,
            reason: 'animation repaints without rebuilding label/HUD',
          );
          expect(
            jsonEncode(s.progress.toSave()),
            state,
            reason: 'visual clock cannot mutate resources or gameplay',
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      },
    );
  }
  testWidgets('paint clock caps at30Hz and never catches up a long wall gap', (
    tester,
  ) async {
    final s = scene();
    s.progress.energy = 50;
    await tester.pumpWidget(host(s));
    await tester.pump();
    final first = await capture(tester, paintOnly: true);
    await tester.pump(const Duration(seconds: 2));
    expect(await capture(tester, paintOnly: true), orderedEquals(first));
    for (var i = 0; i < 3; i++) {
      await pumpEngine(tester, s, const Duration(milliseconds: 8));
    }
    expect(await capture(tester, paintOnly: true), orderedEquals(first));
    await pumpEngine(tester, s, const Duration(milliseconds: 10));
    final frame = await capture(tester, paintOnly: true);
    expect(changes(first, frame), greaterThan(0));
    await tester.pumpWidget(host(s, meterKey: const ValueKey('long')));
    await tester.pump();
    await pumpEngine(tester, s, const Duration(seconds: 3));
    final long = await capture(tester, paintOnly: true);
    await tester.pumpWidget(host(s, meterKey: const ValueKey('short')));
    await tester.pump();
    await pumpEngine(tester, s, const Duration(milliseconds: 100));
    expect(
      await capture(tester, paintOnly: true),
      orderedEquals(long),
      reason:
          'three seconds is one bounded .1s visual step, not a catch-up jump',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'direct engine pause and hitstop freeze then resume without changing state',
    (tester) async {
      final s = scene();
      s.progress.energy = 50;
      final game = s.game! as TestGame;
      await tester.pumpWidget(host(s));
      await tester.pump();
      await pumpEngine(tester, s, const Duration(milliseconds: 34));
      for (final stop in ['engine', 'hitstop', 'session']) {
        final before = await capture(tester, paintOnly: true);
        if (stop == 'engine') {
          game.pauseEngine();
        } else if (stop == 'hitstop') {
          game.timeScale = 0;
        } else {
          s.pause();
        }
        s.refresh(); // A HUD refresh while directly stopped must not lose resume polling.
        await pumpEngine(tester, s, const Duration(seconds: 2));
        expect(
          await capture(tester, paintOnly: true),
          orderedEquals(before),
          reason: stop,
        );
        if (stop == 'engine') {
          game.resumeEngine();
        } else if (stop == 'hitstop') {
          game.timeScale = 1;
        } else {
          s.resume();
        }
        await tester.pump();
        expect(await capture(tester, paintOnly: true), orderedEquals(before));
        await pumpEngine(tester, s, const Duration(milliseconds: 34));
        expect(
          changes(before, await capture(tester, paintOnly: true)),
          greaterThan(0),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('reduced motion, muted ticker and background remain static', (
    tester,
  ) async {
    final s = scene(HeroClass.mage);
    s.progress.energy = 45;
    for (final mode in ['reduced', 'ticker', 'background']) {
      await tester.pumpWidget(
        host(s, reduced: mode == 'reduced', ticker: mode != 'ticker'),
      );
      await tester.pump();
      if (mode == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      }
      final before = await capture(tester, paintOnly: true);
      await pumpEngine(tester, s, const Duration(seconds: 2));
      expect(await capture(tester, paintOnly: true), orderedEquals(before));
      if (mode == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'null game draws safely and replacing/disposal detaches the old session',
    (tester) async {
      final old = scene(),
          next = Adventure(GameArt(), heroClass: HeroClass.mage);
      addTearDown(next.dispose);
      await tester.pumpWidget(host(old));
      await tester.pump();
      await tester.pumpWidget(host(next));
      await tester.pump();
      final before = await capture(tester, paintOnly: true);
      old.progress.energy = 0;
      old.refresh();
      await pumpEngine(tester, next, const Duration(seconds: 2));
      expect(await capture(tester, paintOnly: true), orderedEquals(before));
      expect(find.text('마나 90'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      old.refresh();
      next.refresh();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  for (final hero in HeroClass.values) {
    for (final requestedHeight in [15.0, 22.0]) {
      testWidgets(
        '$hero full-size130% label fits requested height$requestedHeight',
        (tester) async {
          final s = scene(hero);
          s.progress.energy = s.progress.maxEnergy;
          await tester.pumpWidget(host(s, scale: 1.3, height: requestedHeight));
          await tester.pump();
          final bar = tester.getRect(find.byType(ResourceMeter));
          final label = tester.getRect(find.byType(Text));
          expect(
            bar.height,
            greaterThanOrEqualTo(
              ResourceMeter.minimumHeight(const TextScaler.linear(1.3)),
            ),
          );
          expect(label.top, greaterThanOrEqualTo(bar.top + 1));
          expect(label.bottom, lessThanOrEqualTo(bar.bottom - 1));
          expect(tester.widget<Text>(find.byType(Text)).style!.fontSize, 12);
          expect(
            find.byType(FittedBox),
            findsNothing,
            reason:
                'large-font accessibility is preserved rather than scaled down',
          );
          await capture(
            tester,
            proof: '${hero.name}-requested${requestedHeight.round()}-large130',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets('paused resource changes redraw the true fill and floor label', (
    tester,
  ) async {
    final s = scene();
    s.progress.energy = 50;
    await tester.pumpWidget(host(s));
    await tester.pump();
    s.pause();
    await tester.pump();
    final before = await capture(tester, paintOnly: true);
    s.progress.energy = 25.9;
    s.refresh();
    await tester.pump();
    expect(find.text('분노 25'), findsOneWidget);
    final updated = await capture(tester, paintOnly: true);
    expect(changes(before, updated), greaterThan(0));
    await pumpEngine(tester, s, const Duration(seconds: 2));
    expect(await capture(tester, paintOnly: true), orderedEquals(updated));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

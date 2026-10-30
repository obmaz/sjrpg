import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/health_widgets.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/player_health_feedback.dart';
import 'package:guardian_new/resource_meter.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/rpg_widgets.dart';

import 'support/test_game.dart';

void main() {
  test('gauge join follows the portrait circle and preserves the live bar', () {
    const clipper = PortraitGaugeClipper(Offset(0, 15), 35);
    final clip = clipper.getClip(const Size(180, 20));
    expect(clip.contains(const Offset(10, 10)), false);
    expect(clip.contains(const Offset(34, 15)), false);
    expect(clip.contains(const Offset(36, 15)), true);
    expect(clip.contains(const Offset(34, 0)), true);
    expect(clip.contains(const Offset(170, 10)), true);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  GameArt? loaded;
  Future<GameArt> art(WidgetTester tester) async =>
      loaded ??= (await tester.runAsync(() async {
        await (FontLoader(
              'Guardian',
            )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf')))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        return GameArt.loadMenu();
      }))!;
  tearDownAll(() => loaded?.dispose());
  Future<void> proof(WidgetTester tester, String name) async {
    final directory = Platform.environment['SJRPG_HEALTH_PROOF_DIR'];
    if (directory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('health-proof')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        Directory(directory).createSync(recursive: true);
        File('$directory/$name.png').writeAsBytesSync(bytes);
      } finally {
        image.dispose();
      }
    });
  }

  Future<void> show(
    WidgetTester tester,
    Size size,
    Widget child, {
    bool reduced = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Guardian'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('health-proof'),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  for (final size in [
    const Size(320, 420),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final hp in [100.0, 30.0, 10.0, 9.0]) {
      testWidgets('male HUD health $hp stays legible at $size and font1.3', (
        tester,
      ) async {
        final artwork = await art(tester);
        final s = inCombatField(Adventure(artwork)..start(TestGame()));
        addTearDown(s.dispose);
        s.progress.hp = hp;
        s.progress.gold = 9999999;
        s.elapsed = 36000;
        for (final status in PlayerStatus.values) {
          s.afflictions.apply(status);
        }
        var maps = 0;
        await show(
          tester,
          size,
          PlayerHealthFeedbackScope(
            session: s,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RawImage(
                  image: artwork.images['entry-scene'],
                  fit: BoxFit.cover,
                ),
                HealthDangerVignette(s),
                Align(
                  alignment: Alignment.topCenter,
                  child: GameHud(s, onMap: () => maps++),
                ),
                if (size.width >= 600)
                  Positioned(left: 136, bottom: 66, child: PotionBelt(s))
                else
                  Positioned(left: 14, top: 110, child: PotionBelt(s)),
              ],
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final health = tester.getRect(find.byType(HealthMeter));
        final resource = tester.getRect(find.byType(ResourceMeter));
        final identity = tester.getRect(
          find.byKey(const ValueKey('hud-identity')),
        );
        final portrait = tester.getRect(
          find.byKey(const ValueKey('hud-portrait')),
        );
        expect(find.text('Lv.${s.progress.level}  전사'), findsOneWidget);
        expect(identity.bottom, lessThanOrEqualTo(health.top));
        expect(health.left, lessThan(portrait.right));
        expect(health.left, greaterThan(portrait.center.dx));
        final xp = tester.getRect(find.byKey(const ValueKey('hud-experience')));
        expect(xp.top, greaterThan(resource.bottom));
        expect(xp.left, health.left);
        expect(xp.bottom, lessThan(100));
        expect(resource.width, lessThanOrEqualTo(health.width));
        expect(health.height, lessThanOrEqualTo(18));
        expect(health.bottom, lessThanOrEqualTo(resource.top));
        expect(resource.height, greaterThanOrEqualTo(18));
        final hpText = tester.getRect(find.text('${hp.ceil()} / 100'));
        expect(health.contains(hpText.topLeft), true);
        expect(health.contains(hpText.bottomRight), true);
        final resourceText = tester.getRect(find.text('분노 25'));
        expect(resource.contains(resourceText.topLeft), true);
        expect(resource.contains(resourceText.bottomRight), true);
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('분노 25'))
              .didExceedMaxLines,
          false,
        );
        final hud = tester.getRect(find.byType(GameHud));
        for (final paragraph
            in find
                .descendant(
                  of: find.byType(GameHud),
                  matching: find.byType(RichText),
                )
                .evaluate()) {
          final render = paragraph.renderObject! as RenderParagraph;
          expect(render.didExceedMaxLines, false);
          expect(
            hud.bottom + .1,
            greaterThanOrEqualTo(
              render.localToGlobal(Offset(0, render.size.height)).dy,
            ),
          );
        }
        await proof(
          tester,
          'hud-${size.width.toInt()}x${size.height.toInt()}-hp${hp.toInt()}',
        );
        final semantics = tester.ensureSemantics();
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('지도 확대'));
        expect(maps, 1, reason: 'danger layer never intercepts HUD input');
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'critical pulse has a calm peak and the mage retains his portrait and mana',
    (tester) async {
      final artwork = await art(tester);
      final s = inCombatField(
        Adventure(artwork, heroClass: HeroClass.mage)..start(TestGame()),
      );
      addTearDown(s.dispose);
      s.progress.hp = 7;
      PlayerHealthFeedback? feedback;
      await show(
        tester,
        const Size(390, 844),
        PlayerHealthFeedbackScope(
          session: s,
          child: Builder(
            builder: (context) {
              feedback = PlayerHealthFeedbackScope.maybeOf(context);
              return Stack(
                fit: StackFit.expand,
                children: [
                  RawImage(
                    image: artwork.images['entry-scene'],
                    fit: BoxFit.cover,
                  ),
                  HealthDangerVignette(s),
                  Align(alignment: Alignment.topCenter, child: GameHud(s)),
                ],
              );
            },
          ),
        ),
      );
      final minimum = feedback!.dangerOpacity;
      await proof(tester, 'mage-critical-pulse-rest');
      for (var i = 0; i < 5; i++) {
        s.tick(.1);
        await tester.pump(const Duration(milliseconds: 34));
      }
      expect(feedback!.dangerOpacity, greaterThan(minimum));
      expect(feedback!.dangerOpacity, lessThanOrEqualTo(.26));
      expect(find.text('7 / 80'), findsOneWidget);
      expect(find.text('마나 90'), findsOneWidget);
      await proof(tester, 'mage-critical-pulse-peak');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'poison damage paints a brief red cue above world and below readable controls',
    (tester) async {
      final artwork = await art(tester);
      final s = inCombatField(Adventure(artwork)..start(TestGame()));
      addTearDown(s.dispose);
      s.progress.hp = 80;
      PlayerHealthFeedback? feedback;
      var presses = 0;
      await show(
        tester,
        const Size(390, 844),
        PlayerHealthFeedbackScope(
          session: s,
          child: Builder(
            builder: (context) {
              feedback = PlayerHealthFeedbackScope.maybeOf(context);
              return Stack(
                fit: StackFit.expand,
                children: [
                  RawImage(
                    image: artwork.images['entry-scene'],
                    fit: BoxFit.cover,
                  ),
                  HealthDangerVignette(s),
                  Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedBuilder(
                      animation: s,
                      builder: (context, _) => GameHud(s),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton(
                      onPressed: () => presses++,
                      child: const Text('공격'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      s.hero.invulnerable = 3;
      s.afflictions.apply(PlayerStatus.poison);
      s.afflictions.poisonTick = .01;
      s.tick(.05);
      await tester.pump(const Duration(milliseconds: 20));
      expect(s.progress.hp, lessThan(80));
      expect(feedback!.damageRemaining, greaterThan(0));
      expect(feedback!.dangerOpacity, greaterThan(0));
      await proof(tester, 'poison-hp-drop');
      await tester.tap(find.text('공격'));
      expect(presses, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'wall-time alone does not animate, and shared scope never rebuilds whole HUD',
    (tester) async {
      final s = inCombatField(Adventure(GameArt())..start(TestGame()));
      addTearDown(s.dispose);
      s.progress.hp = 9;
      PlayerHealthFeedback? f;
      var builds = 0;
      await show(
        tester,
        const Size(320, 420),
        PlayerHealthFeedbackScope(
          session: s,
          child: Builder(
            builder: (context) {
              builds++;
              f = PlayerHealthFeedbackScope.maybeOf(context);
              return Stack(
                fit: StackFit.expand,
                children: [
                  HealthDangerVignette(s),
                  Align(alignment: Alignment.topCenter, child: HealthMeter(s)),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(f!.phase, 0);
      for (var i = 0; i < 10; i++) {
        s.tick(.04);
        await tester.pump(const Duration(milliseconds: 34));
      }
      expect(f!.phase, greaterThan(0));
      expect(builds, 1);
      final phase = f!.phase;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      s.elapsed += 4;
      await tester.pump(const Duration(seconds: 1));
      expect(f!.phase, phase);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(f!.phase, phase);
      s.tick(.04);
      await tester.pump(const Duration(milliseconds: 34));
      expect((f!.phase - phase).abs(), lessThan(.06));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('restored critical health paints when the engine becomes ready', (
    tester,
  ) async {
    final s = Adventure(GameArt())..progress.hp = 9;
    addTearDown(s.dispose);
    PlayerHealthFeedback? feedback;
    final paintKey = GlobalKey();
    await show(
      tester,
      const Size(320, 420),
      PlayerHealthFeedbackScope(
        session: s,
        child: Builder(
          builder: (context) {
            feedback = PlayerHealthFeedbackScope.maybeOf(context);
            return RepaintBoundary(
              key: paintKey,
              child: HealthDangerVignette(s),
            );
          },
        ),
      ),
      reduced: true,
    );
    Future<int> cornerAlpha() async {
      final boundary =
          paintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          return bytes[3];
        } finally {
          image.dispose();
        }
      }))!;
    }

    expect(await cornerAlpha(), 0);
    expect(feedback!.needsFrames, false);
    s.start(TestGame());
    await tester.pump();
    expect(feedback!.dangerOpacity, .11);
    expect(feedback!.damageRemaining, 0);
    expect(feedback!.needsFrames, false);
    expect(await cornerAlpha(), greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reduced motion stays static and swapping sessions cannot replay an old hit',
    (tester) async {
      final a = inCombatField(Adventure(GameArt())..start(TestGame()));
      final b = inCombatField(Adventure(GameArt())..start(TestGame()));
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      a.progress.hp = 9;
      PlayerHealthFeedback? f;
      Widget page(Adventure s) => PlayerHealthFeedbackScope(
        session: s,
        child: Builder(
          builder: (context) {
            f = PlayerHealthFeedbackScope.maybeOf(context);
            return HealthDangerVignette(s);
          },
        ),
      );
      await show(tester, const Size(320, 420), page(a), reduced: true);
      final alpha = f!.dangerOpacity;
      for (var i = 0; i < 5; i++) {
        a.tick(.1);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(f!.phase, 0);
      expect(f!.dangerOpacity, alpha);
      final old = f;
      await show(tester, const Size(320, 420), page(b), reduced: true);
      expect(identical(old, f), false);
      expect(f!.damageRemaining, 0);
      expect(f!.dangerOpacity, 0);
      a.hurtHero(5);
      await tester.pump();
      expect(f!.damageRemaining, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      b.hurtHero(5);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/scene_atmosphere.dart';
import 'package:guardian_new/sorceress_combat.dart';

import 'support/sorceress_fixture.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'vignette leaves the center clear and passes input to the world',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const ColoredBox(color: Colors.white),
              ),
              const GameVignette(),
            ],
          ),
        ),
      );
      await tester.tapAt(const Offset(150, 150));
      expect(taps, 1);
      final widget = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('game-vignette')),
      );
      final gradient =
          (widget.decoration as BoxDecoration).gradient! as RadialGradient;
      expect(gradient.center, Alignment.center);
      expect(gradient.radius, .9);
      expect(gradient.colors.first.a, 0);
      expect(gradient.colors.last.a, closeTo(.45, .005));
    },
  );
  testWidgets('both joystick parts fade together and cancel returns to rest', (
    tester,
  ) async {
    final values = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: GameStick(
            art: GameArt(),
            size: 140,
            onChange: (_, intensity) => values.add(intensity),
          ),
        ),
      ),
    );
    Opacity opacity() =>
        tester.widget<Opacity>(find.byKey(const ValueKey('joystick-opacity')));
    expect(opacity().opacity, .18);
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(GameStick)) + const Offset(25, 0),
    );
    await tester.pump();
    expect(opacity().opacity, .4);
    expect(values.last, greaterThan(0));
    await finger.cancel();
    await tester.pump();
    expect(opacity().opacity, .18);
    expect(values.last, 0);
  });
  testWidgets('cooldown clears clockwise and shows fractional real seconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ActionButton(
            art: GameArt(),
            sprite: 'roundEmpty',
            label: '기술',
            semanticLabel: '테스트 기술',
            icon: Icons.flash_on,
            showLabel: false,
            size: 64,
            total: 2.88,
            remaining: 1.44,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('1.2s'), findsOneWidget);
    final painter = tester
        .widget<CustomPaint>(find.byKey(const ValueKey('cooldown-overlay')))
        .painter!;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      painter.paint(ui.Canvas(recorder), const Size(64, 64));
      final picture = recorder.endRecording(),
          image = await picture.toImage(64, 64);
      picture.dispose();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      expect(bytes[(32 * 64 + 12) * 4 + 3], greaterThan(100));
      expect(bytes[(32 * 64 + 52) * 4 + 3], 0);
      image.dispose();
    });
  });
  test(
    'player and finite spell lights share real Bonfire lighting without gameplay effects',
    () {
      final s = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage))
        ..start(TestGame());
      addTearDown(s.dispose);
      s.progress.level = 100;
      s.progress.skillPoints = 1000;
      trainSkill(s.progress, 'chargedBolt', 20);
      final spec = s.progress.sorceressSpell(
        s.progress.skills.firstWhere((d) => d.id == 'chargedBolt'),
      );
      expect(s.hero, isA<WithLighting>());
      expect(s.hero.lighting.config!.radius, 120);
      expect(s.hero.lighting.config!.withPulse, true);
      final bolts = [
        for (var i = 0; i < 24; i++)
          SorceressProjectile(
            s.hero.sorceressCombat,
            spec,
            s.hero.body.center,
            damageAmount: 1,
            bearing: 0,
            seed: i,
          ),
      ];
      final flashes = [
        for (var i = 0; i < 12; i++)
          SorceressFlash(
            s.hero.sorceressCombat,
            spec,
            s.hero.body.center,
            mode: 'impact',
            duration: 1,
            radius: 80,
          ),
      ];
      for (final effect in [...bolts, ...flashes]) {
        effect.step(.01);
      }
      expect(
        [...bolts, ...flashes].where((e) => e.lighting.config != null),
        hasLength(SorceressCombat.maxLights),
      );
      final flash = flashes.firstWhere((e) => e.lighting.config != null),
          alpha = flashes.first.lighting.config!.color.a;
      for (var i = 0; i < 14; i++) {
        flash.step(.05);
      }
      expect(flash.lighting.config!.color.a, lessThan(alpha));
      s.pause();
      final age = flash.age;
      flash.step(.5);
      expect(flash.age, age);
      for (final effect in [...bolts, ...flashes]) {
        effect.finish();
        expect(effect.lighting.config, null);
      }
    },
  );
}

import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

Future<(int, int)> bodyPixels(Guardian hero) async {
  final recorder = ui.PictureRecorder();
  // Render with the real actor atlas, keeping the protection ring outside the body sample.
  final bodyCanvas = ui.Canvas(recorder)..translate(52, 88);
  hero.render(bodyCanvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(128, 128);
  picture.dispose();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  var alpha = 0, light = 0;
  for (var y = 10; y < 96; y++) {
    for (var x = 0; x < 128; x++) {
      final offset = (y * 128 + x) * 4;
      alpha += bytes.getUint8(offset + 3);
      light += bytes.getUint8(offset) + bytes.getUint8(offset + 1);
    }
  }
  image.dispose();
  return (alpha, light);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt art;
  setUpAll(() async {
    art = await GameArt.load();
  });
  tearDownAll(() {
    for (final shader in art.materials) {
      shader.dispose();
    }
    for (final image in art.images.values) {
      image.dispose();
    }
  });
  for (final heroClass in HeroClass.values) {
    test(
      '$heroClass stays fully visible during protection and flashes without losing body coverage',
      () async {
        final s = inCombatField(Adventure(art, heroClass: heroClass));
        s.start(TestGame());
        addTearDown(s.dispose);
        s.hero.invulnerable = 0;
        s.hero.hurtFlash = 0;
        final normal = await bodyPixels(s.hero);
        s.hero.invulnerable = .6;
        final protected = await bodyPixels(s.hero);
        expect(normal.$1, greaterThan(100000));
        expect(protected, normal);
        s.hero.hurtFlash = .1;
        final flashed = await bodyPixels(s.hero);
        expect(flashed.$1, normal.$1);
        expect(flashed.$2, greaterThan(normal.$2));
      },
    );
  }
  test(
    'damage flash respects pause and ignored hits do not restart it or change health',
    () {
      final s = inCombatField(Adventure(art));
      s.start(TestGame());
      addTearDown(s.dispose);
      s.hurtHero(10);
      expect(s.hero.hurtFlash, .12);
      s.hero.update(.05);
      final remaining = s.hero.hurtFlash, hp = s.progress.hp;
      s.hurtHero(10);
      expect(s.hero.hurtFlash, remaining);
      expect(s.progress.hp, hp);
      s.pause();
      s.hero.update(.5);
      expect(s.hero.hurtFlash, remaining);
      s.resume();
      for (var i = 0; i < 4; i++) {
        s.hero.update(.05);
      }
      expect(s.hero.hurtFlash, 0);
      expect(s.progress.hp, hp);
    },
  );
}

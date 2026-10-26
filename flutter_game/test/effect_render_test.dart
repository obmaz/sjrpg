import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bonfire/camera/bonfire_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/effect_atlas.dart';
import 'package:guardian_new/fire_plume.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/spell_vfx.dart';

import 'support/test_game.dart';

Future<Uint8List> raster(
  void Function(ui.Canvas) paint, {
  int side = 160,
}) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording(),
      image = await picture.toImage(side, side);
  picture.dispose();
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  image.dispose();
  return bytes;
}

class _TestCamera extends BonfireCamera {
  ui.Rect visibleRect = const ui.Rect.fromLTWH(0, 0, 300, 300);
  @override
  ui.Rect get visibleWorldRect => visibleRect;
}

class _CameraGame extends TestGame {
  @override
  final _TestCamera camera = _TestCamera();
}

class _CountingBurst extends SpellBurst {
  _CountingBurst(super.session, super.clip, super.at, {required super.radius});
  int draws = 0;
  @override
  void render(ui.Canvas canvas) {
    draws++;
    super.render(canvas);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'FX atlas regions are shared, inset and refreshed for a replaced image',
    () async {
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 32, 32),
        ui.Paint()..color = const ui.Color(0xffff0000),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(32, 32);
      final replacement = await picture.toImage(64, 64);
      picture.dispose();
      addTearDown(image.dispose);
      addTearDown(replacement.dispose);
      final images = {'fx-meteor': image}, atlas = EffectAtlas(images);
      final first = atlas.source('fx-meteor', 5)!;
      expect(first, const ui.Rect.fromLTWH(9, 9, 6, 6));
      expect(identical(first, atlas.source('fx-meteor', 5)), true);
      images['fx-meteor'] = replacement;
      expect(
        atlas.source('fx-meteor', 5),
        const ui.Rect.fromLTWH(17, 17, 14, 14),
      );
    },
  );

  test('faded FX paint never leaks opacity into the next effect', () async {
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 16, 16),
      ui.Paint()..color = const ui.Color(0xffff0000),
    );
    final picture = recorder.endRecording(),
        image = await picture.toImage(16, 16);
    picture.dispose();
    addTearDown(image.dispose);
    final atlas = EffectAtlas({'fx-meteor': image});
    final bytes = await raster((canvas) {
      atlas.draw(
        canvas,
        'fx-meteor',
        0,
        const ui.Rect.fromLTWH(10, 10, 10, 10),
        opacity: .25,
      );
      atlas.draw(
        canvas,
        'fx-meteor',
        0,
        const ui.Rect.fromLTWH(30, 10, 10, 10),
      );
    });
    expect(bytes[(15 * 160 + 15) * 4 + 3], closeTo(64, 1));
    expect(bytes[(15 * 160 + 35) * 4 + 3], 255);
  });

  test(
    'offscreen drawing is skipped, visible effect edges remain and time still advances',
    () {
      final game = _CameraGame();
      final s = inCombatField(Adventure(GameArt()))..start(game);
      addTearDown(s.dispose);
      final effect = _CountingBurst(
        s,
        SpellClip.meteorImpact,
        const ui.Offset(6000, 4200),
        radius: 175,
      )..gameRef = game;
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      effect.renderTree(canvas);
      expect(effect.draws, 0);
      effect.update(1 / 30);
      expect(effect.age, closeTo(1 / 30, .00001));
      // The center is outside the viewport, but the expanding blast is visible.
      game.camera.visibleRect = const ui.Rect.fromLTWH(5750, 4180, 80, 80);
      effect.renderTree(canvas);
      expect(effect.draws, 1);
      s.pause();
      effect.update(1 / 30);
      expect(effect.age, closeTo(1 / 30, .00001));
      recorder.endRecording().dispose();
    },
  );

  test('an offscreen meteor keeps its one impact and damage event', () {
    final game = _CameraGame();
    final s = inCombatField(Adventure(GameArt()))..start(game);
    addTearDown(s.dispose);
    s.mobs.clear();
    final mob = s.spawnEnemy('goblin', const ui.Offset(6100, 4200))!;
    final before = mob.life.value;
    final meteor = MeteorFall(s, s.hero.body.center, mob.body.center, 5)
      ..gameRef = game;
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    for (var i = 0; i < 36; i++) {
      meteor.renderTree(canvas);
      meteor.update(1 / 30);
    }
    recorder.endRecording().dispose();
    expect(mob.life.value, before - 5);
    expect(
      game.added.whereType<SpellBurst>().where(
        (e) => e.clip == SpellClip.meteorImpact,
      ),
      hasLength(1),
    );
  });

  test(
    'flame and explosion details evolve at every 30Hz sample between atlas frames',
    () async {
      final flame = FirePlume();
      for (final impact in [false, true]) {
        final hashes = <int>{};
        for (var i = 0; i < 16; i++) {
          final time = i / 30;
          final bytes = await raster((canvas) {
            if (impact) {
              flame.impact(canvas, const ui.Offset(80, 100), time / .56, 70);
            } else {
              flame.flight(
                canvas,
                const ui.Offset(100, 80),
                .45,
                time,
                radius: 30,
              );
            }
          });
          expect(bytes.any((byte) => byte != 0), true);
          hashes.add(Object.hashAll(bytes));
        }
        expect(
          hashes,
          hasLength(16),
          reason: 'continuous geometry must not hold on the atlas frame',
        );
      }
    },
  );
}

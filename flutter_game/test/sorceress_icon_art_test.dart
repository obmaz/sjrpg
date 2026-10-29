import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/barbarian_icon_art.dart';
import 'package:guardian_new/d1_icon_art.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/rpg_widgets.dart';
import 'package:guardian_new/skill_tree_layout.dart';
import 'package:guardian_new/sorceress_icon_art.dart';
import 'package:guardian_new/world_model.dart';

Future<ui.Image> _raster(void Function(ui.Canvas) paint, int side) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(side, side);
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> _pixels(ui.Image image) async => (await image.toByteData(
  format: ui.ImageByteFormat.rawRgba,
))!.buffer.asUint8List();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canonical thirty mage skills map to a separate generated atlas', () {
    expect(SorceressIconArt.ids.toSet(), mageTreeIds);
    expect(SorceressIconArt.ids.toSet().length, 30);
    expect(
      SorceressIconArt.ids.map(skillEffect),
      List.generate(30, (i) => 200 + i),
    );
    expect(SorceressIconArt.ids.map(skillIcon).toSet().length, 30);
    expect(skillEffect('bash'), BarbarianIconArt.effectFor('bash'));
    expect(skillEffect('shadowAssault'), 36);
    expect(SorceressIconArt.containsEffect(199), false);
    expect(SorceressIconArt.containsEffect(230), false);
    expect(SorceressIconArt.effectFor('sorceressAttack'), null);
  });

  test(
    'all thirty real paintings survive small square and circular rasterization',
    () async {
      final data = await rootBundle.load('assets/images/sorceress-skills.webp');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final atlas = (await codec.getNextFrame()).image;
      codec.dispose();
      final art = GameArt()..images[SorceressIconArt.imageKey] = atlas;
      addTearDown(art.dispose);
      expect(atlas.width * atlas.height * 4, lessThan(6 * 1024 * 1024));
      final signatures = <String>{};
      for (var i = 0; i < 30; i++) {
        final source = SorceressIconArt.source(atlas, i)!;
        final cell = ui.Rect.fromLTWH(i % 6 * 224, i ~/ 6 * 224, 224, 224);
        expect(cell.contains(source.topLeft), true);
        expect(cell.contains(source.bottomRight), true);
        for (final framed in [true, false]) {
          final image = await _raster(
            (canvas) => EffectIconPainter(
              art,
              200 + i,
              framed: framed,
            ).paint(canvas, const ui.Size.square(48)),
            48,
          );
          try {
            final pixels = await _pixels(image);
            var visible = 0;
            for (var y = 0; y < 48; y++) {
              for (var x = 0; x < 48; x++) {
                final alpha = pixels[(y * 48 + x) * 4 + 3];
                if (alpha > 128) visible++;
                if (!framed &&
                    (ui.Offset(x + .5, y + .5) - const ui.Offset(24, 24))
                            .distance >
                        25) {
                  expect(
                    alpha,
                    0,
                    reason: '${SorceressIconArt.ids[i]} circular corner',
                  );
                }
              }
            }
            expect(visible, greaterThan(1200), reason: SorceressIconArt.ids[i]);
            if (framed) {
              signatures.add(String.fromCharCodes(pixels));
            } else {
              expect(pixels[3], 0);
            }
          } finally {
            image.dispose();
          }
        }
      }
      expect(
        signatures.length,
        30,
        reason: 'no repeated or blank cell substitutes',
      );
      expect(SorceressIconArt.source(atlas, -1), null);
      expect(SorceressIconArt.source(atlas, 30), null);
    },
  );

  test(
    'battle crop removes plaque edges without sampling a neighboring skill',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // Source bounds are measured from the generated plaques. A diagnostic sheet
      // gives every plaque a distinct center and a common thick bronze border.
      final emptyPicture = ui.PictureRecorder();
      ui.Canvas(emptyPicture);
      final p = emptyPicture.endRecording();
      final dimensions = await p.toImage(1344, 1120);
      p.dispose();
      for (var i = 0; i < 30; i++) {
        final source = SorceressIconArt.source(dimensions, i)!;
        canvas.drawRect(source, ui.Paint()..color = const ui.Color(0xffffbb33));
        canvas.drawRect(
          source.deflate(15),
          ui.Paint()..color = ui.Color.fromARGB(255, 20 + i * 6, 80, 120),
        );
      }
      dimensions.dispose();
      final picture = recorder.endRecording();
      final atlas = await picture.toImage(1344, 1120);
      picture.dispose();
      final art = GameArt()..images[SorceressIconArt.imageKey] = atlas;
      addTearDown(art.dispose);
      for (var i = 0; i < 30; i++) {
        for (final framed in [true, false]) {
          final image = await _raster(
            (canvas) => EffectIconPainter(
              art,
              200 + i,
              framed: framed,
            ).paint(canvas, const ui.Size.square(64)),
            64,
          );
          try {
            final bytes = await _pixels(image);
            final center = (32 * 64 + 32) * 4;
            expect(bytes.sublist(center, center + 4), [
              20 + i * 6,
              80,
              120,
              255,
            ]);
            var borderPixels = 0;
            for (var j = 0; j < bytes.length; j += 4) {
              if (bytes[j] == 255 &&
                  bytes[j + 1] == 187 &&
                  bytes[j + 2] == 51 &&
                  bytes[j + 3] == 255) {
                borderPixels++;
              }
            }
            expect(
              borderPixels,
              framed ? greaterThan(0) : 0,
              reason: SorceressIconArt.ids[i],
            );
          } finally {
            image.dispose();
          }
        }
      }
    },
  );

  test(
    'menu and warrior defer mage atlas; mage stage decodes and retains it',
    () async {
      final art = await GameArt.loadMenu();
      addTearDown(art.dispose);
      expect(art.images.containsKey(D1IconArt.mageKey), false);
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      expect(art.images.containsKey(D1IconArt.mageKey), false);
      expect(art.images.containsKey(D1IconArt.warriorKey), true);
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.mage);
      final atlas = art.images[D1IconArt.mageKey];
      expect(atlas, isNotNull);
      await art.ensureStage(WorldStage.sands, heroClass: HeroClass.mage);
      expect(identical(atlas, art.images[D1IconArt.mageKey]), true);
    },
  );
}

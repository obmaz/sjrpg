import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/quest_scenery.dart';
import 'package:guardian_new/world_model.dart';

Future<Uint8List> _pixels(
  void Function(ui.Canvas canvas) draw,
  int width,
  int height,
) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording(),
      image = await picture.toImage(width, height);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all 26 objectives have independent compositions and only roots uses the generated scene',
    () {
      final all = [
        for (final stage in WorldStage.values)
          ...QuestScenery(AdventureWorld(stage: stage)).patches,
      ];
      expect(all.length, 26);
      expect(all.map((p) => p.composition).toSet().length, all.length);
      expect(all.where((p) => p.usesDedicatedImage).map((p) => p.siteId), [
        'roots',
      ]);
    },
  );

  test(
    'every chapter landscapes its actual mandatory sites without changing collision',
    () {
      for (final stage in WorldStage.values) {
        final world = AdventureWorld(stage: stage),
            scenery = QuestScenery(AdventureWorld(stage: stage));
        expect(scenery.patches.length, world.sites.length);
        for (final (index, patch) in scenery.patches.indexed) {
          final site = world.sites[index];
          expect(patch.siteId, site.id);
          expect(patch.center, site.at);
          expect(patch.size.width, inInclusiveRange(800, 1600));
          expect(patch.size.height, inInclusiveRange(800, 1600));
          final body = ui.Rect.fromCenter(
            center: site.at + const ui.Offset(0, 75),
            width: 28,
            height: 24,
          );
          final blocked = world.blocked(body),
              cache = TerrainArt(world, GameArt());
          expect(cache.questScenery.patches[index].bounds, patch.bounds);
          cache.dispose();
          expect(world.blocked(body), blocked);
        }
      }
    },
  );
  test(
    'large ground patches remain visually continuous across sector boundaries and culled outside their bounds',
    () async {
      for (final stage in WorldStage.values) {
        final scenery = QuestScenery(AdventureWorld(stage: stage));
        final patch = scenery.patches.firstWhere((p) => !p.usesDedicatedImage);
        final region = ui.Rect.fromCenter(
          center: patch.center,
          width: 1024,
          height: 1024,
        );
        final direct = await _pixels(
          (c) {
            c.translate(-region.left, -region.top);
            scenery.paintGround(c, region);
          },
          1024,
          1024,
        );
        final sectors = await _pixels(
          (c) {
            c.translate(-region.left, -region.top);
            for (
              var row = (region.top / 512).floor();
              row <= (region.bottom / 512).floor();
              row++
            ) {
              for (
                var col = (region.left / 512).floor();
                col <= (region.right / 512).floor();
                col++
              ) {
                final bounds = ui.Rect.fromLTWH(
                  col * 512.0,
                  row * 512.0,
                  512,
                  512,
                );
                c.save();
                c.clipRect(bounds, doAntiAlias: false);
                scenery.paintGround(c, bounds);
                c.restore();
              }
            }
          },
          1024,
          1024,
        );
        // Native stroked-path clipping changes fringe coverage slightly; the
        // opaque cached terrain regression below checks actual visible seams.
        var totalChannelDifference = 0.0;
        for (var i = 0; i < direct.length; i += 4) {
          for (var channel = 0; channel < 4; channel++) {
            // rawRgba is unpremultiplied: tiny alpha differences magnify RGB
            // errors in invisible fringe pixels. Compare visible contribution.
            final a = channel == 3
                ? sectors[i + 3].toDouble()
                : sectors[i + channel] * sectors[i + 3] / 255;
            final b = channel == 3
                ? direct[i + 3].toDouble()
                : direct[i + channel] * direct[i + 3] / 255;
            final difference = (a - b).abs();
            totalChannelDifference += difference;
          }
        }
        expect(
          totalChannelDifference / direct.length,
          lessThan(.01),
          reason: stage.name,
        );
        final outside = await _pixels(
          (c) => scenery.paintGround(c, const ui.Rect.fromLTWH(0, 0, 32, 32)),
          32,
          32,
        );
        expect(outside.every((value) => value == 0), true);
      }
    },
  );
  test(
    'terrain picture cache stays opaque across fractional-scale sector boundaries',
    () async {
      final art = await GameArt.loadMenu();
      addTearDown(art.dispose);
      expect(art.images.containsKey('quest-root-garden'), false);
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      expect(art.images.containsKey('quest-root-garden'), true);
      final world = AdventureWorld(),
          terrain = TerrainArt(AdventureWorld(), art);
      addTearDown(terrain.dispose);
      final view = ui.Rect.fromCenter(
        center: world.sites.first.at,
        width: 1000,
        height: 1000,
      );
      final pixels = await _pixels(
        (canvas) {
          canvas.scale(.8);
          canvas.translate(-view.left, -view.top);
          terrain.render(canvas, view);
        },
        800,
        800,
      );
      var transparent = 0;
      for (var at = 3; at < pixels.length; at += 4) {
        if (pixels[at] < 255) transparent++;
      }
      expect(
        transparent,
        0,
        reason:
            'neighboring sector clips must not double-antialias over transparent pixels',
      );
    },
  );
}

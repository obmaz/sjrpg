import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/quest_scenery.dart';
import 'package:guardian_new/world_model.dart';

const _colors = [
  ui.Color(0xff5dba71),
  ui.Color(0xff54a5d6),
  ui.Color(0xffd6a34e),
  ui.Color(0xffda9869),
  ui.Color(0xffa69285),
  ui.Color(0xff8075ce),
];
Future<ui.Image> _atlas() async {
  final recorder = ui.PictureRecorder(),
      c = ui.Canvas(recorder),
      paint = ui.Paint();
  for (var index = 0; index < 6; index++) {
    final center = ui.Offset(index % 3 * 64 + 32, index ~/ 3 * 64 + 32);
    for (var radius = 30; radius > 0; radius--) {
      c.drawCircle(
        center,
        radius.toDouble(),
        paint
          ..color = _colors[index].withAlpha(
            ((31 - radius) * 12).clamp(0, 255),
          ),
      );
    }
    c.drawRect(
      ui.Rect.fromCenter(
        center: center + const ui.Offset(5, -9),
        width: 5,
        height: 11,
      ),
      paint..color = const ui.Color(0x887ae7d2),
    );
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(192, 128);
  } finally {
    picture.dispose();
  }
}

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
          expect(patch.cell, inInclusiveRange(0, 5));
          expect(patch.size.width, inInclusiveRange(800, 1000));
          expect(patch.size.height, inInclusiveRange(800, 1000));
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
        if (stage == WorldStage.forest) {
          expect(scenery.patches.map((p) => p.cell), [0, 1, 2]);
        }
        if (stage == WorldStage.future || stage == WorldStage.foundry) {
          expect(scenery.patches.every((p) => p.cell == 5), true);
        }
      }
    },
  );
  test(
    'large ground patches are identical across sector boundaries and culled outside their bounds',
    () async {
      final atlas = await _atlas();
      addTearDown(atlas.dispose);
      for (final stage in WorldStage.values) {
        final scenery = QuestScenery(AdventureWorld(stage: stage)),
            patch = QuestScenery(AdventureWorld(stage: stage)).patches.first;
        final region = ui.Rect.fromCenter(
          center: patch.center,
          width: 1024,
          height: 1024,
        );
        final direct = await _pixels(
          (c) {
            c.translate(-region.left, -region.top);
            scenery.paint(c, atlas, region);
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
                scenery.paint(c, atlas, bounds);
                c.restore();
              }
            }
          },
          1024,
          1024,
        );
        expect(sectors, direct, reason: stage.name);
        final at = (512 * 1024 + 512) * 4, color = _colors[patch.cell];
        expect(
          direct.sublist(at, at + 4),
          [
            color.r,
            color.g,
            color.b,
            color.a,
          ].map((v) => (v * 255).round()).toList(),
        );
        final outside = await _pixels(
          (c) => scenery.paint(c, atlas, const ui.Rect.fromLTWH(0, 0, 32, 32)),
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
      expect(art.images.containsKey('quest-landscapes'), false);
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      expect(art.images.containsKey('quest-landscapes'), true);
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

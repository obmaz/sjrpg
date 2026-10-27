import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/crushing_blow_vfx.dart';
import 'package:guardian_new/enemy_catalog.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

Future<Uint8List> _worldPixels(GameArt art, AdventureWorld world) async {
  final terrain = TerrainArt(world, art);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  ui.Picture? picture;
  try {
    final col = (world.spawn.dx / 512).floor();
    final row = (world.spawn.dy / 512).floor();
    canvas.save();
    canvas.translate(-col * 512.0, -row * 512.0);
    canvas.drawPicture(terrain.sector(col, row));
    canvas.restore();

    final actors = <String>{
      world.stage.bossActor,
      'merchant',
      'villager',
      world.stage.usesCityArt ? 'drone' : 'viper',
      for (final path in TimePath.values)
        if (chapterContract(world.stage, path) case final contract?)
          contract.actor,
    };
    for (final sand in [false, true]) {
      for (final wooded in [false, true]) {
        for (final ruins in [false, true]) {
          actors.addAll(
            biomeEnemies(world.stage, sand: sand, wooded: wooded, ruins: ruins),
          );
        }
      }
    }
    if (world.stage == WorldStage.sands) {
      actors.addAll(timeQuestGivers.map((giver) => giver.actor));
    }
    var index = 0;
    for (final actor in actors) {
      art.actor(
        canvas,
        actor,
        ui.Offset(50 + index % 9 * 110, 650 + index ~/ 9 * 120),
        1,
        0,
        enemyCatalog[actor]?.renderHeight ?? 70,
      );
      index++;
    }

    final kinds = <String>{};
    index = 0;
    for (final prop in [...world.campProps, ...world.props]) {
      if (!kinds.add(prop.kind)) continue;
      canvas.save();
      canvas.translate(600 + index % 3 * 145, 180 + index ~/ 3 * 180);
      canvas.scale(.5);
      final feet = prop.body.bottomCenter;
      canvas.translate(-feet.dx, -feet.dy);
      art.prop(canvas, prop);
      canvas.restore();
      index++;
    }
    for (final (index, site) in world.sites.indexed) {
      final feet = ui.Offset(50 + index * 110, 1000);
      if (world.stage.usesCityArt) {
        art.cityProp(canvas, site.artIndex, feet, 90);
      } else {
        art.landmark(
          canvas,
          site.artIndex,
          feet,
          90,
          themed: world.stage != WorldStage.forest,
        );
      }
    }
    picture = recorder.endRecording();
    final image = await picture.toImage(1100, 1050);
    try {
      return (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    if (recorder.isRecording) recorder.endRecording().dispose();
    picture?.dispose();
    terrain.dispose();
  }
}

Future<Uint8List> _pixels(
  void Function(ui.Canvas) paint,
  int width,
  int height,
) async {
  final recorder = ui.PictureRecorder();
  ui.Picture? picture;
  try {
    paint(ui.Canvas(recorder));
    picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      return (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    if (recorder.isRecording) recorder.endRecording().dispose();
    picture?.dispose();
  }
}

Future<Uint8List> _poses(GameArt art, String kind) => _pixels(
  (canvas) {
    for (var direction = 0; direction < 8; direction++) {
      for (var phase = 0; phase < 2; phase++) {
        art.actor(
          canvas,
          kind,
          ui.Offset(65 + direction * 130, 100 + phase * 120),
          direction * math.pi / 4,
          phase,
          enemyCatalog[kind]!.renderHeight,
        );
      }
    }
  },
  1040,
  240,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt full;
  setUpAll(() async {
    full = await GameArt.load();
  });
  tearDownAll(() {
    full.dispose();
  });
  for (final stage in WorldStage.values) {
    test(
      '${stage.name} keeps full-loader terrain, encounter, scenery and landmark pixels',
      () async {
        final staged = await GameArt.loadMenu();
        addTearDown(staged.dispose);
        await staged.ensureStage(stage, heroClass: HeroClass.warrior);
        final world = AdventureWorld(stage: stage);
        final expected = await _worldPixels(full, world);
        final actual = await _worldPixels(staged, world);
        expect(
          listEquals(actual, expected),
          isTrue,
          reason: '${stage.name} must preserve its actual chapter artwork',
        );
      },
    );
  }

  for (final (stage, kind) in const [
    (WorldStage.tombs, 'bonehound'),
    (WorldStage.foundry, 'clockwork-spider'),
    (WorldStage.convergence, 'crystal-beetle'),
  ]) {
    test(
      '$kind keeps both poses in every direction on a fresh staged entry',
      () async {
        final staged = await GameArt.loadMenu();
        addTearDown(staged.dispose);
        await staged.ensureStage(stage, heroClass: HeroClass.warrior);
        final expected = await _poses(full, kind);
        final actual = await _poses(staged, kind);
        expect(listEquals(actual, expected), isTrue);
        for (var direction = 0; direction < 8; direction++) {
          for (var phase = 0; phase < 2; phase++) {
            var visible = 0;
            for (var y = phase * 120; y < (phase + 1) * 120; y++) {
              for (var x = direction * 130; x < (direction + 1) * 130; x++) {
                if (actual[(y * 1040 + x) * 4 + 3] > 0) visible++;
              }
            }
            expect(
              visible,
              greaterThan(0),
              reason: '$kind direction $direction pose $phase',
            );
          }
        }
      },
    );
  }

  test(
    'staged entry retains the crushing impact atlas through its full timeline',
    () async {
      final staged = await GameArt.loadMenu();
      addTearDown(staged.dispose);
      await staged.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      for (final frame in [0, 2, 7, 15]) {
        Future<Uint8List> impact(GameArt art) => _pixels(
          (canvas) {
            paintCrushingFrame(
              art,
              canvas,
              const ui.Offset(200, 300),
              frame,
              rank: 3,
              charge: 1,
              bearing: 0,
            );
          },
          400,
          420,
        );
        final expected = await impact(full);
        final actual = await impact(staged);
        expect(
          actual.any((value) => value != 0),
          isTrue,
          reason: 'impact frame $frame must paint',
        );
        expect(
          listEquals(actual, expected),
          isTrue,
          reason: 'impact frame $frame',
        );
      }
    },
  );
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/field_palettes.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

Future<Uint8List> _paint(
  Adventure session, {
  required bool round,
  String? proof,
}) async {
  final dimensions = round ? const ui.Size(85, 85) : const ui.Size(1200, 900);
  final recorder = ui.PictureRecorder();
  MapPainter(session, round: round).paint(ui.Canvas(recorder), dimensions);
  final picture = recorder.endRecording(),
      image = await picture.toImage(
        dimensions.width.toInt(),
        dimensions.height.toInt(),
      );
  picture.dispose();
  try {
    final output = Platform.environment['SJRPG_FIELD_MAP_PROOF_DIR'];
    if (proof != null && output != null) {
      final directory = Directory(output)..createSync(recursive: true);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${directory.path}/$proof.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    }
    return Uint8List.fromList(
      (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List(),
    );
  } finally {
    image.dispose();
  }
}

Future<Uint8List> _ground(Adventure session, List<ui.Color> colors) async {
  final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
  canvas.scale(1200 / worldSize.width, 900 / worldSize.height);
  canvas.drawRect(
    ui.Offset.zero & worldSize,
    ui.Paint()..color = session.world.stage.mapColor,
  );
  session.terrain.mapPlan.paint(
    canvas,
    ui.Offset.zero & worldSize,
    unitsPerPixel: worldSize.width / 1200,
  );
  final picture = recorder.endRecording(),
      image = await picture.toImage(1200, 900);
  picture.dispose();
  try {
    return Uint8List.fromList(
      (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List(),
    );
  } finally {
    image.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('Guardian', 'assets-fonts/NanumGothic-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });
  for (final stage in WorldStage.values) {
    test(
      '${stage.name} both maps share actual terrain geometry in a flat restrained palette',
      () async {
        final art = await GameArt.loadMenu();
        await art.ensureStage(stage, heroClass: HeroClass.warrior);
        final current = Adventure(art, stage: stage)..start(TestGame());
        addTearDown(current.dispose);
        addTearDown(art.dispose);
        final original = fieldPalettes[stage.name]!;
        final flat = await _paint(current, round: true);
        final expanded = await _paint(current, round: false, proof: stage.name);
        final ground = await _ground(current, original);
        var samples = 0, matches = 0;
        final world = current.world;
        for (var y = 90; y < 810; y += 37) {
          for (var x = 90; x < 1110; x += 37) {
            final point = ui.Offset(
              x / 1200 * worldSize.width,
              y / 900 * worldSize.height,
            );
            if (world.settlement.inflate(1000).contains(point) ||
                world.trails.any((trail) => trail.near(point, 160)) ||
                world.lakes.any(
                  (lake) => lake.bounds.inflate(220).contains(point),
                ) ||
                world.river.bounds.inflate(220).contains(point) ||
                world.sites.any((site) => (site.at - point).distance < 2000)) {
              continue;
            }
            final at = (y * 1200 + x) * 4;
            samples++;
            if (listEquals(
              expanded.sublist(at, at + 4),
              ground.sublist(at, at + 4),
            )) {
              matches++;
            }
          }
        }
        expect(samples, greaterThan(30));
        expect(
          matches / samples,
          greaterThan(.98),
          reason:
              'expanded terrain must follow the same quiet plan as the compact map',
        );
        await _ground(
          current,
          List.filled(
            fieldPaletteColumns * fieldPaletteRows,
            const ui.Color(0xffcd288e),
          ),
        );
        expect(
          listEquals(await _paint(current, round: true), flat),
          true,
          reason:
              'painting field palettes must not alter compact minimap geometry or colors',
        );
      },
    );
  }
}

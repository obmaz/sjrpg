import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/effect_atlas.dart';
import 'package:guardian_new/game_art.dart';

Future<ui.Image> _raster(void Function(ui.Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(128, 128);
  picture.dispose();
  return image;
}

// The UI's combat icons use square cells based on the image width, independently
// of EffectAtlas's row count. The real sheet has eight icons in two rows.
void _paintReference(
  ui.Image sheet,
  ui.Canvas canvas,
  int index,
  double side, {
  double opacity = 1,
}) {
  final cell = sheet.width / 4;
  canvas.drawImageRect(
    sheet,
    ui.Rect.fromLTWH(index % 4 * cell, index ~/ 4 * cell, cell, cell),
    ui.Rect.fromCenter(
      center: const ui.Offset(64, 64),
      width: side,
      height: side,
    ),
    ui.Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity),
  );
}

Future<int> _differentBytes(ui.Image actual, ui.Image expected) async {
  final a = (await actual.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final e = (await expected.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  return [
    for (var i = 0; i < a.length; i++)
      if (a[i] != e[i]) i,
  ].length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image sheet;
  setUpAll(() async {
    final data = await rootBundle.load('assets/images/combat-fx.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    sheet = (await codec.getNextFrame()).image;
    codec.dispose();
  });
  tearDownAll(() => sheet.dispose());

  Adventure session() {
    final s = Adventure(GameArt()..images['combat-fx'] = sheet);
    addTearDown(s.dispose);
    return s;
  }

  test(
    'all eight combat crops match the real square icons without bleed',
    () async {
      final s = session();
      expect(sheet.width, sheet.height * 2);
      for (var index = 0; index < 8; index++) {
        final actual = await _raster(
          (c) => paintCombatEffect(
            s,
            c,
            const ui.Offset(64, 64),
            index,
            const ui.Size.square(52),
          ),
        );
        final expected = await _raster(
          (c) => _paintReference(sheet, c, index, 52),
        );
        expect(
          await _differentBytes(actual, expected),
          0,
          reason: 'combat cell $index, including transparent destination edges',
        );
        actual.dispose();
        expected.dispose();
      }
    },
  );

  test(
    'warm shares the two-row combat regions and preserves other FX grids',
    () {
      final atlas = EffectAtlas({
        'combat-fx': sheet,
        'fx-meteor': sheet,
        'fx-steel-whirlwind': sheet,
      });
      final cell = sheet.width / 4;
      final combat = [
        for (var i = 0; i < 8; i++)
          atlas.source('combat-fx', i, rows: 2, inset: 0)!,
      ];
      final meteor = atlas.source('fx-meteor', 15)!;
      final whirlwind = atlas.source('fx-steel-whirlwind', 35, rows: 9)!;
      atlas.warm();
      for (var i = 0; i < 8; i++) {
        final source = atlas.source('combat-fx', i, rows: 2, inset: 0)!;
        expect(identical(source, combat[i]), true);
        expect(
          source,
          ui.Rect.fromLTWH(i % 4 * cell, i ~/ 4 * cell, cell, cell),
        );
        expect(
          (ui.Offset.zero &
                  ui.Size(sheet.width.toDouble(), sheet.height.toDouble()))
              .contains(source.topLeft),
          true,
        );
        expect(source.right, lessThanOrEqualTo(sheet.width));
        expect(source.bottom, lessThanOrEqualTo(sheet.height));
      }
      expect(identical(meteor, atlas.source('fx-meteor', 15)), true);
      expect(
        identical(whirlwind, atlas.source('fx-steel-whirlwind', 35, rows: 9)),
        true,
      );
    },
  );

  test('live sword and purple effects retain their size and fade', () async {
    final s = session();
    for (final (index, side) in [(7, 52.0), (3, 40.0), (3, 76.0)]) {
      // Draw faded then opaque through the shared paint to catch alpha leakage.
      for (final opacity in [.25, 1.0]) {
        final actual = await _raster(
          (c) => paintCombatEffect(
            s,
            c,
            const ui.Offset(64, 64),
            index,
            ui.Size.square(side),
            opacity: opacity,
          ),
        );
        final expected = await _raster(
          (c) => _paintReference(sheet, c, index, side, opacity: opacity),
        );
        expect(
          await _differentBytes(actual, expected),
          0,
          reason: 'cell $index at ${side}px with opacity $opacity',
        );
        actual.dispose();
        expected.dispose();
      }
    }
  });

  test('optional native combat atlas proof', () async {
    final directory = Platform.environment['COMBAT_ATLAS_PROOF_DIR'];
    if (directory == null) return;
    await Directory(directory).create(recursive: true);
    final s = session();
    for (final (index, side) in [(7, 52.0), (3, 40.0), (3, 76.0)]) {
      for (final reference in [false, true]) {
        final image = await _raster((c) {
          c.drawColor(const ui.Color(0xff18211b), ui.BlendMode.src);
          if (reference) {
            _paintReference(sheet, c, index, side);
          } else {
            paintCombatEffect(
              s,
              c,
              const ui.Offset(64, 64),
              index,
              ui.Size.square(side),
            );
          }
        });
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '$directory/combat-$index-${side.toInt()}-${reference ? 'reference' : 'actual'}.png',
        ).writeAsBytes(png.buffer.asUint8List());
        image.dispose();
      }
    }
  });
}

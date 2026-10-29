import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/ranked_vfx.dart';
import 'package:guardian_new/rpg_widgets.dart';

Future<ui.Image> _decodeLegacyImage(String name) async {
  final directory = name == 'popup-frame' ? '../assets' : 'art';
  final data = await File('$directory/$name.webp').readAsBytes();
  final codec = await ui.instantiateImageCodec(data);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> _pixels(ui.Image image) async {
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Future<Uint8List> _whirlwindPixels(GameArt art, int rank, double phase) async {
  final recorder = ui.PictureRecorder();
  paintSteelWhirlwind(
    art,
    ui.Canvas(recorder),
    const ui.Offset(210, 270),
    phase,
    rank,
  );
  final picture = recorder.endRecording();
  try {
    return await _pixels(await picture.toImage(420, 440));
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'compact panels and current whirlwind keep their pixels without legacy textures',
    (tester) async {
      final art = (await tester.runAsync(GameArt.load))!;
      final ownedImages = art.images.values.toSet();
      addTearDown(() {
        for (final shader in art.materials) {
          shader.dispose();
        }
        for (final image in ownedImages) {
          image.dispose();
        }
      });

      Future<Uint8List> panelPixels() async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 320,
                  height: 240,
                  child: FramedSurface(
                    art: art,
                    compact: true,
                    child: const Text('Adventure panel'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        return (await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          return _pixels(await boundary.toImage());
        }))!;
      }

      final panelWithoutLegacy = await panelPixels();
      final effectsWithoutLegacy = <(int, double, Uint8List)>[];
      for (final rank in [1, 3, 5]) {
        for (final phase in [.1, .22, .5, .8]) {
          final pixels = (await tester.runAsync(
            () => _whirlwindPixels(art, rank, phase),
          ))!;
          expect(
            pixels.any((value) => value != 0),
            isTrue,
            reason: 'the current whirlwind must paint visible pixels',
          );
          effectsWithoutLegacy.add((rank, phase, pixels));
        }
      }

      // Restore the old sources to compare the actual rendering paths against
      // their output before those unused decodes were removed from startup.
      for (final name in ['popup-frame', 'fx-whirlwind']) {
        final image = (await tester.runAsync(() => _decodeLegacyImage(name)))!;
        ownedImages.add(image);
        art.images[name] = image;
      }
      expect(await panelPixels(), orderedEquals(panelWithoutLegacy));
      for (final (rank, phase, before) in effectsWithoutLegacy) {
        final after = await tester.runAsync(
          () => _whirlwindPixels(art, rank, phase),
        );
        expect(
          after,
          orderedEquals(before),
          reason:
              'rank $rank at phase $phase must preserve its rendered pixels',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'both classes share width, height and foot anchors in every presentation',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(1, 1, 8, 18),
        ui.Paint()..color = const ui.Color(0xffb59163),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(10, 20);
      picture.dispose();
      addTearDown(image.dispose);
      Map<String, Object> record(int count, {int groups = 1}) => {
        'frames': List.filled(count, [0, 0, 10, 20]),
        'feet': List.filled(count, [5, 20]),
        'sizes': List.generate(groups, (_) => [10, 20]),
        'anchorMode': 'projected-origin',
      };
      final art = GameArt()
        ..actors = {
          for (final role in [
            'hero',
            'mage',
            'hero-attack',
            'hero-backhand',
            'hero-cleave',
            'mage-cast',
          ])
            role: record(32),
          'roll': record(64, groups: 2),
        };
      for (final role in art.actors.keys) {
        art.images['actors-$role'] = image;
      }
      Future<List<int>> pixels(
        bool mage, {
        bool attack = false,
        bool roll = false,
        int combo = 0,
        double height = 60,
      }) async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        if (roll) {
          art.roll(canvas, const ui.Offset(60, 90), 0, 2, mage: mage);
        } else {
          art.actor(
            canvas,
            mage ? 'mage' : 'hero',
            const ui.Offset(60, 90),
            0,
            1,
            height,
            attack: attack,
            comboPose: combo,
            moving: !attack,
          );
        }
        final picture = recorder.endRecording();
        final rendered = await picture.toImage(120, 100);
        picture.dispose();
        final data = (await rendered.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List().toList();
        rendered.dispose();
        return data;
      }

      for (final height in [60.0, 46.0]) {
        expect(
          listEquals(
            await pixels(false, height: height),
            await pixels(true, height: height),
          ),
          true,
          reason: 'running and mounted rider sizes share the same transform',
        );
      }
      for (var combo = 0; combo < 3; combo++) {
        expect(
          listEquals(
            await pixels(false, attack: true, combo: combo),
            await pixels(true, attack: true),
          ),
          true,
          reason:
              'warrior attacks and mage casting retain the same body proportions',
        );
      }
      expect(
        listEquals(
          await pixels(false, roll: true),
          await pixels(true, roll: true),
        ),
        true,
      );
    },
  );
}

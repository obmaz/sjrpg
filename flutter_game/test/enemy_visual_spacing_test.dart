import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'smaller enemies with reserved spawn space overlap less on screen',
    () async {
      final codec = await ui.instantiateImageCodec(
        await File('art/actors-cinematic-goblin.webp').readAsBytes(),
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      final art = GameArt()
        ..actors = {
          'cinematic-goblin': jsonDecode(
            await File(
              'art/actors-cinematic-goblin-bounds.json',
            ).readAsString(),
          ),
        }
        ..images['actors-cinematic-goblin'] = image;
      addTearDown(art.dispose);
      Future<List<int>> raster(double x, double height) async {
        final recorder = ui.PictureRecorder();
        art.actor(
          ui.Canvas(recorder),
          'goblin',
          ui.Offset(x, 135),
          math.pi / 2,
          0,
          height,
        );
        final picture = recorder.endRecording();
        final output = await picture.toImage(240, 160);
        picture.dispose();
        final bytes = (await output.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List().toList();
        output.dispose();
        return bytes;
      }

      Future<int> overlap(double gap, double height) async {
        final a = await raster(90, height), b = await raster(90 + gap, height);
        var count = 0;
        for (var i = 3; i < a.length; i += 4) {
          if (a[i] > 96 && b[i] > 96) count++;
        }
        return count;
      }

      final old = await overlap(44, 62);
      final adjusted = await overlap(44 * 1.2, 62 * HuntEnemy.visualScale);
      expect(
        old,
        greaterThan(0),
        reason: 'the original silhouettes actually overlap',
      );
      expect(
        adjusted,
        lessThan(old ~/ 2),
        reason: 'the new spawn spacing must visibly separate the artwork',
      );
    },
  );
}

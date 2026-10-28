import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/mount_panel.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'merchant portraits use loaded dedicated mount art rather than fallback icons',
    () async {
      final art = await GameArt.load();
      addTearDown(art.dispose);
      expect(art.images.containsKey('actors-vehicles'), false);
      for (final def in travelMountDefs.take(4)) {
        expect(art.images.containsKey('actors-${def.artKey}'), true);
        Future<List<int>> pixels(GameArt source) async {
          final recorder = ui.PictureRecorder();
          MountPortraitPainter(
            source,
            def,
          ).paint(Canvas(recorder), const Size(80, 80));
          final picture = recorder.endRecording(),
              image = picture.toImageSync(80, 80);
          final bytes = (await image.toByteData())!.buffer
              .asUint8List()
              .toList();
          image.dispose();
          picture.dispose();
          return bytes;
        }

        expect(
          await pixels(art),
          isNot(await pixels(GameArt())),
          reason: '${def.name} must show its own sprite',
        );
      }
    },
  );
}

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/bridge_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'foreground posts preserve their stone silhouette without replaying adjacent floorboards',
    () async {
      final bytes = await rootBundle.load(
        'assets/images/landscape-bridge.webp',
      );
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final source = (await codec.getNextFrame()).image;
      codec.dispose();
      addTearDown(source.dispose);
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      final bridge = ui.Rect.fromCenter(
        center: QuarterViewBridgeArt.deckCenter,
        width: 950,
        height: 260,
      );
      for (var strip = 0; strip < QuarterViewBridgeArt.stripCount; strip++) {
        QuarterViewBridgeArt.drawRail(
          canvas,
          source,
          bridge,
          strip,
          front: true,
        );
      }
      final picture = recorder.endRecording(),
          image = await picture.toImage(1536, 1024);
      picture.dispose();
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      image.dispose();
      int alpha(int x, int y) => pixels.getUint8((y * 1536 + x) * 4 + 3);
      for (final p in const [
        ui.Offset(390, 610),
        ui.Offset(745, 450),
        ui.Offset(740, 480),
        ui.Offset(650, 550),
      ]) {
        expect(
          alpha(p.dx.toInt(), p.dy.toInt()),
          0,
          reason: 'clear deck beside post at $p',
        );
      }
      for (final p in const [
        ui.Offset(425, 625),
        ui.Offset(790, 470),
        ui.Offset(775, 500),
        ui.Offset(1110, 330),
        ui.Offset(775, 530),
        ui.Offset(1110, 370),
      ]) {
        expect(
          alpha(p.dx.toInt(), p.dy.toInt()),
          greaterThan(240),
          reason: 'opaque native stone at $p',
        );
      }
    },
  );
}

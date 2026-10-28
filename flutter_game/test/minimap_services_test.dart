import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'smith marker remains at its true projected world position near the hero',
    () async {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      for (final dx in [45.0, 90.0, 160.0]) {
        final focus = s.world.blacksmithAt - ui.Offset(dx, 0);
        s.hero.position.setValues(focus.dx - 14, focus.dy - 12);
        final rec = ui.PictureRecorder();
        MapPainter(s).paint(ui.Canvas(rec), const ui.Size(85, 85));
        final picture = rec.endRecording(),
            image = await picture.toImage(85, 85);
        picture.dispose();
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final markerX = 42.5 + dx / localMapBounds(focus).width * 85;
        var goldPixels = 0;
        // The near edge can overlap the hero; the far rim must stay anchored to
        // the forge, rather than being pushed onto a moving 23px orbit.
        for (var y = 36; y <= 49; y++) {
          if ((y - 42.5).abs() < 3) {
            continue;
          }
          for (var x = (markerX + 5).floor(); x <= (markerX + 8).ceil(); x++) {
            final i = (y * 85 + x) * 4;
            final r = pixels.getUint8(i),
                g = pixels.getUint8(i + 1),
                b = pixels.getUint8(i + 2);
            if (r > 100 && r - g > 9 && g - b > 24 && b < 135) {
              goldPixels++;
            }
          }
        }
        image.dispose();
        expect(
          goldPixels,
          greaterThan(0),
          reason: 'smith moved away from actual world anchor at hero offset$dx',
        );
      }
    },
  );
}

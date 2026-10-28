import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the large map uses the current authored settlement image', () async {
    final art = GameArt();
    final s = Adventure(art)..start(TestGame());
    addTearDown(() {
      s.dispose();
      art.dispose();
    });
    final sourceRecorder = ui.PictureRecorder();
    ui.Canvas(sourceRecorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 64, 64),
      ui.Paint()..color = const ui.Color(0xffff00ff),
    );
    final sourcePicture = sourceRecorder.endRecording();
    art.images[s.world.authoredSettlement.imageKey] = await sourcePicture
        .toImage(64, 64);
    sourcePicture.dispose();
    final recorder = ui.PictureRecorder();
    MapPainter(
      s,
      round: false,
    ).paint(ui.Canvas(recorder), const ui.Size(1200, 900));
    final picture = recorder.endRecording();
    final image = await picture.toImage(1200, 900);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    var authoredPixels = 0;
    for (var i = 0; i < bytes.lengthInBytes; i += 4) {
      if (bytes.getUint8(i) > 200 &&
          bytes.getUint8(i + 1) < 50 &&
          bytes.getUint8(i + 2) > 200) {
        authoredPixels++;
      }
    }
    expect(
      authoredPixels,
      greaterThan(100),
      reason:
          'the detailed large map retains the authored town while the minimap uses the uncluttered plan',
    );
    image.dispose();
    picture.dispose();
  });
}

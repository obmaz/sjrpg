import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a large desert polygon cannot paint beyond the map canvas', () async {
    final s = Adventure(GameArt(), stage: WorldStage.sands)..start(TestGame());
    s.pause();
    addTearDown(s.dispose);
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec)..translate(10, 10);
    MapPainter(s, round: false).paint(canvas, const ui.Size(280, 210));
    final picture = rec.endRecording();
    final image = await picture.toImage(300, 230);
    picture.dispose();
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    expect(bytes[(110 * 300 + 4) * 4 + 3], 0);
    expect(bytes[(110 * 300 + 296) * 4 + 3], 0);
    expect(bytes[(110 * 300 + 150) * 4 + 3], 255);
    image.dispose();
  });
  test(
    'the centered minimap leaves unplayable space dark at the world edge',
    () async {
      final s = Adventure(GameArt(), stage: WorldStage.sands)
        ..start(TestGame());
      s.pause();
      addTearDown(s.dispose);
      s.hero.position.setValues(0, 0);
      final rec = ui.PictureRecorder();
      MapPainter(s).paint(ui.Canvas(rec), const ui.Size(200, 200));
      final picture = rec.endRecording();
      final image = await picture.toImage(200, 200);
      picture.dispose();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final pixel = (100 * 200 + 20) * 4;
      expect(bytes.sublist(pixel, pixel + 4), [16, 42, 41, 255]);
      image.dispose();
    },
  );
}

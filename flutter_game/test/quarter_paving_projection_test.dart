import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'paver rows follow two diagonal ground axes rather than a top-down grid',
    () async {
      final r = ui.PictureRecorder(), c = ui.Canvas(r);
      c.drawColor(const ui.Color(0xff000000), ui.BlendMode.src);
      for (final (at, color) in [
        (const ui.Offset(16, 8), const ui.Color(0xffff0000)),
        (const ui.Offset(32, 8), const ui.Color(0xff00ff00)),
        (const ui.Offset(16, 24), const ui.Color(0xff0000ff)),
      ]) {
        c.drawRect(at & const ui.Size(3, 3), ui.Paint()..color = color);
      }
      final p = r.endRecording(), source = await p.toImage(64, 64);
      p.dispose();
      final art = GameArt()..images['field-paving'] = source;
      final terrain = TerrainArt(AdventureWorld(), art);
      addTearDown(() {
        terrain.dispose();
        art.dispose();
      });
      final rr = ui.PictureRecorder(),
          canvas = ui.Canvas(rr)..translate(200, 20);
      canvas.drawRect(
        const ui.Rect.fromLTWH(-200, 0, 500, 330),
        ui.Paint()..shader = terrain.pavingShader,
      );
      final pic = rr.endRecording(), im = await pic.toImage(500, 350);
      pic.dispose();
      final data = (await im.toByteData())!;
      im.dispose();
      for (final (x, y, channel) in [
        (224, 60, 0),
        (272, 84, 1),
        (176, 84, 2),
      ]) {
        expect(data.getUint8((y * 500 + x) * 4 + channel), greaterThan(220));
        expect(
          data.getUint8((y * 500 + x) * 4 + (channel + 1) % 3),
          lessThan(30),
        );
      }
    },
  );
}

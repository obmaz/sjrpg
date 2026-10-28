import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/effect_visibility.dart';

class _ForegroundSpell extends GameComponent with EffectVisibility {
  _ForegroundSpell(this.actor) {
    position = Vector2(10, 12);
    size = Vector2.all(100);
  }
  final ui.Rect? actor;
  @override
  ui.Rect get effectBounds => const ui.Rect.fromLTWH(10, 12, 100, 100);
  @override
  ui.Rect? get protectedActorBody => actor;
  @override
  void render(ui.Canvas canvas) {
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 100, 100),
      ui.Paint()..color = const ui.Color(0xffff9900),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<Uint8List> draw({required bool protect}) async {
    const body = ui.Rect.fromLTWH(42, 84, 28, 24);
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 128, 128));
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 128, 128),
      ui.Paint()..color = const ui.Color(0xff234466),
    );
    _ForegroundSpell(protect ? body : null).renderTree(canvas);
    canvas.drawRect(
      const ui.Rect.fromLTWH(54, 72, 4, 4),
      ui.Paint()..color = const ui.Color(0xff00ff00),
    );
    final picture = recorder.endRecording(),
        image = await picture.toImage(128, 128);
    picture.dispose();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = Uint8List.fromList(bytes.buffer.asUint8List());
    image.dispose();
    return result;
  }

  List<int> pixel(Uint8List bytes, int x, int y) =>
      bytes.sublist((y * 128 + x) * 4, (y * 128 + x) * 4 + 4);

  test(
    'foreground magic leaves head/torso clear but preserves vivid feet and edges',
    () async {
      final protected = await draw(protect: true),
          normal = await draw(protect: false);
      expect(pixel(protected, 56, 60), [35, 68, 102, 255]);
      expect(pixel(normal, 56, 60), [255, 153, 0, 255]);
      for (final at in [
        const ui.Offset(16, 20),
        const ui.Offset(96, 72),
        const ui.Offset(56, 106),
      ]) {
        expect(pixel(protected, at.dx.toInt(), at.dy.toInt()), [
          255,
          153,
          0,
          255,
        ]);
      }
      expect(pixel(protected, 55, 73), [0, 255, 0, 255]);
    },
  );
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native damage number poses preserve motion, color and canvas state',
    () async {
      final font = FontLoader('Guardian')
        ..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'));
      await font.load();
      final session = Adventure(GameArt())..start(TestGame());
      addTearDown(session.dispose);
      final frames = <List<int>>[];
      for (final remaining in [.87, .60, .10]) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xff19332a), ui.BlendMode.src);
        final values = ['12890', '34512', '-1278', '+38 골드'];
        for (var i = 0; i < values.length; i++) {
          final text = BattleText(
            session,
            values[i],
            ui.Offset.zero,
            i == 3 ? const ui.Color(0xff8be6a7) : const ui.Color(0xffffedb4),
            critical: i == 1,
          )..remaining = remaining;
          canvas.save();
          canvas.translate(105 + i * 190, 48);
          text.render(canvas);
          canvas.restore();
          text.releaseText();
        }
        // Caller transforms and clips survive all opaque/fade branches.
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 3, 3),
          ui.Paint()..color = const ui.Color(0xffffffff),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(800, 110);
        picture.dispose();
        final raw = (await image.toByteData())!.buffer.asUint8List().toList();
        expect(raw.take(4), [255, 255, 255, 255]);
        frames.add(raw);
        final proof = Platform.environment['COMBAT_NUMBER_PROOF_DIR'];
        if (proof != null) {
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final file = File('$proof/$remaining.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(
            png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          );
        }
        image.dispose();
      }
      expect(frames[0], isNot(frames[1]));
      expect(frames[1], isNot(frames[2]));
    },
  );
  test('system reduced motion disables punch and rise, preserving expiry', () {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final session = Adventure(GameArt())..start(TestGame());
    addTearDown(session.dispose);
    final text = BattleText(
      session,
      '12890',
      const ui.Offset(30, 50),
      const ui.Color(0xffffedb4),
    );
    expect(text.reducedMotion, true);
    expect(text.punchScale, 1);
    text.update(.2);
    expect(text.position.y, 50);
    expect(text.remaining, closeTo(.7, .0001));
    text.releaseText();
  });
}

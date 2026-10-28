import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/barbarian_icon_art.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/rpg_widgets.dart';
import 'package:guardian_new/skill_tree_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all thirty generated warrior effects have unique stable IDs and fallbacks',
    () {
      expect(BarbarianIconArt.ids.length, 30);
      expect(BarbarianIconArt.ids.toSet().length, 30);
      expect(BarbarianIconArt.ids.toSet(), warriorTreeIds);
      expect(
        BarbarianIconArt.ids.map(skillEffect),
        List.generate(30, (i) => 100 + i),
      );
      expect(BarbarianIconArt.ids.map(skillIcon).toSet().length, 30);
      expect(skillEffect('meteor'), 227);
      expect(skillEffect('shadowAssault'), 36);
      expect(BarbarianIconArt.effectFor('battleSprint'), null);
      expect(BarbarianIconArt.containsEffect(130), false);
    },
  );
  test(
    'battle icons crop the square plaque while tree icons retain it',
    () async {
      final referenceRecorder = ui.PictureRecorder();
      ui.Canvas(referenceRecorder);
      final referencePicture = referenceRecorder.endRecording();
      final reference = await referencePicture.toImage(1374, 1145);
      referencePicture.dispose();
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      for (var i = 0; i < 30; i++) {
        final source = BarbarianIconArt.source(reference, i)!;
        canvas.drawRect(source, ui.Paint()..color = const ui.Color(0xffffbb33));
        canvas.drawRect(
          source.deflate(16),
          ui.Paint()..color = const ui.Color(0xff235577),
        );
      }
      reference.dispose();
      final picture = recorder.endRecording(),
          atlas = await picture.toImage(1374, 1145);
      picture.dispose();
      final art = GameArt()..images[BarbarianIconArt.imageKey] = atlas;
      addTearDown(art.dispose);
      for (final framed in [true, false]) {
        final r = ui.PictureRecorder();
        EffectIconPainter(
          art,
          100,
          framed: framed,
        ).paint(ui.Canvas(r), const ui.Size(64, 64));
        final p = r.endRecording(), image = await p.toImage(64, 64);
        p.dispose();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        expect(bytes.sublist((32 * 64 + 32) * 4, (32 * 64 + 32) * 4 + 4), [
          35,
          85,
          119,
          255,
        ]);
        if (!framed) {
          expect(
            bytes[3],
            0,
            reason: 'the circular battle icon has no rectangular corners',
          );
          expect(
            [
              for (var i = 0; i < bytes.length; i += 4)
                if (bytes[i] == 255 &&
                    bytes[i + 1] == 187 &&
                    bytes[i + 2] == 51 &&
                    bytes[i + 3] == 255)
                  i,
            ],
            isEmpty,
            reason: 'the baked gold square border is cropped away',
          );
        } else {
          expect(
            [
              for (var i = 0; i < bytes.length; i += 4)
                if (bytes[i] == 255 &&
                    bytes[i + 1] == 187 &&
                    bytes[i + 2] == 51 &&
                    bytes[i + 3] == 255)
                  i,
            ],
            isNotEmpty,
            reason: 'tree and popup icons retain their original plaque',
          );
        }
        image.dispose();
      }
    },
  );
  test(
    'each effect samples its own six by five cell without the legacy physical sheet',
    () async {
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      for (var i = 0; i < 30; i++) {
        canvas.drawRect(
          ui.Rect.fromLTWH(i % 6 * 40, i ~/ 6 * 40, 40, 40),
          ui.Paint()
            ..color = ui.Color.fromARGB(
              255,
              20 + i * 6,
              180 - i * 3,
              40 + i * 5,
            ),
        );
      }
      final picture = recorder.endRecording(),
          atlas = await picture.toImage(240, 200);
      picture.dispose();
      final art = GameArt()..images[BarbarianIconArt.imageKey] = atlas;
      addTearDown(art.dispose);
      for (var i = 0; i < 30; i++) {
        final source = BarbarianIconArt.source(atlas, i)!;
        expect(
          (ui.Offset.zero & ui.Size(240, 200)).contains(source.topLeft),
          true,
        );
        expect(
          (ui.Offset.zero & ui.Size(240, 200)).contains(source.bottomRight),
          true,
        );
        final r = ui.PictureRecorder();
        EffectIconPainter(
          art,
          100 + i,
        ).paint(ui.Canvas(r), const ui.Size(48, 48));
        final p = r.endRecording(), image = await p.toImage(48, 48);
        p.dispose();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final at = (24 * 48 + 24) * 4;
        expect(bytes.sublist(at, at + 4), [
          20 + i * 6,
          180 - i * 3,
          40 + i * 5,
          255,
        ], reason: BarbarianIconArt.ids[i]);
        image.dispose();
      }
      expect(BarbarianIconArt.source(atlas, 30), null);
    },
  );
}

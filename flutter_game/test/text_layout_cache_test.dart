import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';

class _MeasuredArt extends GameArt {
  int layouts = 0;
  @override
  ui.Paragraph layoutText(
    String value, {
    double size = 16,
    ui.Color color = const ui.Color(0xffffedbb),
  }) {
    layouts++;
    return super.layoutText(value, size: size, color: color);
  }
}

class _UncachedArt extends _MeasuredArt {
  @override
  void text(
    ui.Canvas canvas,
    String value,
    ui.Offset at, {
    double size = 16,
    ui.Color color = const ui.Color(0xffffedbb),
  }) {
    final paragraph = layoutText(value, size: size, color: color);
    canvas.drawParagraph(paragraph, at - const ui.Offset(80, 0));
    paragraph.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'repeated labels reuse layouts; style changes and LRU eviction stay correct',
    () {
      final art = _MeasuredArt(), recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      addTearDown(art.dispose);
      for (var i = 0; i < 100; i++) {
        art.text(canvas, 'village', ui.Offset(i.toDouble(), 0));
      }
      expect(art.layouts, 1);
      art.text(canvas, 'village', ui.Offset.zero, size: 20);
      art.text(
        canvas,
        'village',
        ui.Offset.zero,
        color: const ui.Color(0xffaabbcc),
      );
      expect(art.layouts, 3);
      final owned = art.layoutText('village');
      owned.dispose(); // Public paragraphs retain caller ownership.
      art.text(canvas, 'village', ui.Offset.zero);
      expect(art.layouts, 4);
      for (var i = 0; i < 128; i++) {
        art.text(canvas, 'label-$i', ui.Offset.zero);
      }
      final before = art.layouts;
      art.text(canvas, 'label-0', ui.Offset.zero);
      art.text(canvas, 'label-128', ui.Offset.zero);
      art.text(canvas, 'label-0', ui.Offset.zero);
      expect(
        art.layouts,
        before + 1,
        reason: 'recent access protects a label from eviction',
      );
      art.text(canvas, 'label-1', ui.Offset.zero);
      expect(art.layouts, before + 2);
      recorder.endRecording().dispose();
    },
  );
  test(
    'label cache preserves pixels and reduces repeated native layout work',
    () async {
      final timings = <String, Object>{};
      final pixels = <List<int>>[];
      for (final art in <_MeasuredArt>[_UncachedArt(), _MeasuredArt()]) {
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        final timer = Stopwatch()..start();
        for (var i = 0; i < 1000; i++) {
          art.text(canvas, 'village', const ui.Offset(100, 20));
        }
        timer.stop();
        final name = art is _UncachedArt ? 'uncached' : 'cached';
        timings[name] = {
          'layouts': art.layouts,
          'microseconds': timer.elapsedMicroseconds,
        };
        expect(art.layouts, art is _UncachedArt ? 1000 : 1);
        final picture = recorder.endRecording(),
            image = await picture.toImage(200, 80);
        pixels.add((await image.toByteData())!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        art.dispose();
      }
      expect(pixels[1], orderedEquals(pixels[0]));
      final export = Platform.environment['SJRPG_LABEL_BENCHMARK'];
      if (export != null) {
        File(export).writeAsStringSync(jsonEncode(timings));
      }
    },
  );
}

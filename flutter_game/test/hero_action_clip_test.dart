import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_atlas.dart';
import 'package:guardian_new/game_art.dart';

Map<String, dynamic> actionRecord({
  int count = 8,
  String layout = 'phase-major',
}) => {
  'frames': [
    for (var i = 0; i < count * 16; i++) [i * 4, 0, 4, 8],
  ],
  'feet': [
    for (var i = 0; i < count * 16; i++) [i * 4 + 2, 8],
  ],
  'sizes': [
    [4, 8],
  ],
  'anchorMode': 'projected-origin',
  'action': {'directions': 16, 'frames': count, 'layout': layout},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('action progress spans every phase in all sixteen directions', () {
    for (final layout in ['phase-major', 'direction-major']) {
      final clip = ActorAtlas.fromJson(actionRecord(layout: layout)).action!;
      for (var d = 0; d < 16; d++) {
        for (var phase = 0; phase < 8; phase++) {
          expect(
            clip.frameIndex(d, (phase + .1) / 8),
            layout == 'phase-major' ? phase * 16 + d : d * 8 + phase,
          );
        }
        expect(clip.frameIndex(d, -1), clip.frameIndex(d, 0));
        expect(clip.frameIndex(d, 1), clip.frameIndex(d, .999));
        expect(clip.frameIndex(d, double.nan), clip.frameIndex(d, 0));
      }
      expect(() => clip.frameIndex(16, .5), throwsRangeError);
    }
  });
  test('incomplete aliased mirrored or unanchored action data is rejected', () {
    final invalid = <Map<String, dynamic>>[
      actionRecord(count: 2),
      actionRecord()
        ..['frames'] = [
          [0, 0, 4, 8],
        ],
      actionRecord()..['feet'] = null,
      actionRecord()..['frames'] = List.filled(128, [0, 0, 4, 8]),
      actionRecord()..['mirrors'] = List.filled(128, true),
      actionRecord()
        ..['action'] = {'directions': 8, 'frames': 8, 'layout': 'phase-major'},
    ];
    for (final record in invalid) {
      expect(() => ActorAtlas.fromJson(record), throwsFormatException);
    }
    final legacy = actionRecord(count: 2)..remove('action');
    expect(ActorAtlas.fromJson(legacy).action, isNull);
  });
  test(
    'actual raster uses eight action poses and retains the heavier feet anchor',
    () async {
      ui.Color color(int i) =>
          ui.Color.fromARGB(255, i + 1, 255 - i, i * 17 % 256);
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      for (var i = 0; i < 128; i++) {
        canvas.drawRect(
          ui.Rect.fromLTWH(i * 4.0, 0, 4, 8),
          ui.Paint()..color = color(i),
        );
      }
      final picture = recorder.endRecording(),
          source = await picture.toImage(512, 8);
      picture.dispose();
      final art = GameArt()..actors = {'hero-attack': actionRecord()};
      art.images['actors-hero-attack'] = source;
      addTearDown(art.dispose);
      final seen = <List<int>>[];
      for (var phase = 0; phase < 8; phase++) {
        final recorder = ui.PictureRecorder();
        art.actor(
          ui.Canvas(recorder),
          'hero',
          const ui.Offset(40, 40),
          0,
          0,
          16,
          attack: true,
          actionProgress: (phase + .1) / 8,
        );
        final p = recorder.endRecording(), image = await p.toImage(80, 64);
        p.dispose();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        List<int> pixel(int x, int y) =>
            data.sublist((y * 80 + x) * 4, (y * 80 + x) * 4 + 4);
        final c = color(phase * 16 + 12);
        expect(
          pixel(40, 30),
          [c.r * 255, c.g * 255, c.b * 255, 255].map((v) => v.round()).toList(),
        );
        expect(
          pixel(40, 40).last,
          0,
          reason: 'the fixed ground anchor does not float on widening',
        );
        expect(
          pixel(35, 30).last,
          greaterThan(0),
          reason: 'the heavier body still fills the old left boundary',
        );
        expect(
          pixel(34, 30).last,
          greaterThan(0),
          reason: 'the new 1.36 width reaches beyond the old silhouette',
        );
        expect(
          pixel(34, 30).last,
          pixel(45, 30).last,
          reason: 'the broadened edges remain symmetric about the x=40 anchor',
        );
        expect(pixel(33, 30).last, 0);
        expect(pixel(46, 30).last, 0);
        seen.add(pixel(40, 30));
        image.dispose();
      }
      expect(seen.map((p) => p.join(',')).toSet(), hasLength(8));
    },
  );
}

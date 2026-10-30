import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stage in WorldStage.values) {
    test(
      '${stage.name} loads four isolated native landmarks only for its stage',
      () async {
        final art = await GameArt.loadMenu();
        addTearDown(art.dispose);
        await art.ensureStage(stage, heroClass: HeroClass.warrior);
        expect(art.images.keys.where((key) => key.startsWith('landmarks-')), [
          'landmarks-${stage.name}',
        ]);
        final image = art.images['landmarks-${stage.name}']!;
        expect(image.width, 1536);
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        for (var index = 0; index < 4; index++) {
          var visible = 0, borderAlpha = 0;
          for (var y = 0; y < 768; y++) {
            for (var x = 0; x < 768; x++) {
              final alpha =
                  bytes[(((index ~/ 2 * 768 + y) * 1536 + index % 2 * 768 + x) *
                          4) +
                      3];
              if (alpha > 16) visible++;
              if (x < 30 || x >= 738 || y < 30 || y >= 738) {
                if (alpha > borderAlpha) borderAlpha = alpha;
              }
            }
          }
          expect(borderAlpha, 0, reason: 'neighbor-free cell padding $index');
          expect(visible, greaterThan(20000));
        }
        final s = Adventure(art, stage: stage, hubOrigin: stage.arrival)
          ..start(TestGame());
        addTearDown(s.dispose);
        final output = Platform.environment['SJRPG_LANDMARK_PROOF_DIR'];
        if (output != null) {
          Directory(output).createSync(recursive: true);
          final landmark = s.world.landmarks.first;
          final at = s.world.spawnNear(
            landmark.footprint.bottomCenter + const ui.Offset(-12, 50),
            Guardian.onFootSize,
          )!;
          s.hero.position.setValues(at.dx, at.dy);
          File(
            '$output/${stage.name}-checkpoint.json',
          ).writeAsStringSync(GameCheckpoint.capture(s)!.encode());
          File('$output/${stage.name}-landmarks.json').writeAsStringSync(
            jsonEncode([
              for (final l in s.world.landmarks)
                {
                  'index': l.index,
                  'name': l.name,
                  'x': l.center.dx,
                  'y': l.center.dy,
                  'side': l.side,
                },
            ]),
          );
          final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
          final view = ui.Rect.fromCenter(
            center: landmark.drawBounds.center + const ui.Offset(0, 60),
            width: 1280,
            height: 960,
          );
          canvas.translate(-view.left, -view.top);
          s.terrain.render(canvas, view);
          art.prop(
            canvas,
            s.world.props.firstWhere((p) => identical(p.landmark, landmark)),
          );
          art.actor(
            canvas,
            'hero',
            landmark.footprint.bottomCenter + const ui.Offset(90, 45),
            0,
            0,
            84,
          );
          final picture = recorder.endRecording(),
              proof = await picture.toImage(1280, 960);
          final png = await proof.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$output/${stage.name}-world.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          proof.dispose();
          picture.dispose();
        }
      },
    );
  }
}

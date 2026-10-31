import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/dungeon.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'fork walls remain dark on the map and share physical clearance',
    () async {
      final art = GameArt();
      addTearDown(art.dispose);
      final s = Adventure(art, dungeon: DungeonRun(WorldStage.forest, 1))
        ..start(TestGame());
      addTearDown(s.dispose);
      final view = s.dungeon!.layout.bounds;
      final middle = ui.Offset.lerp(
        DungeonLayout.rooms[1],
        DungeonLayout.rooms[2],
        .5,
      )!;
      final fork = middle + const ui.Offset(0, -300);
      expect(s.dungeon!.layout.contains(middle), false);
      expect(s.dungeon!.layout.contains(fork), true);
      final recorder = ui.PictureRecorder();
      MapPainter(
        s,
        round: false,
      ).paint(ui.Canvas(recorder), const ui.Size(1200, 900));
      final picture = recorder.endRecording(),
          image = await picture.toImage(1200, 900);
      final bytes = (await image.toByteData())!.buffer.asUint8List();
      List<int> rgb(ui.Offset at) {
        final x = ((at.dx - view.left) / view.width * 1200).floor(),
            y = ((at.dy - view.top) / view.height * 900).floor();
        return bytes.sublist((y * 1200 + x) * 4, (y * 1200 + x) * 4 + 3);
      }

      expect(rgb(middle), [24, 32, 39]);
      expect(rgb(fork), [122, 131, 125]);
      final output = Platform.environment['SJRPG_DUNGEON_MAP_PROOF'];
      if (output != null) {
        File('$output.png').writeAsBytesSync(
          (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List(),
        );
        File('$output.json').writeAsStringSync(
          jsonEncode({
            'bounds': [view.left, view.top, view.width, view.height],
            'middle': [middle.dx, middle.dy],
            'fork': [fork.dx, fork.dy],
          }),
        );
      }
      image.dispose();
      picture.dispose();
    },
  );
  for (final stage in WorldStage.values) {
    test(
      '${stage.name} instance map paints without outdoor service lookups',
      () async {
        final art = GameArt();
        addTearDown(art.dispose);
        final session = Adventure(
          art,
          stage: stage,
          dungeon: DungeonRun(stage, 8),
        )..start(TestGame());
        addTearDown(session.dispose);
        for (final round in [true, false]) {
          final recorder = ui.PictureRecorder();
          MapPainter(
            session,
            round: round,
          ).paint(ui.Canvas(recorder), const ui.Size(512, 384));
          final picture = recorder.endRecording();
          final image = await picture.toImage(512, 384);
          expect(image.width, 512);
          image.dispose();
          picture.dispose();
        }
      },
    );
  }
}

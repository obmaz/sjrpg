import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/dungeon.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cave wall decodes on instance preparation and rendered tiles are owned',
    () async {
      final art = await GameArt.loadMenu();
      addTearDown(art.dispose);
      expect(art.images['cave-entrances'], isNull);
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      expect(art.images['cave-entrances'], isNotNull);
      expect(art.images['cave-rock'], isNull);
      await art.ensureStage(
        WorldStage.forest,
        heroClass: HeroClass.warrior,
        cave: true,
      );
      final rock = art.images['cave-rock'];
      expect(rock, isNotNull);
      final world = AdventureWorld(dungeon: DungeonRun(WorldStage.forest, 1));
      final terrain = TerrainArt(world, art);
      final recorder = ui.PictureRecorder();
      terrain.render(
        ui.Canvas(recorder),
        const ui.Rect.fromLTWH(2800, 4800, 512, 512),
      );
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(512, 512);
      rendered.dispose();
      picture.dispose();
      final cached = terrain.rasterSector(5, 9);
      terrain.dispose();
      expect(cached.debugDisposed, true);
      expect(rock!.debugDisposed, false);
    },
  );
  test(
    'six independently measured entrance crops have transparent cell borders',
    () async {
      final art = await GameArt.loadMenu();
      addTearDown(art.dispose);
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      final atlas = art.images['cave-entrances']!;
      expect(atlas.width, 1536);
      expect(atlas.height, 1024);
      final bytes = (await atlas.toByteData())!.buffer.asUint8List();
      int alpha(int x, int y) => bytes[(y * 1536 + x) * 4 + 3];
      for (var cell = 0; cell < 6; cell++) {
        final left = cell % 3 * 512, top = cell ~/ 3 * 512;
        for (var i = 0; i < 512; i++) {
          expect(alpha(left + i, top), 0);
          expect(alpha(left + i, top + 511), 0);
          expect(alpha(left, top + i), 0);
          expect(alpha(left + 511, top + i), 0);
        }
      }
    },
  );
}

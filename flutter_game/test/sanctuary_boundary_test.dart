import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/sanctuary_fence.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stage in WorldStage.values) {
    test('$stage has visible solid boundaries and open service approaches', () {
      final world = AdventureWorld(stage: stage);
      expect(world.sanctuaryFences, isNotEmpty);
      for (final section in world.sanctuaryFences) {
        for (final body in section.collisionBodies) {
          expect(world.blocked(body), true);
        }
      }
      const size = ui.Size(28, 24);
      for (final service in [
        world.healAt + const ui.Offset(0, 70),
        world.merchantAt,
        if (stage == WorldStage.sands)
          ...timeQuestGivers.map((giver) => giver.at)
        else
          world.elderAt,
      ]) {
        final at = world.spawnNear(service, size);
        expect(at, isNotNull);
        expect(world.sanctuary.protects(at! & size), true);
        expect(
          world.clearLine(world.spawn, at, size) ||
              world.route(world.spawn, at, size).isNotEmpty,
          true,
        );
      }
    });
  }

  final world = AdventureWorld();
  ui.Offset at(double u, double v) =>
      ui.Offset(town.left + town.width * u, town.top + town.height * v);
  for (final size in [const ui.Size(28, 24), const ui.Size(44, 32)]) {
    for (final (name, start, direction) in [
      ('east', at(.73, .52), const ui.Offset(1, 0)),
      ('west', at(.15, .34), const ui.Offset(-1, 0)),
      ('north', at(.48, .07), const ui.Offset(0, -1)),
      ('south', at(.57, .88), const ui.Offset(0, 1)),
    ]) {
      test(
        '$name gate lets a $size body leave the entire sanctuary and return',
        () {
          var end = start;
          for (
            var step = 0;
            step < 200 && world.sanctuary.protects(end & size);
            step++
          ) {
            end += direction * 6;
          }
          expect(world.sanctuary.protects(end & size), false);
          expect(world.clearLine(start, end, size), true);
          final forward = world.move(start, end - start, size);
          expect((forward - end).distance, lessThan(.01));
          final reverse = world.move(end, start - end, size);
          expect((reverse - start).distance, lessThan(.01));
        },
      );
    }
  }

  test('all boundary themes render distinct complete low fences', () async {
    final renders = <int>{};
    for (final stage in WorldStage.values) {
      final recorder = ui.PictureRecorder();
      paintSanctuaryFence(
        ui.Canvas(recorder),
        stage,
        const ui.Offset(20, 56),
        const ui.Offset(108, 44),
      );
      final picture = recorder.endRecording(),
          image = await picture.toImage(128, 72);
      picture.dispose();
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final bytes = Uint8List.sublistView(data);
      renders.add(Object.hashAll(bytes));
      expect(
        [
          for (var i = 3; i < bytes.length; i += 4)
            if (bytes[i] > 40) bytes[i],
        ].length,
        greaterThan(600),
      );
      image.dispose();
    }
    expect(renders.length, WorldStage.values.length);
  });
}

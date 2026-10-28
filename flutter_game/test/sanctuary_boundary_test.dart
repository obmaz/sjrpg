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
      expect(world.settlementCollision, isNotEmpty);
      for (final section in world.sanctuaryFences) {
        for (final body in section.collisionBodies) {
          expect(world.blocked(body), true);
        }
      }
      const size = ui.Size(28, 24);
      for (final uv in const [
        ui.Offset(.09, .19),
        ui.Offset(.80, .135),
        ui.Offset(.045, .72),
        ui.Offset(.95, .70),
      ]) {
        final wall = world.authoredSettlement.point(uv);
        final body = ui.Rect.fromCenter(center: wall, width: 28, height: 24);
        expect(world.blocked(body), true);
        expect(world.sanctuary.protects(body), true);
      }
      for (final service in [
        world.authoredSettlement.wellApproach,
        world.merchantAt,
        if (stage == WorldStage.sands)
          ...timeQuestGivers.map((giver) => world.questGiverAt(giver.path))
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

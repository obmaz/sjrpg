import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

class PoseArt extends GameArt {
  int? phase;
  @override
  void actor(
    ui.Canvas canvas,
    String key,
    ui.Offset feet,
    double angle,
    int phase,
    double height, {
    bool attack = false,
    bool moving = false,
    int comboPose = 0,
    double? actionProgress,
    Object? bossPose,
    Object? walkPose,
    Object? mountPose,
    double opacity = 1,
    double flash = 0,
  }) {
    if (key == 'hero') this.phase = phase;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'stopping and a blocked step render the idle pose after a passing stride',
    () {
      final art = PoseArt();
      final session = inCombatField(Adventure(art))..start(TestGame());
      addTearDown(session.dispose);
      final hero = session.hero;
      void draw() {
        final recorder = ui.PictureRecorder();
        hero.render(ui.Canvas(recorder));
        recorder.endRecording().dispose();
      }

      // Half-speed walking takes twice as long to pass the middle of a stride.
      for (var i = 0; i < 10; i++) {
        hero.moveRight();
        hero.update(.05);
      }
      expect(hero.runMotion.phase, 1);
      draw();
      expect(art.phase, 1);
      hero.stop();
      hero.update(.05);
      final cycle = hero.runMotion.cycle;
      draw();
      expect(art.phase, 0, reason: 'resting is not a frozen passing foot');
      final tree = session.world.props.firstWhere(
        (prop) =>
            prop.kind == 'tree' &&
            !session.world.blocked(
              ui.Rect.fromLTWH(
                prop.body.left - hero.size.x,
                prop.body.center.dy - hero.size.y / 2,
                hero.size.x,
                hero.size.y,
              ),
            ),
      );
      hero.position.setValues(
        tree.body.left - hero.size.x,
        tree.body.center.dy - hero.size.y / 2,
      );
      hero.moveRight();
      hero.update(.05);
      draw();
      expect(hero.runMotion.cycle, closeTo(cycle, .0001));
      expect(art.phase, 0, reason: 'pushing a wall has no walking stride');
    },
  );

  test(
    'boarding and dismounting restore the original whole-body footprint',
    () {
      final s = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(s.dispose);
      final original = s.hero.body.size;
      expect(original, const ui.Size(28, 24));
      withOwnedMounts(s).mounts.first.at = const ui.Offset(6000, 4200);
      s.hero.position.setValues(5990, 4250);
      expect(s.boardNearbyMount(), true);
      expect(s.hero.body.size, withOwnedMounts(s).mounts.first.def.bodySize);
      expect(s.dismount(), true);
      expect(s.hero.body.size, original);
      expect(s.world.blocked(s.hero.body), false);
    },
  );
}

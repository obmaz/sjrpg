import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_motion.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

class RecordingArt extends GameArt {
  int? lastHeroPhase;

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
    double opacity = 1,
    double flash = 0,
  }) {
    if (key == 'hero') lastHeroPhase = phase;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // An 8px thumb displacement on the current 142px stick, just outside its
  // 18% deadzone. This is a real emitted analog intensity, not tiny fake input.
  final intensity = (8 / (142 * .27) - .18) / .82;

  void walk(Guardian hero) => hero.onJoystickChangeDirectional(
    JoystickDirectionalEvent(
      directional: JoystickMoveDirectional.MOVE_RIGHT,
      radAngle: 0,
      intensity: intensity,
    ),
  );

  for (final hz in [30, 60, 120, 144]) {
    test('$hz Hz slow analog movement advances and renders the gait', () {
      final art = RecordingArt();
      final s = inCombatField(Adventure(art))..start(TestGame());
      addTearDown(s.dispose);
      walk(s.hero);
      s.hero.update(
        1 / hz,
      ); // A positive frame applies the new joystick velocity.
      final before = s.hero.position.clone();
      expect(
        s.hero.velocity.x,
        closeTo(CombatBalance.normalMoveSpeed * intensity, .00001),
      );
      for (var i = 0; i < hz * 5; i++) {
        s.hero.update(1 / hz);
      }
      final travelled = (s.hero.position - before).length;
      // Bonfire positions use Float32 storage: subpixel rounding over many
      // small steps is normal, and must not hide real movement from animation.
      // At x6000 a Float32 ULP is1/2048px. Bound accumulated rounding
      // by half an ULP per integration step;135px/s changes that rounding.
      final quantizationBudget = hz * 5 / 4096 + .001;
      expect(
        travelled,
        closeTo(
          CombatBalance.normalMoveSpeed * intensity * 5,
          quantizationBudget,
        ),
      );
      expect(s.hero.movingThisFrame, true);
      expect(
        s.hero.runMotion.cycle,
        closeTo(travelled / RunMotion.strideLength, .00001),
      );
      expect(s.hero.animationTime, greaterThan(0));
      final recorder = ui.PictureRecorder();
      s.hero.render(ui.Canvas(recorder));
      recorder.endRecording().dispose();
      expect(
        art.lastHeroPhase,
        s.hero.runMotion.phaseFor(art.runFrameCount('hero')),
      );
    });
  }

  test(
    '144 Hz blocked analog input remains idle instead of walking in place',
    () {
      final art = RecordingArt();
      final s = inCombatField(Adventure(art))..start(TestGame());
      addTearDown(s.dispose);
      final size = s.hero.body.size;
      final tree = s.world.props.firstWhere(
        (p) =>
            p.kind == 'tree' &&
            !s.world.blocked(
              ui.Rect.fromLTWH(
                p.body.left - size.width - .01,
                p.body.center.dy - size.height / 2,
                size.width,
                size.height,
              ),
            ),
      );
      s.hero.position.setValues(
        tree.body.left - size.width - .01,
        tree.body.center.dy - size.height / 2,
      );
      final before = s.hero.position.clone();
      walk(s.hero);
      s.hero.update(1 / 144);
      for (var i = 0; i < 144; i++) {
        s.hero.update(1 / 144);
      }
      expect(s.hero.position, before);
      expect(s.hero.movingThisFrame, false);
      expect(s.hero.runMotion.cycle, 0);
      final recorder = ui.PictureRecorder();
      s.hero.render(ui.Canvas(recorder));
      recorder.endRecording().dispose();
      expect(art.lastHeroPhase, 0);
    },
  );
}

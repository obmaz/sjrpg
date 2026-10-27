import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/hud_motion_clock.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure scene() {
    final s = Adventure(GameArt())..start(TestGame());
    addTearDown(s.dispose);
    return s;
  }

  test(
    'clock samples actual simulation delta and caps notifications at30Hz',
    () {
      final s = scene(), c = HudMotionClock();
      expect(c.advance(s), 0);
      expect(c.advance(s), 0);
      s.elapsed = .016;
      expect(c.advance(s), 0);
      s.elapsed = .032;
      expect(c.advance(s), 0);
      s.elapsed = .034;
      expect(c.advance(s), closeTo(.034, .000001));
      s.elapsed = .05;
      expect(c.advance(s), 0);
      s.elapsed = .068;
      expect(c.advance(s), closeTo(.034, .000001));
      s.elapsed = 3;
      expect(c.advance(s), .1);
      expect(c.advance(s), 0, reason: 'discarded overshoot is never replayed');
    },
  );
  test('10Hz simulation keeps real cue timing without double scaling', () {
    final s = scene(), c = HudMotionClock();
    c.advance(s);
    (s.game! as TestGame).timeScale = .5;
    var consumed = 0.0;
    for (var i = 0; i < 5; i++) {
      s.elapsed += .1;
      consumed += c.advance(s);
    }
    expect(consumed, closeTo(.5, .000001));
    s.elapsed += .05;
    expect(c.advance(s), closeTo(.05, .000001));
  });
  test(
    'engine pause and scale0 permit polling but reset their time baseline',
    () {
      final s = scene(), c = HudMotionClock(), game = s.game! as TestGame;
      c.advance(s);
      for (final gate in ['pause', 'scale']) {
        if (gate == 'pause') {
          game.pauseEngine();
        } else {
          game.timeScale = 0;
        }
        expect(c.canObserve(s), true);
        s.elapsed += 10;
        expect(c.advance(s), 0);
        if (gate == 'pause') {
          game.resumeEngine();
        } else {
          game.timeScale = 1;
        }
        expect(c.advance(s), 0);
        s.elapsed += .04;
        expect(c.advance(s), closeTo(.04, .000001));
      }
    },
  );
  test('lifecycle and motion-mode transitions discard stale elapsed', () {
    final s = scene(), c = HudMotionClock();
    c.advance(s);
    for (final gate in ['disabled', 'background', 'reduced', 'session']) {
      if (gate == 'session') s.pause();
      s.elapsed += 10;
      expect(
        c.advance(
          s,
          enabled: gate != 'disabled',
          foreground: gate != 'background',
          reducedMotion: gate == 'reduced',
        ),
        0,
      );
      if (gate == 'session') s.resume();
      expect(c.advance(s), 0);
      s.elapsed += .04;
      expect(c.advance(s), closeTo(.04, .000001));
    }
    expect(c.advance(s, reducedMotion: true, allowReducedMotion: true), 0);
    s.elapsed += .05;
    expect(
      c.advance(s, reducedMotion: true, allowReducedMotion: true),
      closeTo(.05, .000001),
    );
    expect(c.advance(s, reducedMotion: false), 0);
  });
  test('identity, backwards time, null game and disposed session are safe', () {
    final a = scene(), b = scene(), c = HudMotionClock();
    c.advance(a);
    a.elapsed = .05;
    expect(c.advance(a), closeTo(.05, .000001));
    b.elapsed = 100;
    expect(c.advance(b), 0);
    b.elapsed = 99;
    expect(c.advance(b), 0);
    b.elapsed = 99.04;
    expect(c.advance(b), closeTo(.04, .000001));
    final empty = Adventure(GameArt());
    expect(c.advance(empty), 0);
    empty.dispose();
    expect(c.advance(empty), 0);
  });
}

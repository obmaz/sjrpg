import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/health_widgets.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/player_health_feedback.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session({double hp = 100}) {
    final s = inCombatField(Adventure(GameArt())..start(TestGame()));
    s.progress.hp = hp;
    s.syncLife();
    addTearDown(s.dispose);
    return s;
  }

  PlayerHealthFeedback watch(Adventure s) {
    final f = PlayerHealthFeedback(s)..sample();
    addTearDown(f.dispose);
    return f;
  }

  test(
    'restored low health shows thresholds without inventing a damage event',
    () {
      final s = session(hp: 30), f = watch(s);
      expect(f.reading.value.danger, HealthDanger.low);
      expect(f.damageRemaining, 0);
      s.progress.hp = 15;
      f.sample();
      expect(f.reading.value.danger, HealthDanger.critical);
      s.progress.hp = 30.01;
      f.sample();
      expect(f.reading.value.danger, HealthDanger.none);
      expect(
        f.damageRemaining,
        0,
        reason: 'healing clears the previous hit cue',
      );
    },
  );

  test(
    'accepted hit creates a pale trail and brief cue; rejected hit does not',
    () {
      final s = session(), f = watch(s);
      s.hurtHero(25);
      f.sample();
      expect(s.progress.hp, lessThan(100));
      expect(f.trailRatio, 1);
      expect(f.damageRemaining, PlayerHealthFeedback.damageDuration);
      expect(f.dangerOpacity, greaterThan(0));
      final hp = s.progress.hp;
      s.hurtHero(25); // Invulnerability rejects this second hit.
      f.sample();
      expect(s.progress.hp, hp);
      expect(f.damageRemaining, PlayerHealthFeedback.damageDuration);
      for (var i = 0; i < 10; i++) {
        s.tick(.1);
        f.sample();
      }
      expect(f.damageRemaining, 0);
      expect(f.trailRatio, closeTo(f.reading.value.ratio, .001));
      expect(f.dangerOpacity, 0, reason: 'healthy damage feedback expires');
    },
  );

  test(
    'actual poison HP loss uses the same damage cue despite hit invulnerability',
    () {
      final s = session(), f = watch(s);
      s.hero.invulnerable = 10;
      s.afflictions.apply(PlayerStatus.poison, potency: 1.2);
      s.afflictions.poisonTick = .01;
      s.tick(.05);
      f.sample();
      expect(s.progress.hp, lessThan(100));
      expect(f.damageRemaining, greaterThan(0));
      expect(f.trailRatio, greaterThan(f.reading.value.ratio));
      expect(f.dangerOpacity, greaterThan(0));
      expect(s.hero.invulnerable, 10);
    },
  );

  test(
    'equipment maximum changes, heals and new-session restoration are not hits',
    () {
      final s = session(), f = watch(s);
      s.progress.bonusHealth += 20;
      f.sample();
      expect(f.reading.value.maximum, 120);
      expect(f.damageRemaining, 0);
      expect(f.trailRatio, f.reading.value.ratio);
      s.progress.hp = 110;
      f.sample();
      expect(f.damageRemaining, 0);
      final save = s.progress.toSave();
      f.sample();
      expect(
        s.progress.toSave(),
        save,
        reason: 'feedback never writes gameplay state',
      );
      final restored = session(hp: 20), restoredFeedback = watch(restored);
      expect(restoredFeedback.damageRemaining, 0);
      expect(restoredFeedback.reading.value.danger, HealthDanger.low);
    },
  );

  test('fountain rejection produces no hit feedback', () {
    final s = Adventure(GameArt())..start(TestGame());
    addTearDown(s.dispose);
    final f = watch(s);
    s.hurtHero(99);
    f.sample();
    expect(s.progress.hp, 100);
    expect(f.damageRemaining, 0);
    expect(f.dangerOpacity, 0);
  });

  test(
    'simulation clock caps paints and freezes pause, direct engine pause and hitstop',
    () {
      final s = session(hp: 15), f = watch(s);
      s.tick(.04);
      f.sample();
      expect(f.phase, greaterThan(0));
      var before = f.phase;
      s.pause();
      s.elapsed += 3;
      f.sample();
      expect(f.phase, before);
      s.resume();
      f.sample();
      s.tick(.04);
      f.sample();
      expect((f.phase - before).abs(), lessThan(.05));
      before = f.phase;
      s.game!.pauseEngine();
      s.tick(.5);
      f.sample();
      expect(f.phase, before);
      s.game!.resumeEngine();
      f.sample();
      s.tick(.04);
      f.sample();
      expect((f.phase - before).abs(), lessThan(.05));
      before = f.phase;
      s.game!.timeScale = 0;
      s.tick(.5);
      f.sample();
      expect(f.phase, before);
      s.game!.timeScale = 1;
      f.sample();
      s.tick(.04);
      f.sample();
      expect((f.phase - before).abs(), lessThan(.05));
      var paints = 0;
      f.addListener(() => paints++);
      for (var i = 0; i < 100; i++) {
        s.elapsed += .01;
        f.sample();
      }
      expect(paints, lessThanOrEqualTo(31));
      expect(paints, greaterThan(20));
    },
  );

  test(
    'hidden changes and reduced motion remain static without wall-time catchup',
    () {
      final s = session(hp: 15), f = watch(s);
      s.tick(.1);
      f.sample();
      final before = f.phase;
      f.sample(foreground: false);
      s.tick(.5);
      f.sample(foreground: false);
      s.progress.hp = 10;
      f.sample(foreground: true);
      expect(f.phase, before);
      expect(
        f.damageRemaining,
        0,
        reason: 'a hidden HP change is not replayed as a fresh hit',
      );
      f.sample(reducedMotion: true);
      final alpha = f.dangerOpacity;
      for (var i = 0; i < 10; i++) {
        s.tick(.1);
        f.sample(reducedMotion: true);
      }
      expect(f.phase, before);
      expect(f.dangerOpacity, alpha);
      expect(f.trailRatio, f.reading.value.ratio);
    },
  );

  test('death and victory hide the warning and stop all feedback motion', () {
    final s = session(hp: 15), f = watch(s);
    s.hurtHero(1000);
    f.sample();
    expect(s.defeated, true);
    expect(f.dangerOpacity, 0);
    expect(f.damageRemaining, 0);
    expect(f.needsFrames, false);
    final winning = session(hp: 15), winFeedback = watch(winning);
    winning.won = true;
    winFeedback.sample();
    expect(winFeedback.dangerOpacity, 0);
    expect(winFeedback.needsFrames, false);
  });

  test(
    'edge shader is transparent at center and never exceeds its one-pass opacity',
    () async {
      final s = session(hp: 15), f = watch(s);
      s.tick(.1);
      f.sample();
      final recorder = ui.PictureRecorder();
      final painter = HealthDangerPainter(f);
      painter.paint(ui.Canvas(recorder), const ui.Size(320, 420));
      final picture = recorder.endRecording(),
          image = await picture.toImage(320, 420);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        int alpha(int x, int y) => bytes[(y * 320 + x) * 4 + 3];
        expect(alpha(160, 210), 0);
        expect(alpha(0, 0), greaterThan(0));
        expect(alpha(0, 0), lessThanOrEqualTo((.18 * 255).ceil()));
        expect(alpha(160, 0), lessThanOrEqualTo((.18 * 255).ceil()));
      } finally {
        image.dispose();
        picture.dispose();
        painter.release();
      }
    },
  );
}

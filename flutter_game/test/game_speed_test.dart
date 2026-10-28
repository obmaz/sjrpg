import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/combat_feedback.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/main.dart';

import 'support/test_game.dart';

class _SpeedClock extends PositionComponent {
  double elapsed = 0;
  @override
  void update(double dt) {
    elapsed += dt;
    super.update(dt);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual game engine preserves 1.2 pacing through load, pause and hit-stop',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final art = (await t.runAsync(GameArt.load))!;
      final source = inCombatField(Adventure(GameArt()))..start(TestGame());
      final checkpoint = GameCheckpoint.capture(source)!;
      source.dispose();
      await t.pumpWidget(
        MaterialApp(
          home: GamePage(
            art: art,
            checkpoint: checkpoint,
            startPaused: true,
            onRestart: () {},
          ),
        ),
      );
      Adventure? s;
      for (var i = 0; i < 320; i++) {
        await t.pump(const Duration(milliseconds: 16));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
        final widgets = find.byType(BonfireWidget).evaluate();
        if (widgets.isNotEmpty) {
          s = ((widgets.single.widget as BonfireWidget).player! as Guardian)
              .session;
          if (s.ready) break;
        }
      }
      expect(s?.ready, true);
      final session = s!, engine = session.hero.gameRef as BonfireGame;
      expect(engine.timeScale, 1.2);
      expect(session.paused, true);
      session.resume();
      expect(engine.timeScale, 1.2);
      // Stop the widget's ticker and advance the real pinned engine explicitly.
      engine.pauseEngine();
      session.waveTime = 10000;
      session.hero.invulnerable = 1000;
      session.hero.attackClock = 10;
      final clock = _SpeedClock();
      await engine.world.add(clock);
      engine.update(.001);
      final before = session.elapsed, actorBefore = clock.elapsed;
      final attackBefore = session.hero.attackClock;
      for (var i = 0; i < 10; i++) {
        engine.update(1 / 30);
      }
      expect(session.elapsed - before, closeTo(.4, 1e-9));
      expect(clock.elapsed - actorBefore, closeTo(.4, 1e-9));
      expect(attackBefore - session.hero.attackClock, closeTo(.4, 1e-9));
      final feedback = CombatFeedback(
        game: () => engine,
        active: () => true,
        visible: (_) => true,
      );
      feedback.accepted(const AcceptedImpact(Offset.zero, 0, ImpactKind.heavy));
      await t.pump(Duration.zero);
      expect(engine.timeScale, 0);
      await t.pump(const Duration(milliseconds: 60));
      engine.update(1 / 30);
      expect(engine.timeScale, 1.2);
      feedback.dispose();
      session.pause();
      session.resume();
      expect(engine.timeScale, 1.2);
      engine.pauseEngine();
      session.hero.revivalProtection = CombatBalance.revivalProtection;
      for (var i = 0; i < 89; i++) {
        engine.update(1 / 30);
      }
      expect(session.hero.revivalProtection, closeTo(.04, 1e-8));
      engine.update(1 / 30);
      expect(session.hero.revivalProtection, closeTo(0, 1e-8));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      art.dispose();
      expect(t.takeException(), null);
    },
  );
}

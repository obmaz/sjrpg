import 'dart:async' as async;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bonfire/base/base_game.dart';
import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/combat_feedback.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';

import 'support/test_game.dart';

class _FeedbackGame extends TestGame {
  double _scale = 1;
  int stops = 0, resumes = 0;
  @override
  double get timeScale => _scale;
  @override
  set timeScale(double value) {
    if (value == 0) stops++;
    _scale = value;
  }

  @override
  void resumeEngine() {
    resumes++;
    super.resumeEngine();
  }

  List<ImpactParticles> get impacts =>
      added.whereType<ImpactParticles>().toList();
  void advanceFeedbackRecovery() {
    for (var i = 0; i < 3; i++) {
      for (final observer in added.whereType<CombatClockObserver>()) {
        observer.update(.1);
      }
    }
  }

  void observeStoppedUpdate() {
    for (final observer in added.whereType<CombatClockObserver>()) {
      observer.update(0);
    }
  }
}

class _ClockEngine extends BaseGame {}

class _EnginePort extends _FeedbackGame {
  _EnginePort(this.engine);
  final _ClockEngine engine;
  @override
  async.FutureOr<void> add(Component component) {
    super.add(component);
    return engine.world.add(component);
  }

  @override
  double get timeScale => engine.timeScale;
  @override
  set timeScale(double value) => engine.timeScale = value;
}

class _MovingActor extends PositionComponent {
  double clock = 0;
  @override
  void update(double dt) {
    clock += dt;
    position.x += dt * 100;
    super.update(dt);
  }
}

Adventure scene(TestGame game) {
  final session = Adventure(GameArt())..start(game);
  session.mobs.clear();
  session.hero.position.setValues(6000, 4200);
  return session;
}

HuntEnemy enemy(Adventure s, double x) =>
    s.spawnEnemy('goblin', Offset(x, 4200))!..life.initial(1000);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'rapid followups retain particles without repeatedly stopping the world',
    (tester) async {
      final game = _FeedbackGame(), s = scene(_FeedbackGame());
      s.game = game;
      addTearDown(s.dispose);
      final mob = enemy(s, 6050);
      s.hit(mob, 1, Offset.zero, impactKind: ImpactKind.melee);
      await tester.pump(Duration.zero);
      expect(game.stops, 1);
      game.observeStoppedUpdate();
      await tester.pump(const Duration(milliseconds: 55));
      expect(game.timeScale, 1);
      s.hit(mob, 1, Offset.zero, hitStop: false);
      await tester.pump(Duration.zero);
      expect(game.stops, 1);
      expect(game.impacts.length, greaterThan(1));
      s.hit(mob, 1, Offset.zero);
      await tester.pump(Duration.zero);
      expect(
        game.stops,
        1,
        reason: 'a new hit in the refractory interval is visual only',
      );
      game.advanceFeedbackRecovery();
      s.hit(mob, 1, Offset.zero);
      await tester.pump(Duration.zero);
      expect(game.stops, 2);
      game.observeStoppedUpdate();
      await tester.pump(const Duration(milliseconds: 55));
      expect(game.timeScale, 1);
    },
  );

  testWidgets(
    'accepted AoE applies damage immediately, batches two bursts and one maximum stop',
    (tester) async {
      final game = _FeedbackGame(), s = scene(_FeedbackGame());
      s.game = game;
      addTearDown(s.dispose);
      final targets = [for (var i = 0; i < 6; i++) enemy(s, 6050 + i * 15)];
      areaStrike(s, s.hero.body.center, 300, 100, maxTargets: 6);
      // A heavy contact in the same update upgrades, rather than adds to, the stop.
      s.hit(
        targets.first,
        10,
        const Offset(1, 0),
        impactKind: ImpactKind.heavy,
      );
      expect(targets.every((mob) => mob.life.value < 1000), true);
      expect(game.impacts, isEmpty);
      await tester.pump(Duration.zero);
      expect(game.impacts.length, 2);
      expect(game.stops, 1);
      expect(game.timeScale, 0);
      game.observeStoppedUpdate();
      await tester.pump(const Duration(milliseconds: 54));
      expect(game.timeScale, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(game.timeScale, 1);
      expect(game.stops, 1);
      expect(game.resumes, 0);
    },
  );

  testWidgets(
    'zero, invalid, sanctuary and unmounted contacts emit no impact',
    (tester) async {
      final game = _FeedbackGame(), s = scene(_FeedbackGame());
      s.game = game;
      addTearDown(s.dispose);
      final mob = enemy(s, 6050);
      for (final damage in [0.0, -1.0, double.nan, double.infinity]) {
        expect(s.hit(mob, damage, Offset.zero), false);
      }
      mob.combatReady = false;
      expect(s.hit(mob, 10, Offset.zero), false);
      mob.combatReady = true;
      mob.position.setValues(
        s.world.sanctuary.center.dx,
        s.world.sanctuary.center.dy,
      );
      expect(s.hit(mob, 10, Offset.zero), false);
      await tester.pump(Duration.zero);
      expect(game.impacts, isEmpty);
      expect(game.stops, 0);
      expect(mob.life.value, 1000);
    },
  );

  testWidgets(
    'slow melee freezes its normalized contact phase rather than jumping to the end',
    (tester) async {
      final game = _FeedbackGame();
      final s = scene(game);
      addTearDown(s.dispose);
      s.hero.swingDuration = 1;
      s.hero.swing = 1;
      s.hit(enemy(s, 6050), 10, const Offset(1, 0), generateRage: true);
      expect(s.hero.swing, .5);
      expect(s.hero.impactHold, 0);
      await tester.pump(Duration.zero);
      expect(game.timeScale, 0);
      s.combatFeedback.cancel();
    },
  );

  testWidgets(
    'offscreen damage stays authoritative without allocating feedback',
    (tester) async {
      final game = _FeedbackGame(), s = scene(_FeedbackGame());
      s.game = game;
      s.viewportSize = const ui.Size(390, 844);
      addTearDown(s.dispose);
      final mob = enemy(s, 6500);
      expect(s.hit(mob, 25, Offset.zero), true);
      expect(mob.life.value, 975);
      await tester.pump(Duration.zero);
      expect(game.impacts, isEmpty);
      expect(game.stops, 0);
    },
  );

  testWidgets(
    'killing contact rewards synchronously and still publishes particles once',
    (tester) async {
      final game = _FeedbackGame(), s = scene(_FeedbackGame());
      s.game = game;
      addTearDown(s.dispose);
      final mob = enemy(s, 6050)..life.update(1);
      final kills = s.progress.kills, gold = s.progress.gold;
      expect(s.hit(mob, 2, Offset.zero), true);
      expect(s.progress.kills, kills + 1);
      expect(s.progress.gold, greaterThan(gold));
      expect(s.hit(mob, 2, Offset.zero), false);
      await tester.pump(Duration.zero);
      expect(game.impacts.length, 1);
      expect(game.stops, 1);
      s.combatFeedback.cancel();
    },
  );

  testWidgets(
    'a stage-finishing boss contact publishes its particles before the victory pause',
    (tester) async {
      final game = _FeedbackGame();
      final s = scene(game);
      addTearDown(s.dispose);
      s.cleansedSites.addAll(s.world.sites.map((site) => site.id));
      final boss = s.spawnEnemy('orc', const Offset(6080, 4200), boss: true)!
        ..life.update(1);
      expect(s.hit(boss, 2, Offset.zero), true);
      expect(s.won, true);
      expect(s.progress.skillResetTickets, 1);
      expect(game.impacts.length, 1);
      expect(game.paused, true);
      expect(game.timeScale, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(game.impacts.length, 1);
      expect(game.paused, true);
      expect(game.resumes, 0);
    },
  );

  testWidgets(
    'pause cancels pending events and an owned stop without resuming the engine',
    (tester) async {
      final game = _FeedbackGame(), s = scene(_FeedbackGame());
      s.game = game;
      addTearDown(s.dispose);
      final mob = enemy(s, 6050);
      s.hit(mob, 10, Offset.zero);
      s.pause();
      await tester.pump(Duration.zero);
      expect(game.impacts, isEmpty);
      s.resume();
      game.timeScale = .75;
      s.hit(mob, 10, Offset.zero);
      await tester.pump(Duration.zero);
      expect(game.timeScale, 0);
      s.pause();
      expect(game.timeScale, .75);
      expect(game.paused, true);
      final resumes = game.resumes;
      await tester.pump(const Duration(seconds: 1));
      expect(game.paused, true);
      expect(game.resumes, resumes);
      expect(game.timeScale, .75);
    },
  );

  testWidgets(
    'late recovery restores only its old clock; new scene clock and pause stay unchanged',
    (tester) async {
      final old = _FeedbackGame(),
          next = _FeedbackGame(),
          s = scene(_FeedbackGame());
      s.game = old;
      addTearDown(s.dispose);
      s.hit(enemy(s, 6050), 10, Offset.zero);
      await tester.pump(Duration.zero);
      next.timeScale = .5;
      next.pauseEngine();
      s.game = next;
      await tester.pump(const Duration(milliseconds: 60));
      expect(old.timeScale, 1);
      expect(next.timeScale, .5);
      expect(next.paused, true);
      expect(next.resumes, 0);
    },
  );

  testWidgets(
    'death cancels the stop, and transient feedback never enters checkpoints',
    (tester) async {
      final game = _FeedbackGame(), s = scene(_FeedbackGame());
      s.game = game;
      addTearDown(s.dispose);
      s.hit(enemy(s, 6050), 10, Offset.zero);
      await tester.pump(Duration.zero);
      final cp = GameCheckpoint.capture(s)!;
      expect(cp.data.containsKey('hitstop'), false);
      expect(cp.data.containsKey('combatFeedback'), false);
      s.progress.hp = 1;
      s.syncLife();
      s.hurtHero(1000);
      expect(s.defeated, true);
      expect(game.timeScale, 1);
      expect(game.paused, true);
      await tester.pump(const Duration(seconds: 1));
      expect(game.paused, true);
      expect(game.resumes, 0);
    },
  );

  testWidgets(
    'particle lifetime budget is bounded and released on component removal',
    (tester) async {
      final game = _FeedbackGame(), s = scene(_FeedbackGame());
      s.game = game;
      addTearDown(s.dispose);
      final mobs = [enemy(s, 6050), enemy(s, 6075)];
      for (var i = 0; i < 8; i++) {
        for (final mob in mobs) {
          s.hit(mob, 1, Offset.zero);
        }
        await tester.pump(Duration.zero);
        game.observeStoppedUpdate();
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(game.impacts.length, CombatFeedback.maxLiveBursts);
      for (final burst in game.impacts) {
        burst.onRemove();
      }
      s.hit(mobs.first, 1, Offset.zero);
      await tester.pump(Duration.zero);
      expect(game.impacts.length, CombatFeedback.maxLiveBursts + 1);
      s.combatFeedback.cancel();
    },
  );

  testWidgets(
    'particle-cap contacts still wait for an observed stopped update without restarting the hold',
    (tester) async {
      final game = _FeedbackGame();
      final s = scene(game);
      addTearDown(s.dispose);
      final mob = enemy(s, 6050);
      for (var i = 0; i < CombatFeedback.maxLiveBursts; i++) {
        s.hit(mob, 1, Offset.zero, impactKind: ImpactKind.magic);
        await tester.pump(Duration.zero);
        game.observeStoppedUpdate();
        await tester.pump(const Duration(milliseconds: 22));
        game.advanceFeedbackRecovery();
      }
      expect(game.impacts.length, CombatFeedback.maxLiveBursts);
      final stops = game.stops;
      s.hit(mob, 1, Offset.zero, impactKind: ImpactKind.magic);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 22));
      expect(
        game.timeScale,
        0,
        reason: 'expired wall time alone is insufficient',
      );
      s.hit(mob, 1, Offset.zero, impactKind: ImpactKind.heavy);
      await tester.pump(Duration.zero);
      expect(game.stops, stops + 1);
      expect(game.impacts.length, CombatFeedback.maxLiveBursts);
      game.observeStoppedUpdate();
      expect(
        game.timeScale,
        1,
        reason: 'a late heavy contact never restarts the first hold',
      );
      await tester.pump(const Duration(milliseconds: 55));
      expect(game.timeScale, 1);
    },
  );

  testWidgets(
    'pause and disposal clear deadline waiting and ignore late observer updates',
    (tester) async {
      final game = _FeedbackGame();
      final s = scene(game);
      addTearDown(() {
        if (!s.disposed) s.dispose();
      });
      final mob = enemy(s, 6050);
      s.hit(mob, 1, Offset.zero, impactKind: ImpactKind.magic);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 33));
      expect(game.timeScale, 0);
      s.pause();
      expect(game.timeScale, 1);
      game.observeStoppedUpdate();
      expect(game.paused, true);
      expect(game.resumes, 0);
      s.resume();
      s.hit(mob, 1, Offset.zero, impactKind: ImpactKind.magic);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 33));
      expect(game.timeScale, 0);
      s.dispose();
      expect(game.timeScale, 1);
      game.observeStoppedUpdate();
      await tester.pump(const Duration(seconds: 1));
      expect(game.timeScale, 1);
      expect(game.resumes, 1, reason: 'only the explicit user resume ran');
    },
  );

  testWidgets(
    'pinned Bonfire BaseGame stops every actor and Flame particle clock, then recovers',
    (tester) async {
      final engine = _ClockEngine();
      engine.onGameResize(Vector2(390, 844));
      // Mount the pinned engine directly to drive exact simulation dt without
      // a widget ticker. Production still uses BonfireWidget's normal loader.
      // ignore: invalid_use_of_internal_member
      await engine.load();
      // ignore: invalid_use_of_internal_member
      engine.mount();
      final actor = _MovingActor();
      final fx = ImpactParticles(
        const AcceptedImpact(Offset.zero, 0, ImpactKind.melee),
        onFinished: () {},
      );
      await engine.world.addAll([actor, fx]);
      engine.update(.033);
      final game = _EnginePort(engine);
      final feedback = CombatFeedback(
        game: () => game,
        active: () => true,
        visible: (_) => true,
      );
      addTearDown(feedback.dispose);
      feedback.accepted(const AcceptedImpact(Offset.zero, 0, ImpactKind.melee));
      await tester.pump(Duration.zero);
      final position = actor.position.x,
          clock = actor.clock,
          age = fx.particles.progress;
      engine.update(.033);
      expect(actor.position.x, position);
      expect(actor.clock, clock);
      expect(fx.particles.progress, age);
      await tester.pump(const Duration(milliseconds: 35));
      engine.update(.033);
      expect(actor.position.x, greaterThan(position));
      expect(actor.clock, greaterThan(clock));
      expect(fx.particles.progress, greaterThan(age));
      engine.onRemove();
    },
  );

  for (final entry in [
    (kind: ImpactKind.magic, frame: const Duration(microseconds: 33333)),
    (kind: ImpactKind.lightning, frame: const Duration(microseconds: 33333)),
    (kind: ImpactKind.melee, frame: const Duration(microseconds: 66667)),
    (kind: ImpactKind.heavy, frame: const Duration(microseconds: 100000)),
  ]) {
    testWidgets(
      '${entry.kind} really stops one pinned engine tick when its deadline precedes the next frame',
      (tester) async {
        final engine = _ClockEngine();
        engine.onGameResize(Vector2(390, 844));
        // Exact pinned engine setup, independent from a widget ticker.
        // ignore: invalid_use_of_internal_member
        await engine.load();
        // ignore: invalid_use_of_internal_member
        engine.mount();
        final beforeObserver = _MovingActor()..priority = -2147483648;
        final afterObserver = _MovingActor()..priority = 100;
        final fx = ImpactParticles(
          const AcceptedImpact(Offset.zero, 0, ImpactKind.heavy),
          onFinished: () {},
        );
        await engine.world.addAll([beforeObserver, afterObserver, fx]);
        engine.update(.001);
        final game = _EnginePort(engine);
        final feedback = CombatFeedback(
          game: () => game,
          active: () => true,
          visible: (_) => true,
        );
        addTearDown(feedback.dispose);
        feedback.accepted(AcceptedImpact(Offset.zero, 0, entry.kind));
        await tester.pump(Duration.zero);
        final firstClock = beforeObserver.clock,
            secondClock = afterObserver.clock,
            particleAge = fx.particles.progress;
        // At 30fps a 22/24ms wall timer expires before the next 33ms update.
        // No update is fabricated between acceptance and deadline expiry.
        await tester.pump(entry.frame);
        engine.update(entry.frame.inMicroseconds / 1000000);
        expect(beforeObserver.clock, firstClock);
        expect(afterObserver.clock, secondClock);
        expect(fx.particles.progress, particleAge);
        expect(
          game.timeScale,
          1,
          reason:
              'the deadline passed and an actual stopped update was observed',
        );
        engine.update(1 / 30);
        expect(beforeObserver.clock, greaterThan(firstClock));
        expect(afterObserver.clock, greaterThan(secondClock));
        expect(fx.particles.progress, greaterThan(particleAge));
        engine.onRemove();
      },
    );
  }

  test('rank growth is visible but its particle budget remains capped', () {
    ImpactParticles burst(int rank) => ImpactParticles(
      AcceptedImpact(Offset.zero, 0, ImpactKind.heavy, rank: rank),
      onFinished: () {},
    );
    int count(ImpactParticles burst) =>
        ((burst.particles.particle! as ComposedParticle).children[1]
                as ComposedParticle)
            .children
            .length;
    expect(
      [for (var rank = 1; rank <= 5; rank++) count(burst(rank))],
      [6, 6, 7, 7, 8],
    );
    expect(count(burst(100000)), 8);
    expect(
      burst(5).particles.particle!.lifespan,
      greaterThan(burst(1).particles.particle!.lifespan),
    );
  });

  test(
    'Flame accelerated sparks generate distinct 30fps frames without sprite assets',
    () async {
      final recorder = ui.PictureRecorder();
      // Separate recorder below keeps each frame's raster assertion independent.
      final sheet = ui.Canvas(recorder);
      final proof = Directory('/tmp/mobile62-feedback-proof')
        ..createSync(recursive: true);
      for (var row = 0; row < ImpactKind.values.length; row++) {
        final impact = AcceptedImpact(Offset.zero, .25, ImpactKind.values[row]);
        final burst = ImpactParticles(impact, onFinished: () {});
        final hashes = <int>{};
        for (var frame = 0; frame < 7; frame++) {
          if (frame > 0) burst.particles.update(1 / 30);
          final single = ui.PictureRecorder(), surface = ui.Canvas(single);
          surface.translate(60, 60);
          burst.particles.render(surface);
          final pic = single.endRecording(),
              image = await pic.toImage(120, 120);
          final bytes = (await image.toByteData())!.buffer.asUint8List();
          hashes.add(Object.hashAll(bytes));
          sheet.drawImage(
            image,
            ui.Offset(frame * 120.0, row * 120.0),
            ui.Paint(),
          );
          image.dispose();
          pic.dispose();
        }
        expect(
          hashes.length,
          7,
          reason: 'Every 30fps frame has new particle geometry: ${impact.kind}',
        );
      }
      final picture = recorder.endRecording(),
          image = await picture.toImage(840, 720);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${proof.path}/impacts-30fps.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    },
  );
}

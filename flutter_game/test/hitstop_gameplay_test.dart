import 'dart:async' as async;
import 'dart:math' as math;

import 'package:bonfire/base/base_game.dart';
import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/combat_feedback.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/player_afflictions.dart';

import 'support/test_game.dart';

class _Engine extends BaseGame {}

class _Port extends TestGame {
  _Port(this.engine);
  final _Engine engine;
  @override
  double get timeScale => engine.timeScale;
  @override
  set timeScale(double value) => engine.timeScale = value;
  @override
  async.FutureOr<void> add(Component component) {
    super.add(component);
    return engine.world.add(component);
  }
}

class _SessionTicker extends Component {
  _SessionTicker(this.session);
  final Adventure session;
  @override
  void update(double dt) => session.tick(dt);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Engine engine;
  late _Port game;
  late Adventure s;
  late HuntEnemy source;
  Future<void> prepare() async {
    engine = _Engine()..onGameResize(Vector2(390, 844));
    // Exact engine harness: a widget ticker does not add extra positive dt.
    // ignore: invalid_use_of_internal_member
    await engine.load();
    // ignore: invalid_use_of_internal_member
    engine.mount();
    game = _Port(engine);
    s = Adventure(GameArt())..start(game);
    s.mobs.clear();
    s.hero.position.setValues(6000, 4200);
    source = s.spawnEnemy('goblin', const Offset(6050, 4200))!
      ..life.initial(1000);
    await engine.world.add(s.hero);
    engine.update(.001);
    addTearDown(() {
      s.dispose();
      engine.onRemove();
    });
  }

  Future<void> accept(WidgetTester tester) async {
    expect(s.hit(source, 1, Offset.zero, impactKind: ImpactKind.magic), true);
    await tester.pump(Duration.zero);
    expect(engine.timeScale, 0);
  }

  testWidgets(
    'held input must not create a second damage transaction on a frozen engine update',
    (tester) async {
      await prepare();
      s.hero.attackClock = 0;
      s.holdAttack('touch', true);
      await accept(tester);
      final hp = source.life.value;
      final strikes = s.hero.strikes;
      engine.update(1 / 30);
      expect(
        source.life.value,
        hp,
        reason:
            'the accepted magic contact is the only transaction while stopped',
      );
      expect(s.hero.strikes, strikes);
      await tester.pump(const Duration(milliseconds: 22));
      engine.update(1 / 30);
      expect(source.life.value, lessThan(hp));
      expect(s.hero.strikes, strikes + 1);
      s.combatFeedback.cancel();
    },
  );

  testWidgets('a due encounter pack must wait for positive simulation time', (
    tester,
  ) async {
    await prepare();
    s.elapsed = 20;
    s.waveTime = 0;
    s.lastPackSpawn = -10;
    await engine.world.add(_SessionTicker(s));
    await accept(tester);
    final count = s.mobs.length, elapsed = s.elapsed;
    engine.update(1 / 30);
    expect(s.elapsed, elapsed);
    expect(
      s.mobs.length,
      count,
      reason: 'the frozen WorldDirector clock must not spawn a wave',
    );
    await tester.pump(const Duration(milliseconds: 22));
    engine.update(1 / 30);
    expect(s.elapsed, greaterThan(elapsed));
    expect(s.mobs.length, greaterThan(count));
    s.combatFeedback.cancel();
  });

  testWidgets(
    'a ready boss must not begin a new warning during a frozen engine update',
    (tester) async {
      await prepare();
      final boss = s.spawnEnemy('orc', const Offset(6150, 4200), boss: true)!;
      engine.update(.001);
      boss.slamClock = 0;
      boss.windup = 0;
      boss.bossAttack = null;
      final sequence = boss.bossSequence;
      await accept(tester);
      engine.update(1 / 30);
      expect(
        boss.windup,
        0,
        reason:
            'ready AI should remain ready, not start its next attack while world time is stopped',
      );
      expect(boss.bossSequence, sequence);
      expect(game.added.whereType<BossAttackVisual>(), isEmpty);
      await tester.pump(const Duration(milliseconds: 22));
      engine.update(1 / 30);
      expect(boss.windup, greaterThan(0));
      expect(boss.bossSequence, sequence + 1);
      expect(game.added.whereType<BossAttackVisual>().length, 1);
      s.combatFeedback.cancel();
    },
  );
  testWidgets(
    'an already-flying net bolt must not collide during a frozen update after the hero moved into its path',
    (tester) async {
      await prepare();
      final bolt = ShadowBolt(
        s,
        const Offset(6056, 4204),
        math.pi,
        damage: 8,
        status: PlayerStatus.root,
      );
      await engine.world.add(bolt);
      // ShadowBolt sorts before the hero by world depth. This positive tick
      // advances the existing bolt, then moves the hero into that path.
      s.hero.velocity = Vector2(270, 0);
      engine.update(.05);
      expect(s.hero.position.x, greaterThan(6000));
      expect(bolt.resolved, false);
      expect(s.hero.body.inflate(7).contains(bolt.position.toOffset()), true);
      final hp = s.progress.hp;
      expect(s.afflictions.remaining(PlayerStatus.root), 0);
      await accept(tester);
      engine.update(1 / 30);
      expect(
        s.progress.hp,
        hp,
        reason: 'no new enemy projectile damage transaction while stopped',
      );
      expect(s.afflictions.remaining(PlayerStatus.root), 0);
      expect(bolt.resolved, false);
      await tester.pump(const Duration(milliseconds: 22));
      engine.update(1 / 30);
      expect(s.progress.hp, lessThan(hp));
      expect(s.afflictions.remaining(PlayerStatus.root), greaterThan(0));
      expect(bolt.resolved, true);
      s.combatFeedback.cancel();
    },
  );

  testWidgets(
    'explicit input remains an immediate damage transaction while the engine clock is held',
    (tester) async {
      await prepare();
      await accept(tester);
      final hp = source.life.value;
      s.hero.attackClock = 0;
      s.hero.slash();
      expect(source.life.value, lessThan(hp));
      final afterInput = source.life.value;
      final strikes = s.hero.strikes;
      engine.update(1 / 30);
      expect(source.life.value, afterInput);
      expect(s.hero.strikes, strikes);
      s.combatFeedback.cancel();
    },
  );
  testWidgets(
    'an already-flying player bolt must not collide during a frozen update after an enemy moved into its path',
    (tester) async {
      await prepare();
      final bolt = ArcaneBolt(s, const Offset(6011.5, 4208), 0, 25);
      await engine.world.add(bolt);
      // The existing projectile updates before the enemy by world depth. Its
      // positive flight step misses, then the enemy moves into that position.
      engine.update(.05);
      expect(bolt.resolved, false);
      expect(source.body.inflate(7).contains(bolt.position.toOffset()), true);
      await accept(tester);
      final hp = source.life.value;
      engine.update(1 / 30);
      expect(
        source.life.value,
        hp,
        reason:
            'a stationary existing player bolt cannot add damage while stopped',
      );
      expect(bolt.resolved, false);
      await tester.pump(const Duration(milliseconds: 22));
      engine.update(1 / 30);
      expect(source.life.value, lessThan(hp));
      expect(bolt.resolved, true);
      s.combatFeedback.cancel();
    },
  );
  testWidgets(
    'IDLE during a held engine clock cannot leak one movement step after recovery',
    (tester) async {
      await prepare();
      s.hero.onJoystickChangeDirectional(
        JoystickDirectionalEvent(
          directional: JoystickMoveDirectional.MOVE_RIGHT,
          intensity: 1,
        ),
      );
      engine.update(.05);
      expect(s.hero.velocity.x, greaterThan(0));
      final at = s.hero.position.clone();
      await accept(tester);
      s.hero.onJoystickChangeDirectional(
        JoystickDirectionalEvent(directional: JoystickMoveDirectional.IDLE),
      );
      engine.update(1 / 30);
      await tester.pump(const Duration(milliseconds: 22));
      engine.update(1 / 30);
      expect(
        s.hero.position,
        at,
        reason:
            'pointer cancellation during hitstop must clear old velocity before the next positive frame',
      );
      expect(s.hero.velocity.isZero(), true);
      s.combatFeedback.cancel();
    },
  );
}

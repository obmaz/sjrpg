import 'dart:math' as math;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Adventure field({WorldStage stage = WorldStage.forest}) {
    final session = inCombatField(Adventure(GameArt(), stage: stage))
      ..start(TestGame());
    addTearDown(session.dispose);
    return session;
  }

  Offset stored(Offset at) => Vector2(at.dx, at.dy).toOffset();

  void commit(Adventure session, HuntEnemy enemy, Offset at) {
    expect(
      at,
      stored(at),
      reason: 'accepted endpoints must already be Float32',
    );
    enemy.position.setValues(at.dx, at.dy);
    session.updateEnemySpacing(enemy);
    expect(enemy.body.topLeft, at);
    expect(session.world.blocksEnemy(enemy.body), false);
  }

  HuntEnemy spawn(Adventure session, Offset at) {
    final enemy = session.spawnEnemy('goblin', at)!;
    expect(enemy.body.topLeft, at);
    return enemy;
  }

  ({Offset desired, Offset from}) wardContact(Adventure session) {
    final ward = session.world.sanctuary;
    const size = Size(24, 22);
    for (var angle = .08; angle < math.pi / 2; angle += .017) {
      final y = stored(
        ward.center + Offset(0, math.sin(angle) * ward.radius),
      ).dy;
      final dy = y - ward.center.dy;
      final x = ward.center.dx + math.sqrt(ward.radius * ward.radius - dy * dy);
      final desired = Offset(x + .0000001, y);
      final from = stored(desired + const Offset(2, 0));
      if (session.world.blocksEnemy(desired & size) ||
          !session.world.blocksEnemy(stored(desired) & size) ||
          session.world.blocksEnemy(from & size)) {
        continue;
      }
      final geometric = session.world.moveEnemy(from, desired - from, size);
      if (!session.world.blocksEnemy(geometric & size) &&
          session.world.blocksEnemy(stored(geometric) & size)) {
        return (desired: desired, from: from);
      }
    }
    throw StateError(
      'current ward must expose a legal double/blocked Float32 contact',
    );
  }

  double openRow(Adventure session) {
    for (var y = 2000.0; y < 16000; y += 64) {
      if (!session.world.blocksEnemy(Rect.fromLTWH(8170, y - 20, 100, 80))) {
        return y;
      }
    }
    throw StateError('precision fixture needs a clear row across x8192');
  }

  test(
    'ordinary spawned scorpion stays outside ward after112 settling steps',
    () {
      final session = Adventure(GameArt(), stage: WorldStage.sands)
        ..start(TestGame());
      addTearDown(session.dispose);
      final ward = session.world.sanctuary;
      final at =
          ward.center + const Offset(.7, .714142842854285) * (ward.radius + 12);
      session.hero.position.setValues(at.dx, at.dy);
      session.hero.lastClearPosition = session.hero.position.toOffset();
      session.progress.bonusHealth = 2000;
      session.progress.hp = session.progress.maxHp;
      session.syncLife();
      expect(session.sheltered, false);
      expect(session.world.blocked(session.hero.body), isFalse);
      final scorpion = session.spawnEnemy(
        'scorpion',
        session.hero.body.center + const Offset(0, 280),
      )!;
      for (var frame = 0; frame <= 111; frame++) {
        session.tick(1 / 30);
        for (final enemy in session.mobs.toList()) {
          enemy.update(1 / 30);
          expect(
            session.world.blocksEnemy(enemy.body),
            false,
            reason: 'frame$frame ${enemy.kind} at${enemy.body.topLeft}',
          );
          expect(enemy.lastClearPosition, enemy.body.topLeft);
        }
      }
      expect(session.mobs, contains(scorpion));
      expect(scorpion.kind, 'scorpion');
      expect(session.progress.hp, greaterThan(0));
    },
  );

  test('invalid rounded fast-path ward slide falls through safely', () {
    final session = field(stage: WorldStage.sands);
    final contact = wardContact(session);
    final from = contact.from, nudge = contact.desired - contact.from;
    final enemy = spawn(session, from);
    final geometric = session.world.moveEnemy(from, nudge, enemy.body.size);
    expect(session.world.blocksEnemy(geometric & enemy.body.size), false);
    expect(
      session.world.blocksEnemy(stored(geometric) & enemy.body.size),
      true,
    );
    final at = session.moveEnemyBody(enemy, from, nudge);
    commit(session, enemy, at);
    expect(at, from);
  });

  test('touching another body is checked after Float32 conversion', () {
    final session = field();
    final y = openRow(session);
    final obstacle = spawn(session, Offset(8191.99853515625, y));
    final enemy = spawn(session, Offset(8216, y));
    final from = enemy.body.topLeft;
    final touching = Offset(obstacle.body.right, y);
    expect((touching & enemy.body.size).overlaps(obstacle.body), false);
    expect((stored(touching) & enemy.body.size).overlaps(obstacle.body), true);
    final at = session.moveEnemyBody(enemy, from, touching - from);
    commit(session, enemy, at);
    expect(enemy.body.overlaps(obstacle.body), false);
    expect(at, from);
  });

  test('rounded terrain contact cannot enter an actual static prop', () {
    final session = field();
    for (final prop in session.world.props) {
      for (final solid in prop.collisionBodies) {
        final touching = Offset(solid.right, solid.center.dy - 11);
        final from = stored(touching + const Offset(2, 0));
        const size = Size(24, 22);
        if (session.world.blocksEnemy(touching & size) ||
            !session.world.blocksEnemy(stored(touching) & size) ||
            session.world.blocksEnemy(from & size) ||
            (from & size).inflate(64).overlaps(session.hero.body)) {
          continue;
        }
        final geometric = session.world.moveEnemy(from, touching - from, size);
        if (session.world.blocksEnemy(geometric & size) ||
            !session.world.blocksEnemy(stored(geometric) & size)) {
          continue;
        }
        final enemy = spawn(session, from);
        final at = session.moveEnemyBody(enemy, from, touching - from);
        commit(session, enemy, at);
        expect(enemy.body.overlaps(solid), false);
        return;
      }
    }
    fail('authored static geometry must supply a Float32 contact boundary');
  });

  test(
    'hero contact uses stored coordinates and preserves avoidHero opt-out',
    () {
      final session = field();
      final y = openRow(session);
      session.hero.position.setValues(8191.99853515625, y);
      final enemy = spawn(session, Offset(8220, y));
      final from = enemy.body.topLeft;
      final touching = Offset(session.hero.body.right, y);
      expect((touching & enemy.body.size).overlaps(session.hero.body), false);
      expect(
        (stored(touching) & enemy.body.size).overlaps(session.hero.body),
        true,
      );
      final at = session.moveEnemyBody(enemy, from, touching - from);
      commit(session, enemy, at);
      expect(enemy.body.overlaps(session.hero.body), false);
      final pounce = session.moveEnemyBody(
        enemy,
        from,
        touching - from,
        avoidHero: false,
      );
      expect((pounce & enemy.body.size).overlaps(session.hero.body), true);
      expect(pounce, stored(pounce));
    },
  );

  test(
    'axis sliding commits a canonical body without crossing the blocker',
    () {
      final session = field();
      const from = Offset(6200.3125, 4200.4375);
      final enemy = spawn(session, from);
      final obstacle = spawn(session, from + const Offset(24, 0));
      final at = session.moveEnemyBody(enemy, from, const Offset(4.13, 3.17));
      commit(session, enemy, at);
      expect(at.dx, from.dx);
      expect(at.dy, greaterThan(from.dy));
      expect(enemy.body.overlaps(obstacle.body), false);
    },
  );

  test('flanking can escape an old overlap without crossing side blockers', () {
    final session = field();
    const from = Offset(6200, 4200);
    final enemy = spawn(session, from);
    final lower = spawn(session, from + const Offset(24, 19));
    final upper = spawn(session, from + const Offset(24, -19));
    final oldOverlap = spawn(session, from - const Offset(30, 0));
    oldOverlap.position.x = from.dx - 23;
    session.updateEnemySpacing(oldOverlap);
    expect(enemy.body.overlaps(oldOverlap.body), true);
    final beforeArea = enemy.body.intersect(oldOverlap.body);
    final at = session.moveEnemyBody(
      enemy,
      from,
      const Offset(6, 0),
      steer: true,
    );
    expect(
      session.enemySpacing.steer(
        enemy,
        from & enemy.body.size,
        const Offset(6, 0),
        [lower, upper, oldOverlap],
      ).dy,
      0,
      reason: 'no vertical axis step exists; side progress uses the flank loop',
    );
    commit(session, enemy, at);
    expect(at.dx, from.dx);
    expect((at.dy - from.dy).abs(), greaterThan(1));
    expect(enemy.body.overlaps(lower.body), false);
    expect(enemy.body.overlaps(upper.body), false);
    final afterArea = enemy.body.intersect(oldOverlap.body);
    expect(
      afterArea.width * afterArea.height,
      lessThan(beforeArea.width * beforeArea.height),
    );
  });

  test('soft spacing leaves an exact body-width corridor traversable', () {
    final session = field();
    const from = Offset(6200.3125, 4200.4375);
    final enemy = spawn(session, from);
    final upper = spawn(session, from - const Offset(0, 22));
    final lower = spawn(session, from + const Offset(0, 22));
    final at = session.moveEnemyBody(
      enemy,
      from,
      const Offset(25.13, 0),
      steer: true,
    );
    expect(
      session.enemySpacing.permitsPersonalSpace(
        enemy,
        enemy.body,
        at & enemy.body.size,
        upper,
      ),
      true,
    );
    expect(
      session.enemySpacing.permitsPersonalSpace(
        enemy,
        enemy.body,
        at & enemy.body.size,
        lower,
      ),
      true,
    );
    commit(session, enemy, at);
    expect(at.dx, greaterThan(from.dx + 20));
    expect(at.dy, from.dy);
    expect(enemy.body.overlaps(upper.body), false);
    expect(enemy.body.overlaps(lower.body), false);
  });

  test('uncongested valid endpoint matches the old actual stored position', () {
    final session = field();
    const from = Offset(6200.3125, 4200.4375);
    final enemy = spawn(session, from);
    for (final delta in [
      const Offset(.15, .25),
      const Offset(-.37, .19),
      const Offset(3.13, -2.73),
      const Offset(25.1, 7.2),
    ]) {
      final geometric = session.world.moveEnemy(from, delta, enemy.body.size);
      final expected = stored(geometric);
      expect(session.world.blocksEnemy(expected & enemy.body.size), false);
      final at = session.moveEnemyBody(enemy, from, delta);
      expect(at, expected);
      expect(at, stored(at));
    }
  });

  test('nearby nonblocking neighbor does not round each geometric substep', () {
    final session = field();
    const from = Offset(6200.3125, 4200.4375);
    final enemy = spawn(session, from);
    final neighbor = spawn(session, from + const Offset(0, 60));
    for (final delta in [
      const Offset(25.1, 7.2),
      const Offset(42.133, 0),
      const Offset(-25.1, 7.2),
    ]) {
      final geometric = session.world.moveEnemy(from, delta, enemy.body.size);
      final expected = stored(geometric);
      expect(session.world.blocksEnemy(expected & enemy.body.size), false);
      expect((expected & enemy.body.size).overlaps(neighbor.body), false);
      final at = session.moveEnemyBody(enemy, from, delta);
      expect(
        [at.dx, at.dy],
        [expected.dx, expected.dy],
        reason: 'a nearby nonblocking body must not introduce extra commits',
      );
      expect(at, stored(at));
    }
  });
}

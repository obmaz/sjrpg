import 'dart:convert';
import 'dart:math' as math;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stage in WorldStage.values) {
    test('$stage denies a close melee target across an open safety gate', () {
      final s = Adventure(GameArt(), stage: stage)..start(TestGame());
      addTearDown(s.dispose);
      final ward = s.world.sanctuary;
      // This assertion concerns hostile targets. Chest attacks are explicitly
      // allowed inside a village, so remove them from this combat fixture.
      s.world.openedChests.addAll(
        List.generate(s.world.chests.length, (i) => i),
      );
      final gate = s.world.authoredSettlement.gatePaths.last.last;
      final gateOffset = gate - ward.center;
      final angle = math.atan2(gateOffset.dy, gateOffset.dx);
      final direction = Offset(math.cos(angle), math.sin(angle));
      final inside =
          ward.center + direction * (ward.radius - 10) - const Offset(14, 12);
      s.hero.position.setValues(inside.dx, inside.dy);
      expect(s.world.blocked(s.hero.body), false);
      final enemyAt =
          ward.center + direction * (ward.radius + 20) - const Offset(12, 11);
      final mob = s.spawnEnemy('goblin', enemyAt)!;
      expect(
        (mob.body.center - s.hero.body.center).distance,
        lessThan(s.progress.weapon.base.range + mob.size.x / 2),
      );
      final health = mob.life.value;
      s.hero.slash();
      expect(mob.life.value, health);
      expect(s.hero.attackClock, 0);
      final outside =
          ward.center + direction * (ward.radius + 50) - const Offset(14, 12);
      s.hero.position.setValues(outside.dx, outside.dy);
      expect(s.sheltered, false);
      s.hero.slash();
      expect(mob.life.value, lessThan(health));
    });
    test(
      '$stage sanctuary blocks incoming and outgoing combat including boundary targets',
      () {
        final session = Adventure(GameArt(), stage: stage)..start(TestGame());
        addTearDown(session.dispose);
        final ward = session.world.sanctuary;
        expect(session.sheltered, true);
        expect(
          session.mobs,
          isEmpty,
          reason: 'peaceful starts do not spend encounter packs',
        );
        // Protected prop strikes have separate coverage; this scene has no props to hit.
        session.openedChests.addAll(
          List.generate(session.stageChestLocations.length, (index) => index),
        );
        final mob = session.spawnEnemy('goblin', ward.center)!;
        expect(ward.protects(mob.body), false);
        final health = mob.life.value,
            hp = session.progress.hp,
            energy = session.progress.energy;
        session.hero.invulnerable = 0;
        session.hurtHero(100000, origin: mob.body.center);
        expect(session.progress.hp, hp);
        expect(session.defeated, false);
        expect(
          session.hit(mob, 100000, Offset.zero, generateRage: true),
          false,
        );
        areaStrike(session, mob.body.center, 100, 100000, stun: 3, slow: 3);
        expect(mob.life.value, health);
        expect(mob.stun, 0);
        expect(mob.slow, 0);
        session.hero.slash();
        session.hero.skill();
        expect(session.hero.attackClock, 0);
        expect(session.hero.cooldowns, isEmpty);
        expect(session.progress.energy, energy);
        final outside = session.world.spawnNear(
          mob.position.toOffset() + const Offset(0, 70),
          session.hero.body.size,
          avoidSanctuary: true,
        )!;
        session.hero.position.setValues(outside.dx, outside.dy);
        expect(session.sheltered, false);
        expect(session.hit(mob, 5, Offset.zero), true);
        expect(mob.life.value, health - 5);
        session.hurtHero(10, origin: mob.body.center);
        expect(session.progress.hp, lessThan(hp));
      },
    );

    test('$stage movement and knockback keep entire enemy bodies out', () {
      final session = Adventure(GameArt(), stage: stage)..start(TestGame());
      addTearDown(session.dispose);
      final ward = session.world.sanctuary;
      final mob = session.spawnEnemy(
        'goblin',
        ward.center + Offset(ward.radius + 20, 0),
      )!;
      final before = mob.position.toOffset();
      final moved = session.world.moveEnemy(
        before,
        ward.center - mob.body.center,
        mob.body.size,
      );
      expect(ward.protects(moved & mob.body.size), false);
      mob.push(const Offset(-80, 0));
      for (var frame = 0; frame < 30; frame++) {
        mob.update(1 / 60);
        expect(ward.protects(mob.body), false);
      }
      expect(
        session.world.clearEnemyLine(
          ward.center - Offset(ward.radius + 100, 0),
          ward.center + Offset(ward.radius + 100, 0),
          const Size(24, 22),
        ),
        false,
      );
    });

    test(
      '$stage friendly and hostile projectiles stop at the peace boundary',
      () {
        final session = Adventure(GameArt(), stage: stage)..start(TestGame());
        addTearDown(session.dispose);
        final ward = session.world.sanctuary;
        final from = ward.center + Offset(ward.radius + 35, 0);
        final friendly = ArcaneBolt(session, from, 3.141592653589793, 999);
        final hostile = ShadowBolt(
          session,
          from,
          3.141592653589793,
          damage: 999,
        );
        for (var frame = 0; frame < 50; frame++) {
          friendly.update(.05);
          hostile.update(.05);
        }
        expect(friendly.resolved, true);
        expect(hostile.resolved, true);
        expect(session.defeated, false);
      },
    );
  }
  for (final boss in [false, true]) {
    test(
      'an old saved ${boss ? 'boss' : 'enemy'} moves outside without losing health',
      () {
        final source = Adventure(GameArt())..start(TestGame());
        addTearDown(source.dispose);
        final mob = source.spawnEnemy(
          'goblin',
          source.world.spawn,
          boss: boss,
        )!;
        mob.life.initial(500);
        mob.life.update(175);
        final data = GameCheckpoint.capture(source)!.data;
        final raw = boss
            ? data['boss'] as Map
            : (data['enemies'] as List).single as Map;
        raw['x'] = source.world.spawn.dx + 30;
        raw['y'] = source.world.spawn.dy + 30;
        final restored = GameCheckpoint.decode(
          jsonEncode(data),
        )!.restore(GameArt())..start(TestGame());
        addTearDown(restored.dispose);
        final enemy = restored.mobs.single;
        expect(restored.world.sanctuary.protects(enemy.body), false);
        expect(enemy.life.max, 500);
        expect(enemy.life.value, 175);
      },
    );
  }
  test(
    'leaving a peaceful new start brings its first pack without a wasted respawn timer',
    () {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      expect(s.mobs, isEmpty);
      expect(s.encounterAreas, isEmpty);
      s.tick(20);
      expect(s.encounterAreas, isEmpty);
      s.hero.position.setValues(6000, 4200);
      s.tick(.05);
      expect(s.mobs.length, inInclusiveRange(1, 6));
      expect(s.encounterAreas.values.single.waves, 1);
    },
  );
}

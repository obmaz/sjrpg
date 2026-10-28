import 'dart:convert';
import 'dart:math' as math;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field() {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    s.mobs.clear();
    s.waveTime = 10000;
    addTearDown(s.dispose);
    return s;
  }

  for (final id in ['leap', 'leapAttack']) {
    for (final blocked in ['root', 'freeze', 'paused']) {
      test(
        '$id aim and activation preserve a mounted rider while $blocked',
        () {
          final s = field();
          s.progress.level = 100;
          s.progress.ranks.addAll({'leap': 1, 'leapAttack': 1});
          expect(s.progress.selectSkill(id), true);
          final mount = withOwnedMounts(s).mounts.first
            ..at = s.hero.body.center + const Offset(40, 0);
          expect(s.boardNearbyMount(), true);
          if (blocked == 'paused') {
            s.pause();
          } else {
            s.afflictions.apply(
              blocked == 'root' ? PlayerStatus.root : PlayerStatus.freeze,
            );
          }
          final energy = s.progress.energy, body = s.hero.body;
          s.hero.beginAim(0);
          s.hero.skill();
          s.hero.dodge();
          expect(s.hero.aim, isNull);
          expect(s.riding, same(mount));
          expect(s.hero.body, body);
          expect(s.hero.barbarianCombat.airborne, false);
          expect(s.hero.cooldowns[id], isNull);
          expect(s.progress.energy, energy);
        },
      );
    }
  }

  test(
    'crowds cannot refresh, alternate or permanently chain movement locks',
    () {
      final state = PlayerAfflictions();
      expect(state.apply(PlayerStatus.root), true);
      expect(state.apply(PlayerStatus.freeze), false);
      state.update(1.4);
      expect(state.movementBlocked, false);
      expect(state.apply(PlayerStatus.root), false);
      state.update(1.51);
      expect(state.apply(PlayerStatus.freeze), true);
      state.update(.75);
      expect(state.frozen, false);
      expect(state.apply(PlayerStatus.root), false);
      expect(state.apply(PlayerStatus.blind), true);
      state.update(2.8);
      expect(state.remaining(PlayerStatus.blind), 0);
      expect(state.apply(PlayerStatus.blind), false);
    },
  );

  test(
    'poison is four bounded nonrefreshing ticks and saves fractional progress',
    () {
      final state = PlayerAfflictions();
      state.apply(PlayerStatus.poison);
      expect(state.update(.4), 0);
      expect(state.apply(PlayerStatus.poison), false);
      state.poisonPotency = 1.4;
      final restored = PlayerAfflictions.fromSave(state.toSave());
      expect(restored.poisonPotency, 1.4);
      expect(restored.update(.51), 1);
      expect(restored.update(5), 3);
      expect(restored.remaining(PlayerStatus.poison), 0);
      expect(restored.update(5), 0);
      expect(PlayerAfflictions.fromSave(null).active, isEmpty);
      for (final raw in [
        {'freeze': double.nan},
        {'poison': 10},
        {'root': -1},
        {'poisonTick': 0},
      ]) {
        expect(() => PlayerAfflictions.fromSave(raw), throwsFormatException);
      }
    },
  );

  test(
    'poison snapshots a bounded source strength and never upgrades on re-hit',
    () {
      final state = PlayerAfflictions();
      expect(state.apply(PlayerStatus.poison, potency: 1.2), true);
      expect(state.apply(PlayerStatus.poison, potency: 8), false);
      expect(state.poisonPotency, 1.2);
      state.update(4);
      state.apply(PlayerStatus.poison, potency: 8);
      expect(state.poisonPotency, 1.5);
      final restored = PlayerAfflictions.fromSave(state.toSave());
      expect(restored.poisonPotency, 1.5);
    },
  );

  test(
    'accepted net projectile hits once; dodge, terrain and wards reject CC',
    () {
      final s = field();
      final hp = s.progress.hp;
      ShadowBolt net(Offset at, double angle) => ShadowBolt(
        s,
        at,
        angle,
        technological: true,
        status: PlayerStatus.root,
      );
      s.hero.invulnerable = .3;
      net(s.hero.body.center + const Offset(25, 0), math.pi).update(.05);
      expect(s.afflictions.movementBlocked, false);
      expect(s.progress.hp, hp);
      s.hero.invulnerable = 0;
      final hit = net(s.hero.body.center + const Offset(25, 0), math.pi);
      hit.update(.05);
      expect(s.afflictions.remaining(PlayerStatus.root), 1.4);
      final after = s.progress.hp;
      hit.update(.05);
      expect(s.progress.hp, after);
      s.afflictions.clear();
      final wall = net(const Offset(1, 100), math.pi);
      wall.update(.05);
      expect(wall.resolved, true);
      expect(s.afflictions.active, isEmpty);
      s.hero.position.setValues(s.world.spawn.dx, s.world.spawn.dy);
      s.hero.invulnerable = 0;
      net(s.hero.body.center + const Offset(25, 0), math.pi).update(.05);
      expect(s.afflictions.active, isEmpty);
    },
  );

  test(
    'root stops movement and movement skills but attacks and potions work',
    () {
      final s = field();
      s.progress.gainXp(8000);
      s.progress.energy = 100;
      s.progress.hp = 60;
      s.syncLife();
      s.hurtHero(1, status: PlayerStatus.root);
      final start = s.hero.body;
      s.hero.onJoystickChangeDirectional(
        JoystickDirectionalEvent(
          directional: JoystickMoveDirectional.MOVE_RIGHT,
          radAngle: 0,
          intensity: 1,
        ),
      );
      s.hero.update(.05);
      expect(s.hero.body, start);
      final strikes = s.hero.strikes;
      s.hero.slash();
      expect(s.hero.strikes, strikes + 1);
      final potions = s.progress.healingPotions;
      s.potion();
      expect(s.progress.healingPotions, potions - 1);
      s.progress.ranks['leap'] = 1;
      s.progress.selectSkill('leap');
      final energy = s.progress.energy;
      s.hero.beginAim(0);
      s.hero.skill();
      s.hero.dodge();
      expect(s.hero.aim, isNull);
      expect(s.hero.chargeTime, 0);
      expect(s.hero.dashing, 0);
      expect(s.hero.cooldowns['leap'], isNull);
      expect(s.progress.energy, energy);
      s.tick(1.41);
      s.hero.update(.05);
      expect(s.hero.body.left, greaterThan(start.left));
      expect(s.world.blocked(s.hero.body), false);
    },
  );

  test(
    'freeze interrupts a paid follow-up and aiming without pausing enemies or spending rejected skills',
    () {
      final s = field();
      s.progress.gainXp(8000);
      s.progress.level = 100;
      s.progress.ranks.addAll({'bash': 1, 'doubleSwing': 1});
      s.progress.selectSkill('doubleSwing');
      s.progress.energy = 100;
      s.hero.skill();
      expect(s.hero.barbarianCombat.busy, true);
      final cooldown = s.hero.cooldowns['doubleSwing'];
      s.hurtHero(1, status: PlayerStatus.freeze);
      final energy = s.progress.energy;
      expect(s.active, true);
      expect(s.hero.barbarianCombat.busy, false);
      expect(s.hero.queuedCast, isNull);
      s.hero.skill();
      s.hero.beginAim(0);
      s.hero.slash();
      s.hero.dodge();
      expect(s.progress.energy, energy);
      expect(s.hero.cooldowns['doubleSwing'], cooldown);
      expect(s.hero.aim, isNull);
      final enemy = s.spawnEnemy('goblin', const Offset(6200, 4200))!;
      final before = enemy.position.clone();
      enemy.update(.05);
      expect((enemy.position - before).length, greaterThan(0));
      s.pause();
      s.tick(.5);
      expect(s.afflictions.remaining(PlayerStatus.freeze), .75);
      s.resume();
      s.tick(.76);
      expect(s.afflictions.frozen, false);
    },
  );

  test(
    'mounted root preserves attacks but rejected movement and frozen skills keep the mount',
    () {
      final s = field();
      s.progress.energy = 100;
      final mount = withOwnedMounts(s).mounts.first
        ..at = s.hero.body.center + const Offset(40, 0);
      expect(s.boardNearbyMount(), true);
      s.hurtHero(1, status: PlayerStatus.root);
      final body = s.hero.body;
      s.hero.onJoystickChangeDirectional(
        JoystickDirectionalEvent(
          directional: JoystickMoveDirectional.MOVE_RIGHT,
          radAngle: 0,
          intensity: 1,
        ),
      );
      s.hero.update(.05);
      expect(s.hero.body, body);
      s.progress.gainXp(8000);
      s.progress.ranks['leap'] = 1;
      s.progress.selectSkill('leap');
      final energy = s.progress.energy;
      s.hero.skill();
      s.hero.dodge();
      s.hero.beginAim(0);
      expect(s.riding, mount);
      expect(s.progress.energy, energy);
      s.progress.ranks['shout'] = 1;
      expect(s.progress.selectSkill('shout'), true);
      s.hero.skill();
      expect(s.riding, isNull);
      expect(s.progress.activeArmorMultiplier, greaterThan(1));
      expect(s.afflictions.movementBlocked, true);
      expect(s.world.blocked(s.hero.body), false);
      final other = field();
      withOwnedMounts(other).mounts.first.at =
          other.hero.body.center + const Offset(40, 0);
      expect(other.boardNearbyMount(), true);
      other.progress.energy = 100;
      other.hurtHero(1, status: PlayerStatus.freeze);
      final heldMount = other.riding, heldEnergy = other.progress.energy;
      other.hero.skill();
      other.hero.beginAim(0);
      other.hero.dodge();
      other.hero.slash();
      expect(other.riding, heldMount);
      expect(other.progress.energy, heldEnergy);
    },
  );

  test(
    'real spider net and wraith sweep are warned, avoidable and apply themed statuses',
    () {
      final s = field();
      final spider = s.spawnEnemy('clockwork-spider', const Offset(6200, 4200))!
        ..attackClock = 0;
      spider.update(.05);
      expect(spider.windup, .9);
      for (var i = 0; i < 19; i++) {
        spider.update(.05);
      }
      final bolt = (s.game! as TestGame).added.whereType<ShadowBolt>().single;
      expect(bolt.status, PlayerStatus.root);
      s.hero.position.y += 100;
      for (var i = 0; i < 50; i++) {
        bolt.update(.05);
      }
      expect(s.afflictions.movementBlocked, false);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      final wraith = s.spawnEnemy('wraith', const Offset(6070, 4200))!
        ..attackClock = 0;
      wraith.update(.05);
      expect(wraith.windup, .75);
      for (var i = 0; i < 16; i++) {
        wraith.update(.05);
      }
      expect(s.afflictions.frozen, true);
      expect(s.active, true);
    },
  );

  test(
    'poison pauses, survives checkpoint and resolves death before healing',
    () {
      final s = field();
      s.hurtHero(1, status: PlayerStatus.poison);
      s.tick(.4);
      final cp = GameCheckpoint.capture(s)!;
      final restored = GameCheckpoint.decode(cp.encode())!.restore(GameArt())
        ..start(TestGame());
      addTearDown(restored.dispose);
      expect(restored.afflictions.toSave(), s.afflictions.toSave());
      final hp = restored.progress.hp;
      restored.pause();
      restored.tick(2);
      expect(restored.progress.hp, hp);
      restored.resume();
      restored.tick(.51);
      expect(restored.progress.hp, lessThan(hp));
      final old = jsonDecode(cp.encode()) as Map<String, dynamic>
        ..remove('afflictions');
      expect(
        GameCheckpoint.decode(jsonEncode(old))!.data['afflictions']['poison'],
        0,
      );
      restored.progress.hp = .1;
      restored.syncLife();
      restored.tick(.9);
      expect(restored.defeated, true);
      expect(restored.progress.hp, 0);
      restored.tick(3);
      restored.potion();
      expect(restored.progress.hp, 0);
    },
  );

  test(
    'ward intentionally cleanses; warp snapshots retain statuses until arrival simulation',
    () {
      final s = field();
      final site = s.world.sites.first;
      s.travelJournal.discover(s.world.stage, site.id);
      s.hero.position.setValues(site.at.dx - 14, site.at.dy + 65);
      s.afflictions.apply(PlayerStatus.poison);
      s.afflictions.apply(PlayerStatus.blind);
      final cp = GameCheckpoint.warp(s, WorldStage.forest, site.id)!;
      expect(cp.data['afflictions'], s.afflictions.toSave());
      final restored = cp.restore(GameArt())..start(TestGame());
      addTearDown(restored.dispose);
      expect(restored.afflictions.remaining(PlayerStatus.blind), 2.8);
      restored.hero.position.setValues(
        restored.world.spawn.dx,
        restored.world.spawn.dy,
      );
      restored.tick(.05);
      expect(restored.afflictions.active, isEmpty);
    },
  );

  test(
    'near-tick poisoned checkpoint proves an ordinary restore can die immediately',
    () {
      final s = field();
      s.afflictions.apply(PlayerStatus.poison);
      s.afflictions.poisonTick = .05;
      s.progress.hp = .1;
      s.syncLife();
      final cp = GameCheckpoint.capture(s)!;
      final restored = cp.restore(GameArt())..start(TestGame());
      addTearDown(restored.dispose);
      expect(restored.hero.invulnerable, .75);
      restored.tick(.05);
      expect(restored.defeated, true);
      final revived = cp.forRevival().restore(GameArt())..start(TestGame());
      addTearDown(revived.dispose);
      revived.tick(.05);
      expect(revived.defeated, false);
      expect(revived.progress.hp, revived.progress.maxHp);
      expect(revived.afflictions.active, isEmpty);
      expect(
        cp.data['afflictions']['poison'],
        3.6,
        reason: 'revival must not modify the saved normal-resume checkpoint',
      );
    },
  );
}

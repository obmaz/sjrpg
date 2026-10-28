import 'dart:convert';
import 'package:bonfire/bonfire.dart' show ActionEvent, JoystickActionEvent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/mount_progress.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session({HeroClass heroClass = HeroClass.warrior}) {
    final s = Adventure(GameArt(), heroClass: heroClass)..start(TestGame());
    s.mobs.clear();
    s.progress.gold = 10000;
    addTearDown(s.dispose);
    return s;
  }

  void stable(Adventure s) {
    s.hero.position.setValues(
      s.mountMerchantAt.dx - 14,
      s.mountMerchantAt.dy - 12,
    );
    expect(s.nearMountMerchant, true);
  }

  TravelMount ride(Adventure s, String id) {
    stable(s);
    expect(s.buyMount(id), true);
    inCombatField(s);
    final m = s.mounts.firstWhere((m) => m.def.id == id);
    m.at = s.hero.body.center + const Offset(50, 0);
    expect(s.boardNearbyMount(), true);
    return m;
  }

  test(
    'new adventures contain no free vehicles and trade is range checked and atomic',
    () {
      final s = session();
      expect(s.mounts, isEmpty);
      expect(s.progress.mountProgress.ownedIds, isEmpty);
      final gold = s.progress.gold;
      inCombatField(s);
      expect(s.buyMount('horse'), false);
      expect(s.progress.gold, gold);
      stable(s);
      s.pause();
      expect(s.buyMount('invalid'), false);
      expect(s.buyMount('horse'), true);
      expect(s.progress.gold, gold - 90);
      expect(s.riding, isNull);
      expect(s.buyMount('horse'), false);
      expect(s.progress.gold, gold - 90);
      expect(s.progress.mountProgress.owns('horse'), true);
      expect(s.mounts.single.def.id, 'horse');
      expect(
        s.world.blocked(
          Rect.fromCenter(center: s.mounts.single.at, width: 42, height: 36),
        ),
        false,
      );
    },
  );
  test(
    'ownership and horse condition survive saves and stages without granting old free mounts',
    () {
      final s = session();
      stable(s);
      s.buyMount('horse');
      final state = s.progress.mountProgress.stateFor('horse');
      state.hits = 2;
      state.durability = 54;
      final saved = Progress.fromSave(s.progress.toSave())!;
      expect(saved.mountProgress.owns('horse'), true);
      expect(saved.mountProgress.stateFor('horse').hits, 2);
      final next = Adventure(
        GameArt(),
        stage: WorldStage.sands,
        restoredProgress: saved,
      );
      addTearDown(next.dispose);
      expect(next.mounts.single.def.id, 'horse');
      expect(next.mounts.single.hits, 2);
      expect(next.mounts.single.durability, 54);
      final old = s.progress.toSave()..remove('mountProgress');
      expect(Progress.fromSave(old)!.mountProgress.ownedIds, isEmpty);
      final cp = GameCheckpoint.capture(s)!;
      expect(GameCheckpoint.decode(cp.encode()), isNotNull);
    },
  );
  test(
    'three accepted horse hits force a fall; poison does not count and field repair cannot reset it',
    () {
      final s = session();
      final horse = ride(s, 'horse');
      s.progress.maxHp = 1000;
      s.progress.hp = 1000;
      s.syncLife();
      s.hurtHero(1);
      expect(horse.hits, 1);
      s.hurtHero(1);
      expect(horse.hits, 1, reason: 'ignored invulnerable hit is not a hit');
      s.hurtHero(1, periodic: true);
      expect(horse.hits, 1);
      expect(
        s.repairMount(),
        false,
        reason: 'field repair cannot reset the horse hit budget',
      );
      for (var i = 0; i < 2; i++) {
        s.hero.invulnerable = 0;
        s.hurtHero(1);
      }
      expect(horse.hits, 3);
      expect(horse.fallen, true);
      expect(s.riding, isNull);
      expect(s.hero.body.size, Guardian.onFootSize);
      expect(s.repairMount(), false);
      expect(s.boardNearbyMount(), false);
      final saved = MountProgress.fromSave(s.progress.mountProgress.toSave());
      expect(saved.stateFor('horse').fallen, true);
      stable(s);
      expect(s.repairOwnedMount('horse'), true);
      expect(horse.hits, 0);
      expect(horse.fallen, false);
      expect(horse.durability, 100);
    },
  );
  test(
    'bicycle remains mounted under repeated hits but must dismount for an attack',
    () {
      final s = session();
      final bike = ride(s, 'bicycle');
      s.progress.maxHp = 1000;
      s.progress.hp = 1000;
      s.syncLife();
      for (var i = 0; i < 6; i++) {
        s.hero.invulnerable = 0;
        s.hurtHero(1);
      }
      expect(s.riding, same(bike));
      expect(bike.fallen, false);
      expect(bike.hits, 0);
      s.hero.slash();
      expect(s.riding, isNull);
    },
  );
  for (final heroClass in HeroClass.values) {
    test('$heroClass can use basic attacks on a moving horse', () {
      final s = session(heroClass: heroClass);
      final horse = ride(s, 'horse');
      s.hero.moveRight();
      s.hero.update(.05);
      final before = s.hero.body.center;
      s.hero.slash();
      expect(s.riding, same(horse));
      expect(s.hero.strikes, 1);
      s.hero.update(.05);
      expect(s.hero.body.center.dx, greaterThan(before.dx));
      expect(s.hero.speed, horse.speed);
    });
  }
  test(
    'all mounts offer a distinct skill, share real cooldown and pause it',
    () {
      final s = session();
      ride(s, 'bicycle');
      s.afflictions.apply(PlayerStatus.root);
      s.afflictions.apply(PlayerStatus.poison);
      expect(s.useMountSkill(), true);
      expect(s.afflictions.movementBlocked, false);
      expect(s.afflictions.remaining(PlayerStatus.poison), greaterThan(0));
      expect(s.mountBoostTime, 2);
      expect(s.mountSkillClock, 10);
      expect(s.useMountSkill(), false);
      s.pause();
      s.tick(1);
      expect(s.mountSkillClock, 10);
      s.resume();
      s.tick(.5);
      expect(s.mountSkillClock, 9.5);
      final names = travelMountDefs.take(4).map((m) => m.skillName).toSet();
      expect(names.length, 4);
    },
  );
  test(
    'motorcycle requires ammo, has bounded paid upgrades and a single-target shot',
    () {
      final s = session();
      stable(s);
      expect(s.buyMount('motor'), true);
      for (var i = 0; i < 3; i++) {
        expect(s.upgradeMotor(), true);
      }
      expect(s.upgradeMotor(), false);
      expect(s.progress.mountProgress.motorLevel, 3);
      inCombatField(s);
      final motor = s.mounts.single;
      motor.at = s.hero.body.center + const Offset(50, 0);
      expect(s.boardNearbyMount(), true);
      final game = TestGame();
      s.game = game;
      expect(s.useMountSkill(), true);
      expect(s.progress.mountProgress.motorAmmo, 11);
      expect(s.motorRecoilTime, .5);
      final bolt = game.added.whereType<ArcaneBolt>().single;
      expect(bolt.targetLimit, 1);
      expect(bolt.damage, 20.25);
      expect(s.useMountSkill(), false);
      s.mountSkillClock = 0;
      s.progress.mountProgress.motorAmmo = 0;
      expect(s.useMountSkill(), false);
      expect(s.progress.mountProgress.motorAmmo, 0);
      expect(s.dismount(), true);
      stable(s);
      expect(s.buyMotorAmmo(), true);
      expect(s.progress.mountProgress.motorAmmo, 12);
      expect(s.buyMotorAmmo(), false);
    },
  );
  test('boat purchase creates one accessible berth in large water', () {
    final s = session();
    stable(s);
    expect(s.buyMount('boat'), true);
    final boat = s.mounts.single;
    expect(boat.def.waterOnly, true);
    expect(s.world.largeWater(boat.at), true);
    expect(s.progress.mountProgress.owns('boat-west'), true);
  });
  test(
    'keyboard motor fire uses single down edges and never drops the rider on hold',
    () {
      final s = session();
      final motor = ride(s, 'motor');
      s.waveTime = 10000;
      s.hero.onJoystickAction(
        JoystickActionEvent(
          id: LogicalKeyboardKey.space,
          event: ActionEvent.DOWN,
        ),
      );
      expect(s.progress.mountProgress.motorAmmo, 11);
      for (var i = 0; i < 70; i++) {
        s.hero.update(.05);
        s.tick(.05);
      }
      expect(s.riding, same(motor));
      expect(s.progress.mountProgress.motorAmmo, 11);
      s.hero.onJoystickAction(
        JoystickActionEvent(
          id: LogicalKeyboardKey.space,
          event: ActionEvent.DOWN,
        ),
      );
      expect(
        s.progress.mountProgress.motorAmmo,
        11,
        reason: 'OS repeat is not another trigger edge',
      );
      s.hero.onJoystickAction(
        JoystickActionEvent(
          id: LogicalKeyboardKey.space,
          event: ActionEvent.UP,
        ),
      );
      s.hero.onJoystickAction(
        JoystickActionEvent(
          id: LogicalKeyboardKey.space,
          event: ActionEvent.DOWN,
        ),
      );
      expect(s.progress.mountProgress.motorAmmo, 10);
      expect(s.riding, same(motor));
    },
  );
  test(
    'a motor cannot spend ammunition firing from a ward without a breakable prop',
    () {
      final s = session();
      stable(s);
      s.buyMount('motor');
      final motor = s.mounts.single;
      final at = s.world.spawnNear(
        s.world.sanctuary.center,
        motor.def.bodySize,
      )!;
      motor.at =
          at +
          Offset(motor.def.bodySize.width / 2, motor.def.bodySize.height / 2);
      s.riding = motor;
      s.hero.resizeBody(motor.def.bodySize, motor.at);
      s.openedChests.addAll(
        List.generate(s.stageChestLocations.length, (i) => i),
      );
      expect(s.sheltered, true);
      expect(s.useMountSkill(), false);
      expect(s.progress.mountProgress.motorAmmo, 12);
    },
  );
  test('forged ownership and condition data is rejected', () {
    final p = MountProgress();
    p.ownedIds.add('bicycle');
    final raw = p.toSave();
    (raw['conditions']['bicycle'] as Map)['fallen'] = true;
    expect(
      () => MountProgress.fromSave(jsonDecode(jsonEncode(raw))),
      throwsFormatException,
    );
    final data = Progress().toSave()
      ..['mountProgress'] = {
        'version': 1,
        'owned': [],
        'motorLevel': 3,
        'motorAmmo': 0,
        'conditions': {},
      };
    expect(Progress.fromSave(data), isNull);
  });
}

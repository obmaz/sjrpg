import 'dart:convert';

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/boss_attacks.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field({
    HeroClass heroClass = HeroClass.warrior,
    WorldStage stage = WorldStage.forest,
  }) {
    final s = inCombatField(
      Adventure(GameArt(), heroClass: heroClass, stage: stage),
    )..start(TestGame());
    s.mobs.clear();
    s.waveTime = 10000;
    s.hero.invulnerable = 0;
    addTearDown(s.dispose);
    return s;
  }

  HuntEnemy summon(Adventure s, BossPower power, {double distance = 200}) {
    final base = s.hero.position.toOffset();
    s.hero.position.x += distance;
    final boss = s.spawnEnemy('golem', base, boss: true)!
      ..bossSequence = power.index
      ..slamClock = 0
      ..attackClock = 100;
    boss.update(.05);
    expect(boss.bossAttack, isNotNull);
    return boss;
  }

  void resolve(HuntEnemy boss) {
    for (var i = 0; i < 40 && boss.bossAttack != null; i++) {
      boss.update(.05);
    }
    expect(boss.bossAttack, isNull);
  }

  test(
    'a ranged hero at 540px is threatened without inflating boss health',
    () {
      final s = field(heroClass: HeroClass.mage);
      final boss = summon(s, BossPower.impact, distance: 540);
      expect(boss.bossAttack!.power, BossPower.root);
      expect(
        boss.bossAttack!.zones.any((z) => z.contains(s.hero.body.center)),
        true,
      );
      final hp = s.progress.hp, bossLife = boss.life.max;
      resolve(boss);
      expect(s.progress.hp, lessThan(hp));
      expect(s.afflictions.remaining(PlayerStatus.root), 1.4);
      expect(boss.life.max, bossLife);
    },
  );

  for (final stage in WorldStage.values) {
    test(
      '$stage offers all five readable controls with time and room to evade',
      () {
        const origin = Offset(6000, 4200), target = Offset(6200, 4200);
        for (final power in BossPower.values.skip(1)) {
          final attack = BossAttack.forStage(
            stage,
            origin,
            target,
            sequence: power.index,
          );
          expect(attack.power, power);
          expect(attack.warningTime, greaterThanOrEqualTo(1));
          expect(attack.recovery, greaterThan(3.5));
          expect(attack.zones.any((z) => z.contains(target)), true);
          expect(
            attack.zones.any((z) => z.contains(target + const Offset(0, 220))),
            false,
          );
          final enraged = BossAttack.forStage(
            stage,
            origin,
            target,
            sequence: power.index,
            enraged: true,
          );
          expect(enraged.power, power);
          expect(enraged.warningTime, attack.warningTime);
          expect(
            enraged.recovery,
            greaterThan(PlayerStatus.moveSlow.duration + .9),
          );
        }
      },
    );
  }

  for (final heroClass in HeroClass.values) {
    for (final power in BossPower.values.skip(1)) {
      test(
        '$heroClass suffers accepted $power once; dodge or sanctuary rejects it',
        () {
          final s = field(heroClass: heroClass);
          s.hero.armorTime = 8;
          s.hero.frenzyTime = 4;
          final ranks = Map<String, int>.from(s.progress.ranks),
              inventory = s.progress.inventory.map((g) => g.serial).toList();
          final gold = s.progress.gold;
          final boss = summon(s, power);
          final hp = s.progress.hp;
          resolve(boss);
          expect(s.progress.hp, lessThan(hp));
          if (power == BossPower.dispel) {
            expect(s.hero.armorTime, 0);
            expect(s.hero.frenzyTime, 0);
            expect(s.progress.ranks, ranks);
            expect(s.progress.inventory.map((g) => g.serial), inventory);
            expect(s.progress.gold, gold);
          } else {
            expect(
              s.afflictions.remaining(power.status!),
              power.status!.duration,
            );
          }
          final after = s.progress.hp;
          boss.update(.05);
          expect(s.progress.hp, after);
          final dodging = field(heroClass: heroClass);
          dodging.hero.armorTime = 8;
          dodging.hero.frenzyTime = 4;
          final avoided = summon(dodging, power);
          while (avoided.windup > .051) {
            avoided.update(.05);
          }
          dodging.hero.dodge();
          final protectedHp = dodging.progress.hp;
          resolve(avoided);
          expect(dodging.progress.hp, protectedHp);
          expect(dodging.afflictions.active, isEmpty);
          expect(dodging.hero.armorTime, 8);
          expect(dodging.hero.frenzyTime, 4);
          final sheltered = field(heroClass: heroClass);
          sheltered.hero.armorTime = 8;
          sheltered.hero.frenzyTime = 4;
          final crossing = summon(sheltered, power);
          sheltered.hero.position.setValues(
            sheltered.world.spawn.dx,
            sheltered.world.spawn.dy,
          );
          resolve(crossing);
          expect(sheltered.progress.hp, sheltered.progress.maxHp);
          expect(sheltered.afflictions.active, isEmpty);
          expect(sheltered.hero.armorTime, 8);
          expect(sheltered.hero.frenzyTime, 4);
        },
      );
    }
  }

  test(
    'slow timers do not refresh or chain-lock and older saves default to clear',
    () {
      final statuses = PlayerAfflictions.fromSave({
        'root': 0,
        'freeze': 0,
        'poison': 0,
        'blind': 0,
      });
      expect(statuses.attackTempo, 1);
      expect(statuses.movementScale, 1);
      expect(statuses.apply(PlayerStatus.attackSlow), true);
      expect(statuses.apply(PlayerStatus.moveSlow), true);
      statuses.update(1);
      expect(statuses.apply(PlayerStatus.attackSlow), false);
      expect(statuses.remaining(PlayerStatus.attackSlow), 1.6);
      final restored = PlayerAfflictions.fromSave(statuses.toSave());
      expect(restored.attackTempo, .72);
      expect(restored.movementScale, .7);
      restored.update(1.61);
      expect(restored.attackTempo, 1);
      expect(restored.movementScale, 1);
      expect(restored.apply(PlayerStatus.attackSlow), false);
      expect(restored.apply(PlayerStatus.moveSlow), false);
      restored.update(.91);
      expect(restored.apply(PlayerStatus.attackSlow), true);
      statuses.clear();
      expect(statuses.active, isEmpty);
      expect(statuses.attackGrace, 0);
    },
  );

  test(
    'walking is slowed but a dodge retains its full counterplay distance',
    () {
      final normal = field(), slowed = field();
      slowed.afflictions.apply(PlayerStatus.moveSlow);
      for (final s in [normal, slowed]) {
        s.hero.onJoystickChangeDirectional(
          JoystickDirectionalEvent(
            directional: JoystickMoveDirectional.MOVE_RIGHT,
            radAngle: 0,
            intensity: 1,
          ),
        );
      }
      // Bonfire sets the joystick velocity after applying the previous one.
      normal.hero.update(.05);
      slowed.hero.update(.05);
      final normalAt = normal.hero.position.clone(),
          slowedAt = slowed.hero.position.clone();
      normal.hero.update(.05);
      slowed.hero.update(.05);
      expect(
        (slowed.hero.position - slowedAt).length /
            (normal.hero.position - normalAt).length,
        closeTo(.7, .001),
      );
      final n = field(), q = field();
      q.afflictions.apply(PlayerStatus.moveSlow);
      final before = n.hero.position.clone(), after = q.hero.position.clone();
      n.hero.dodge();
      q.hero.dodge();
      n.hero.update(.05);
      q.hero.update(.05);
      expect(
        (q.hero.position - after).length,
        closeTo((n.hero.position - before).length, .001),
      );
    },
  );

  test(
    'boss sequence, wounds and both slows persist; death retry alone cleanses them',
    () {
      final s = field();
      final boss = summon(s, BossPower.moveSlow);
      resolve(boss);
      s.afflictions.apply(PlayerStatus.attackSlow);
      boss.life.update(boss.life.max - 55);
      s.tick(.4);
      final cp = GameCheckpoint.capture(s)!;
      final restored = GameCheckpoint.decode(cp.encode())!.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.afflictions.toSave(), s.afflictions.toSave());
      expect(
        restored.mobs.singleWhere((m) => m.boss).bossSequence,
        boss.bossSequence,
      );
      expect(
        restored.mobs.singleWhere((m) => m.boss).life.value,
        boss.life.value,
      );
      final revived = cp.forRevival().restore(GameArt());
      addTearDown(revived.dispose);
      expect(revived.afflictions.active, isEmpty);
      expect(cp.data['afflictions']['moveSlow'], greaterThan(0));
      for (final value in [-1, 6, '1', .5]) {
        final raw = jsonDecode(cp.encode()) as Map<String, dynamic>;
        raw['boss']['sequence'] = value;
        expect(GameCheckpoint.decode(jsonEncode(raw)), isNull);
      }
      final raw = jsonDecode(cp.encode()) as Map<String, dynamic>;
      (raw['boss'] as Map).remove('sequence');
      expect(
        GameCheckpoint.decode(
          jsonEncode(raw),
        )!.restore(GameArt()).mobs.singleWhere((m) => m.boss).bossSequence,
        0,
      );
    },
  );
  test(
    'twenty seconds of actual held basic attacks and heavy-hit stuns still allow boss specials',
    () {
      final s = field();
      final boss = summon(s, BossPower.root, distance: 90);
      s.holdAttack('held-heavy-schedule', true);
      var heavyHits = 0;
      for (var i = 0; i < 400 && s.active; i++) {
        final before = boss.life.value;
        s.hero.update(.05);
        if (boss.life.value < before) {
          heavyHits++;
          boss.applyStun(.15);
        }
        boss.update(.05);
        s.tick(.05);
      }
      final specials = (s.game! as TestGame).added
          .whereType<BossAttackVisual>()
          .where((v) => v.impact && v.pattern.power != BossPower.impact)
          .toList();
      expect(heavyHits, greaterThan(15));
      expect(specials.length, greaterThanOrEqualTo(2));
      expect(
        specials.any(
          (v) =>
              v.pattern.power == BossPower.dispel ||
              v.pattern.power == BossPower.freeze,
        ),
        true,
      );
      expect(s.progress.hp, lessThan(s.progress.maxHp));
      expect(boss.isDead, false);
    },
  );

  test(
    'boss control resistance survives saves and the ordinary enemy keeps its full stun',
    () {
      final s = field();
      final boss = summon(s, BossPower.root);
      expect(boss.applyStun(.5), true);
      expect(boss.stun, closeTo(.175, .0001));
      expect(boss.applyStun(2), false);
      final cp = GameCheckpoint.capture(s)!;
      final back = cp.restore(GameArt())..start(TestGame());
      addTearDown(back.dispose);
      final saved = back.mobs.singleWhere((m) => m.boss);
      expect(saved.bossControlGuard, boss.bossControlGuard);
      expect(saved.applyStun(.5), false);
      final goblin = s.spawnEnemy(
        'goblin',
        s.hero.body.center + const Offset(100, 50),
      )!;
      expect(goblin.applyStun(.5), true);
      expect(goblin.stun, .5);
    },
  );
  test(
    'a solid wall rejects every boss hex and dispel before changing hero state',
    () {
      final s = field();
      final tree = s.world.props.firstWhere(
        (p) =>
            p.kind == 'tree' &&
            !s.world.blocked(
              Rect.fromLTWH(p.body.left - 80, p.body.center.dy - 20, 48, 40),
            ) &&
            !s.world.blocked(
              Rect.fromLTWH(p.body.right + 30, p.body.center.dy - 11, 24, 22),
            ),
      );
      s.hero.position.setValues(tree.body.right + 30, tree.body.center.dy - 11);
      s.hero.armorTime = 8;
      s.hero.frenzyTime = 4;
      final boss = s.spawnEnemy(
        'golem',
        Offset(tree.body.left - 80, tree.body.center.dy - 20),
        boss: true,
      )!;
      for (final power in BossPower.values.skip(1)) {
        boss.bossAttack = BossAttack.forStage(
          WorldStage.forest,
          boss.body.center,
          s.hero.body.center,
          sequence: power.index,
        );
        boss.windup = .05;
        boss.attackClock = 100;
        final hp = s.progress.hp;
        boss.update(.05);
        expect(s.progress.hp, hp);
        expect(s.afflictions.active, isEmpty);
        expect(s.hero.armorTime, 8);
        expect(s.hero.frenzyTime, 4);
      }
    },
  );
}

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/dungeon.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/sorceress_rules.dart';
import 'package:guardian_new/world_model.dart';

import 'support/sorceress_fixture.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure outside(
    WorldStage stage, {
    HeroClass heroClass = HeroClass.warrior,
  }) {
    final s = Adventure(GameArt(), stage: stage, heroClass: heroClass)
      ..start(TestGame());
    addTearDown(s.dispose);
    final at = s.world.caveEntrance - const Offset(14, -35);
    s.hero.position.setValues(at.dx, at.dy);
    expect(s.world.blocked(s.hero.body), false);
    expect(s.nearCave, true);
    return s;
  }

  Adventure enter(Adventure s) {
    final checkpoint = GameCheckpoint.enterDungeon(s);
    expect(checkpoint, isNotNull);
    final instance = checkpoint!.restore(GameArt())..start(TestGame());
    addTearDown(instance.dispose);
    return instance;
  }

  test('owned mounts cannot spawn, summon or board inside a cave', () {
    final field = withOwnedMounts(outside(WorldStage.forest));
    final instance = enter(field);
    expect(instance.mounts, isEmpty);
    instance.spawnOwnedMounts();
    expect(instance.mounts, isEmpty);
    for (final id in ['horse', 'bicycle', 'motor', 'boat']) {
      expect(instance.summonMount(id), false);
    }
    // Even an accidentally injected nearby mount cannot bypass the model rule.
    final horse = field.mounts.firstWhere((m) => m.def.artKey == 'horse');
    horse.at = instance.hero.body.center;
    instance.mounts.add(horse);
    expect(instance.nearbyMount, isNull);
    expect(instance.boardNearbyMount(), false);
    expect(instance.riding, isNull);
    expect(instance.nearMountMerchant, false);
  });

  for (final stage in WorldStage.values) {
    test(
      '${stage.name} has an accessible, isolated cave with fixed level enemies',
      () {
        final s = outside(stage);
        s.progress.level = 23;
        final dungeon = enter(s);
        expect(dungeon.dungeon!.enemyLevel, 25);
        expect(dungeon.living, 15);
        expect(dungeon.mobs.every((m) => m.power.level == 25), true);
        expect(dungeon.world.sanctuary.protects(dungeon.hero.body), false);
        expect(dungeon.world.props, isEmpty);
        expect(dungeon.world.chests, isEmpty);
        expect(dungeon.forestQuests.enabled, false);
        expect(dungeon.forestQuests.npcs, isEmpty);
        expect(
          dungeon.forestQuests.updateThreat(dungeon.mobs.first, .05),
          false,
        );
        dungeon.progress.level = 24;
        dungeon.tick(1.2);
        expect(dungeon.dungeon!.enemyLevel, 25);
        expect(dungeon.encounterAreas, isEmpty);
        dungeon.pause();
        final left = dungeon.dungeon!.remaining;
        dungeon.tick(100);
        expect(dungeon.dungeon!.remaining, left);
      },
    );
  }
  test('both arms of each fork connect; walls reject bodies and rays', () {
    final s = Adventure(GameArt(), dungeon: DungeonRun(WorldStage.forest, 1));
    addTearDown(s.dispose);
    for (final (a, b) in s.dungeon!.layout.edges) {
      expect(
        s.world.clearLine(
          a - const Offset(14, 12),
          b - const Offset(14, 12),
          Guardian.onFootSize,
        ),
        true,
      );
    }
    final a = DungeonLayout.rooms[1], b = DungeonLayout.rooms[2];
    expect(s.world.clearLine(a, b, const Size(3, 3)), false);
    expect(
      s.world.blocked((Offset.lerp(a, b, .5)!) & Guardian.onFootSize),
      true,
    );
    final north = Offset.lerp(a, b, .5)! + const Offset(0, -300);
    expect(
      s.world.blocked((north - const Offset(14, 12)) & Guardian.onFootSize),
      false,
    );
  });
  test('chapter arrival hubs also place an accessible cave mouth', () {
    for (final stage in WorldStage.values) {
      final s = Adventure(GameArt(), stage: stage, hubOrigin: stage.arrival)
        ..start(TestGame());
      addTearDown(s.dispose);
      final at = s.world.caveEntrance + const Offset(-14, 35);
      s.hero.position.setValues(at.dx, at.dy);
      expect(s.world.blocked(s.hero.body), false, reason: stage.name);
      expect(s.nearCave, true, reason: stage.name);
    }
  });
  test(
    'timeout is 300 active real seconds and cannot spawn or award after ending',
    () {
      final s = enter(outside(WorldStage.forest));
      final gold = s.progress.gold;
      s.tick(299 * CombatBalance.gameSpeed);
      expect(s.dungeon!.ended, false);
      s.tick(CombatBalance.gameSpeed + 0.001);
      expect(s.dungeon!.outcome, DungeonOutcome.expired);
      expect(s.active, false);
      s.tick(100);
      expect(s.progress.gold, gold);
      expect(s.living, 15);
    },
  );
  test('clear reward is paid once at the exit after all guards die', () {
    final s = enter(outside(WorldStage.forest));
    s.mobs.clear();
    final goal = s.dungeon!.layout.goal;
    s.hero.position.setValues(goal.dx, goal.dy);
    final gold = s.progress.gold;
    s.tick(.05);
    s.tick(.05);
    expect(s.dungeon!.outcome, DungeonOutcome.cleared);
    expect(s.progress.gold, gold + 100 + s.dungeon!.enemyLevel * 20);
  });
  test(
    'return and reload retain loot and growth, but not overworld quest kills',
    () {
      final original = outside(WorldStage.forest);
      original.progress.level = 100;
      original.progress.skillPoints = 1000;
      trainSkill(original.progress, 'warcry');
      trainSkill(original.progress, original.progress.mobilitySkill.id);
      original.hero.restoreMobility(3, .2);
      original.hero.cooldowns['warcry'] = 4;
      original.hero.armorTime = 2;
      original.hero.cooldowns['howl'] = 4;
      final s = enter(original);
      expect(s.hero.armorTime, 2);
      expect(s.hero.cooldowns['howl'], 4);
      s.hero.armorTime = 1;
      s.hero.cooldowns['warcry'] = 2;
      s.hero.cooldowns['howl'] = 1;
      final item = s.progress.createGear(
        gearById('shortsword'),
        rarity: Rarity.rare,
      );
      expect(s.progress.collect(item), true);
      s.progress.kills += 3;
      s.progress.gold += 55;
      final cp = GameCheckpoint.capture(s)!;
      expect(cp.dungeonRun, isNull);
      expect(cp.data['sprintTime'], 0);
      final returned = GameCheckpoint.decode(cp.encode())!.restore(GameArt());
      addTearDown(returned.dispose);
      expect(returned.dungeon, isNull);
      expect(returned.hero.armorTime, 1);
      expect(returned.hero.cooldowns['howl'], 1);
      expect(
        returned.progress.inventory.any((g) => g.serial == item.serial),
        true,
      );
      expect(returned.progress.gold, original.progress.gold + 55);
      expect(returned.progress.kills, original.progress.kills + 3);
      expect(returned.stageKills, original.stageKills);
      expect(returned.hero.body.topLeft, original.hero.body.topLeft);
      expect(returned.world.blocked(returned.hero.body), false);
      s.progress.hp = 0;
      s.defeated = true;
      final death = GameCheckpoint.capture(s, forDefeat: true)!;
      expect(death.data['revivalPending'], true);
      expect(death.progress.hp, death.progress.maxHp);
      expect(death.data['x'], original.world.spawn.dx);
      expect(death.data['y'], original.world.spawn.dy);
    },
  );
  for (final (stage, cold) in [
    (WorldStage.past, true),
    (WorldStage.tombs, false),
  ]) {
    test(
      '${stage.name} reduces only its matching element, including cold contact',
      () {
        final s = enter(outside(stage, heroClass: HeroClass.mage));
        final enemy = s.mobs.first;
        enemy.life.initial(100000);
        final owner = s.hero.sorceressCombat;
        for (final id in ['iceBolt', 'firebolt', 'chargedBolt']) {
          final spec = SorceressRules.evaluate(
            id,
            rank: 1,
            hardRanks: const {},
          );
          final before = enemy.life.value;
          expect(owner.damage(enemy, 100, spec), true);
          expect(spec.damageType, isNot(SorceressDamageType.none));
          final expected = s.dungeon!.definition.damageMultiplier(
            cold: spec.damageType == SorceressDamageType.cold,
            fire: spec.damageType == SorceressDamageType.fire,
          );
          expect(
            before - enemy.life.value,
            closeTo(100 * expected * (1 - enemy.power.defense), .001),
          );
        }
        final before = enemy.life.value;
        owner.applyColdHit(enemy, 100);
        expect(
          before - enemy.life.value,
          closeTo(100 * (cold ? .5 : 1) * (1 - enemy.power.defense), .001),
        );
        expect(
          s.dungeon!.definition.damageMultiplier(cold: false, fire: false),
          1,
        );
      },
    );
  }
  test('export a real entrance fixture when requested', () {
    final path = Platform.environment['SJRPG_DUNGEON_PROOF'];
    if (path == null) return;
    for (final stage in WorldStage.values) {
      final s = outside(stage);
      if (stage == WorldStage.sands) s.timePath = TimePath.past;
      File(
        stage == WorldStage.forest ? path : '$path.${stage.name}',
      ).writeAsStringSync(jsonEncode(GameCheckpoint.capture(s)!.data));
    }
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/encounters.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/travel_journal.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Adventure start([GameCheckpoint? saved]) {
    final session = saved?.restore(GameArt()) ?? Adventure(GameArt());
    session.start(TestGame());
    addTearDown(session.dispose);
    return session;
  }

  void visit(Adventure session, String id) {
    final site = wellSitesForStage(
      session.world.stage,
      hubOrigin: session.world.spawn,
    ).firstWhere((site) => site.id == id);
    final approach = session.world.wellApproach(site);
    session.hero.position.setValues(approach.dx - 14, approach.dy - 12);
    session.hero.lastClearPosition = Offset(
      session.hero.position.x,
      session.hero.position.y,
    );
    session.travelJournal.discover(session.world.stage, id);
  }

  void train(Progress p, String id, [int rank = 1]) {
    final skill = p.skills.firstWhere((skill) => skill.id == id);
    for (final need in skill.requires.entries) {
      train(p, need.key, need.value);
    }
    while (p.rank(id) < rank) {
      expect(p.learn(skill), true, reason: '$id rank$rank');
    }
  }

  void finishForest(Adventure session) {
    session.cleansedSites.addAll(session.world.sites.map((s) => s.id));
    session.progress.bossDefeated = true;
    session.progress.kills = 120;
  }

  test('only known wells are recorded, including each chapter hub', () {
    final journal = TravelJournal();
    expect(journal.discover(WorldStage.forest, 'unknown'), false);
    expect(journal.discover(WorldStage.forest, 'hub'), true);
    expect(journal.discover(WorldStage.forest, 'hub'), false);
    expect(journal.discover(WorldStage.forest, 'roots'), true);
    expect(journal.wells.map((w) => w.id), ['hub', 'roots']);
    expect(journal.wells.first.site.name, '마을 분수');
  });

  test(
    'legacy saves retain their arrival hub, completed wells and old layout origin',
    () {
      final session = start()..cleansedSites.add('roots');
      final data = GameCheckpoint.capture(session)!.data
        ..remove('travel')
        ..remove('hubOrigin');
      final saved = GameCheckpoint.decode(jsonEncode(data))!;
      expect(saved.data['hubOrigin'], legacyHubOrigins.first);
      final restored = start(saved);
      expect(
        restored.travelJournal.hasDiscovered(WorldStage.forest, 'roots'),
        true,
      );
      expect(
        restored.travelJournal.hasDiscovered(WorldStage.forest, 'hub'),
        true,
      );
      expect(
        restored.travelJournal.hasDiscovered(WorldStage.forest, 'moon'),
        false,
      );
    },
  );

  test('same-chapter well travel preserves resources, cooldowns and rewards', () {
    final session = start();
    session.travelJournal.discover(WorldStage.forest, 'roots');
    visit(session, 'hub');
    session.progress
      ..level = 100
      ..skillPoints = 1000;
    train(session.progress, 'warcry');
    train(session.progress, 'frenzy');
    final shout = session.progress.skills.firstWhere(
      (skill) => skill.id == 'shout',
    );
    expect(session.progress.selectSkill(shout.id), true);
    inCombatField(session);
    session.hero.skill();
    visit(session, 'hub');
    expect(session.progress.activeArmorMultiplier, greaterThan(1));
    final shoutCooldown = session.progress.skillCooldown(shout);
    expect(session.hero.cooldowns[shout.id], shoutCooldown);
    session.progress.hp = 55;
    session.progress.energy = 12;
    session.hero.cooldowns['warcry'] = 1.25;
    final frenzyCooldown =
        session.progress.skillCooldown(
          session.progress.skills.firstWhere((skill) => skill.id == 'frenzy'),
        ) *
        .5;
    session.hero.cooldowns['frenzy'] = frenzyCooldown;
    session.hero.attackClock = .25;
    session.hero.dodgeClock = .8;
    session.hero.dashing = .1;
    session.pause();
    session.openedChests.add(0);
    final before = GameCheckpoint.capture(session)!.encode();
    final saved = GameCheckpoint.warp(session, WorldStage.forest, 'roots')!;
    expect(
      GameCheckpoint.capture(session)!.encode(),
      before,
      reason: 'building a travel checkpoint does not mutate the active game',
    );
    final restored = start(saved);
    expect(restored.progress.hp, 55);
    expect(restored.progress.energy, 12);
    expect(restored.hero.cooldowns['warcry'], 1.25);
    expect(restored.hero.attackClock, .25);
    expect(restored.hero.dodgeClock, .8);
    expect(restored.hero.dashing, 0);
    expect(session.paused, true);
    expect(restored.hero.cooldowns['frenzy'], frenzyCooldown);
    expect(restored.hero.cooldowns[shout.id], shoutCooldown);
    expect(
      restored.progress.activeArmorMultiplier,
      1,
      reason:
          'transient Barbarian shouts are omitted while their cooldowns persist',
    );
    expect(restored.hero.armorTime, 0);
    expect(restored.hero.frenzyTime, 0);
    expect(restored.openedChests, {0});
    expect(restored.travelJournal.archives, isEmpty);
    final well = restored.world.sites.firstWhere((s) => s.id == 'roots');
    expect((restored.hero.body.center - well.at).distance, lessThan(220));
  });

  test(
    'travel requires a discovered source, known destination and visiting that stage',
    () {
      final session = start();
      expect(GameCheckpoint.warp(session, WorldStage.forest, 'roots'), null);
      session.travelJournal.discover(WorldStage.forest, 'roots');
      session.hero.position.setValues(6000, 4200);
      expect(GameCheckpoint.warp(session, WorldStage.forest, 'roots'), null);
      visit(session, 'hub');
      expect(GameCheckpoint.warp(session, WorldStage.future, 'hub'), null);
      expect(GameCheckpoint.warp(session, WorldStage.forest, 'unknown'), null);
      session.riding = withOwnedMounts(session).mounts.first;
      expect(GameCheckpoint.warp(session, WorldStage.forest, 'roots'), null);
    },
  );

  test(
    'cross-chapter roundtrip retains scene state without foreign kill credit',
    () {
      final forest = start();
      visit(forest, 'hub');
      forest.openedChests.add(0);
      final mob = forest.spawnEnemy('goblin', const Offset(6000, 4200))!;
      mob.life.initial(100);
      mob.life.update(37);
      final area = EncounterArea('1:1', const Offset(6000, 4200), waves: 3);
      forest.encounterAreas[area.key] = area;
      mob.encounterKey = area.key;
      finishForest(forest);
      final sands = start(GameCheckpoint.advance(forest)!);
      expect(sands.travelJournal.archives.keys, {WorldStage.forest});
      expect(sands.progress.bossDefeated, false);
      visit(sands, 'hub');
      final giver = timeQuestGivers.first;
      final giverAt = sands.world.questGiverAt(giver.path);
      sands.hero.position.setValues(giverAt.dx - 14, giverAt.dy - 12);
      expect(sands.nearbyTimeGiver, giver);
      expect(sands.acceptCommission(timeCommissions.first), true);
      sands.progress.kills += 7;
      sands.progress.hp = 43;
      sands.progress.energy = 9;
      sands.hero.cooldowns['warcry'] = 1.5;
      visit(sands, 'hub');
      final home = start(GameCheckpoint.warp(sands, WorldStage.forest, 'hub')!);
      expect(home.stageKills, 120);
      expect(home.progress.kills, 127);
      expect(home.progress.bossDefeated, true);
      expect(home.progress.hp, 43);
      expect(home.openedChests, {0});
      expect(home.encounterAreas[area.key]!.waves, 3);
      expect(home.dormantEnemies.single['hp'], 37);
      expect(home.dormantEnemies.single['maxHp'], 100);
      home.progress.kills += 4;
      final back = start(GameCheckpoint.warp(home, WorldStage.sands, 'hub')!);
      expect(back.progress.kills, 131);
      expect(back.stageKills, 7);
      expect(back.progress.kills - back.commissionStartKills, 7);
      expect(back.currentCommission!.id, 'past-1');
      expect(back.timePath, TimePath.past);
      expect(back.progress.bossDefeated, false);
      expect(back.progress.hp, 43);
      expect(back.progress.energy, 9);
      expect(back.hero.cooldowns['warcry'], 1.5);
      expect(back.travelJournal.archives.keys, {WorldStage.forest});
    },
  );

  test(
    'an unfinished chapter boss keeps its exact health after a roundtrip',
    () {
      final forest = start();
      visit(forest, 'hub');
      finishForest(forest);
      final sands = start(GameCheckpoint.advance(forest)!);
      sands.timePath = TimePath.past;
      sands.cleansedSites.addAll(
        timeCommissions.where((q) => q.path == TimePath.past).map((q) => q.id),
      );
      final boss = sands.spawnEnemy(
        'golem',
        sands.world.spawn + const Offset(700, 0),
        boss: true,
      )!;
      boss.life.initial(900);
      boss.life.update(321);
      sands.bossSummoned = true;
      visit(sands, 'hub');
      final home = start(GameCheckpoint.warp(sands, WorldStage.forest, 'hub')!);
      final back = start(GameCheckpoint.warp(home, WorldStage.sands, 'hub')!);
      final restoredBoss = back.mobs.singleWhere((m) => m.boss);
      expect(restoredBoss.life.value, 321);
      expect(restoredBoss.life.max, 900);
      expect(back.bossSummoned, true);
      expect(back.progress.bossDefeated, false);
      expect(back.mandatoryQuestsComplete, true);
    },
  );

  test(
    'advancing again restores an existing next chapter without free healing',
    () {
      final forest = start();
      visit(forest, 'hub');
      finishForest(forest);
      final sands = start(GameCheckpoint.advance(forest)!);
      visit(sands, 'hub');
      sands.progress.hp = 24;
      sands.progress.energy = 6;
      sands.hero.cooldowns['warcry'] = 1.5;
      sands.openedChests.add(2);
      final home = start(GameCheckpoint.warp(sands, WorldStage.forest, 'hub')!);
      final back = start(GameCheckpoint.advance(home)!);
      expect(back.world.stage, WorldStage.sands);
      expect(back.progress.hp, 24);
      expect(back.progress.energy, 6);
      expect(back.hero.cooldowns['warcry'], 1.5);
      expect(back.openedChests, {2});
    },
  );

  test(
    'chapter loot is carried once, then stays in its scene during warps',
    () {
      final forest = start();
      visit(forest, 'hub');
      forest.dropGear(
        forest.progress.createGear(gearById('axe')),
        const Offset(6000, 4200),
      );
      finishForest(forest);
      final sands = start(GameCheckpoint.advance(forest)!);
      visit(sands, 'hub');
      expect(sands.loot.length, 1);
      final serial = sands.loot.single.item.serial;
      expect(sands.travelJournal.archives[WorldStage.forest]!['loot'], isEmpty);
      final home = start(GameCheckpoint.warp(sands, WorldStage.forest, 'hub')!);
      expect(home.loot, isEmpty);
      final back = start(GameCheckpoint.warp(home, WorldStage.sands, 'hub')!);
      expect(back.loot.map((item) => item.item.serial), [serial]);
    },
  );

  for (final path in TimePath.values) {
    test(
      '${path.name} keeps all three visited chapters when warping back and forth',
      () {
        final forest = start();
        visit(forest, 'hub');
        finishForest(forest);
        final sands = start(GameCheckpoint.advance(forest)!);
        visit(sands, 'hub');
        sands.timePath = path;
        sands.cleansedSites.addAll(
          timeCommissions.where((q) => q.path == path).map((q) => q.id),
        );
        sands.progress.kills += WorldStage.sands.killGoal;
        sands.progress.bossDefeated = true;
        final leaf = start(GameCheckpoint.advance(sands)!);
        final leafStage = path == TimePath.past
            ? WorldStage.past
            : WorldStage.future;
        expect(leaf.world.stage, leafStage);
        expect(leaf.world.spawn, leafStage.arrival);
        expect(leaf.travelJournal.archives.keys.toSet(), {
          WorldStage.forest,
          WorldStage.sands,
        });
        visit(leaf, 'hub');
        leaf.progress.kills += 5;
        leaf.progress.hp = 31;
        leaf.progress.energy = 7;
        final home = start(
          GameCheckpoint.warp(leaf, WorldStage.forest, 'hub')!,
        );
        expect(home.stageKills, 120);
        final middle = start(
          GameCheckpoint.warp(home, WorldStage.sands, 'hub')!,
        );
        expect(middle.stageKills, WorldStage.sands.killGoal);
        expect(middle.timePath, path);
        expect(middle.stageCleared, true);
        final back = start(GameCheckpoint.warp(middle, leafStage, 'hub')!);
        expect(back.stageKills, 5);
        expect(back.progress.bossDefeated, false);
        expect(back.progress.hp, 31);
        expect(back.progress.energy, 7);
        expect(back.world.spawn, leafStage.arrival);
        expect(back.travelJournal.wells.map((well) => well.stage).toSet(), {
          WorldStage.forest,
          WorldStage.sands,
          leafStage,
        });
      },
    );
  }

  test(
    'valid per-scene enemy budgets are not reduced by visiting another stage',
    () {
      final forest = start();
      visit(forest, 'hub');
      finishForest(forest);
      final data = GameCheckpoint.advance(forest)!.data;
      Map<String, dynamic> survivor() => {
        'kind': 'goblin',
        'trait': 'none',
        'area': null,
        'x': 6000,
        'y': 4200,
        'hp': 17,
        'maxHp': 100,
      };
      data['enemies'] = List.generate(2500, (_) => survivor());
      data['travel']['archives']['forest']['enemies'] = List.generate(
        2501,
        (_) => survivor(),
      );
      final saved = GameCheckpoint.decode(jsonEncode(data))!;
      expect((saved.data['enemies'] as List).length, 2500);
      expect(
        (saved.data['travel']['archives']['forest']['enemies'] as List).length,
        2501,
      );
    },
  );

  test(
    'captured and restored inactive scenes remain detached from live mutations',
    () {
      final forest = withOwnedMounts(start());
      visit(forest, 'hub');
      finishForest(forest);
      forest.dormantEnemies.add({
        'kind': 'goblin',
        'trait': 'none',
        'area': null,
        'x': 6000,
        'y': 4200,
        'hp': 37,
        'maxHp': 100,
        'power': {
          'version': 2,
          'distance': 5000.0,
          'health': 1.0,
          'damage': 1.0,
          'level': 1,
          'defense': 0.0,
        },
      });
      final sands = start(GameCheckpoint.advance(forest)!);
      final liveArchive = sands.travelJournal.archives[WorldStage.forest]!;
      final liveMount = (liveArchive['mounts'] as List).first as Map;
      liveMount.remove('durability');
      final saved = GameCheckpoint.capture(sands)!;
      final savedArchive = saved.data['travel']['archives']['forest'] as Map;
      expect(
        liveMount.containsKey('durability'),
        false,
        reason:
            'archive defaults are applied inside the detached snapshot only',
      );
      expect((savedArchive['mounts'] as List).first['durability'], 100);
      final liveEnemy = (liveArchive['enemies'] as List).single as Map;
      final savedEnemy = (savedArchive['enemies'] as List).single as Map;
      liveEnemy['hp'] = 29;
      (liveArchive['sites'] as List).clear();
      expect(savedEnemy['hp'], 37);
      expect((savedArchive['sites'] as List).length, forest.world.sites.length);
      final restored = start(saved);
      savedEnemy['hp'] = 11;
      (savedArchive['sites'] as List).clear();
      final restoredArchive =
          restored.travelJournal.archives[WorldStage.forest]!;
      expect((restoredArchive['enemies'] as List).single['hp'], 37);
      expect(
        (restoredArchive['sites'] as List).length,
        forest.world.sites.length,
      );
      expect(liveEnemy['hp'], 29);
    },
  );

  test(
    'each capture still rejects changed invalid runtime archive contents',
    () {
      final forest = start();
      visit(forest, 'hub');
      finishForest(forest);
      forest.dormantEnemies.add({
        'kind': 'goblin',
        'trait': 'none',
        'area': null,
        'x': 6000,
        'y': 4200,
        'hp': 37,
        'maxHp': 100,
        'power': {
          'version': 2,
          'distance': 5000.0,
          'health': 1.0,
          'damage': 1.0,
          'level': 1,
          'defense': 0.0,
        },
      });
      final sands = start(GameCheckpoint.advance(forest)!);
      expect(GameCheckpoint.capture(sands), isNotNull);
      final archive = sands.travelJournal.archives[WorldStage.forest]!;
      final enemy = (archive['enemies'] as List).single as Map;
      enemy['hp'] = 101;
      expect(GameCheckpoint.capture(sands), null);
      enemy['hp'] = 37;
      expect(GameCheckpoint.capture(sands), isNotNull);
      enemy['kind'] = 'unknown';
      expect(GameCheckpoint.capture(sands), null);
    },
  );

  test(
    'invalid archive graphs, duplicated loot and unknown wells are rejected',
    () {
      final forest = start();
      visit(forest, 'hub');
      finishForest(forest);
      final saved = GameCheckpoint.advance(forest)!;
      Map<String, dynamic> clone() =>
          jsonDecode(saved.encode()) as Map<String, dynamic>;
      for (final patch in <void Function(Map<String, dynamic>)>[
        (data) => data['hubOrigin'] = [-1, 0],
        (data) => data['attackClock'] = -1,
        (data) => data['dodgeClock'] = 1.6,
        (data) => data['travel']['discovered']['forest'] = ['unknown'],
        (data) => data['travel']['archives']['forest']['stageKills'] = -1,
        (data) =>
            data['travel']['archives']['forest']['progress'] = data['progress'],
        (data) => data['travel']['archives']['forest'].remove('enemies'),
        (data) => data['travel']['archives']['sands'] =
            data['travel']['archives']['forest'],
        (data) => data['travel']['archives']['forest']['stage'] = 'future',
        (data) => data['travel']['discovered']['future'] = ['hub'],
      ]) {
        final data = clone();
        patch(data);
        String? encoded;
        try {
          encoded = jsonEncode(data);
        } catch (_) {}
        expect(GameCheckpoint.decode(encoded), null);
      }
    },
  );
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/travel_journal.dart';
import 'package:guardian_new/world_model.dart';

import 'support/forest_quest_flow.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Adventure start({
    WorldStage stage = WorldStage.forest,
    Offset? hubOrigin,
    GameCheckpoint? saved,
  }) {
    final s =
        saved?.restore(GameArt()) ??
        Adventure(GameArt(), stage: stage, hubOrigin: hubOrigin);
    s.start(TestGame());
    addTearDown(s.dispose);
    return s;
  }

  void cleanse(Adventure s, QuestSite site) {
    if (s.world.stage == WorldStage.forest) {
      completeForestQuest(s, site.id);
      return;
    }
    s.mobs.clear();
    final center = wellApproachForSite(
      s.world.stage,
      site,
      hubOrigin: s.world.spawn,
    );
    s.hero.position.setValues(
      center.dx - s.hero.body.width / 2,
      center.dy - s.hero.body.height / 2,
    );
    expect(s.cleanseNearbySite(), true);
  }

  void visitHub(Adventure s) {
    s.travelJournal.discover(s.world.stage, 'hub');
    final well = wellSitesForStage(
      s.world.stage,
      hubOrigin: s.world.spawn,
    ).firstWhere((site) => site.id == 'hub');
    final center = s.world.wellApproach(well);
    s.hero.position.setValues(
      center.dx - s.hero.body.width / 2,
      center.dy - s.hero.body.height / 2,
    );
    final nearby = s.travelJournal.nearbyWell(s.world, s.hero.body.center);
    expect(nearby?.id, 'hub');
    expect(nearby?.stage, s.world.stage);
  }

  test(
    'fresh adventures guide the nearest mandatory site from their real hub',
    () {
      final forest = start();
      expect(forest.trackedSite?.id, 'roots');
      expect(start(stage: WorldStage.past).trackedSite?.id, 'origin');
      expect(start(stage: WorldStage.future).trackedSite?.id, 'uplink');
      final future = start(
        stage: WorldStage.future,
        hubOrigin: WorldStage.future.arrival,
      );
      expect(future.trackedSite?.id, 'relay');
      expect(future.hero.body.topLeft, WorldStage.future.arrival);
    },
  );

  test(
    'purifying the tracked site guides the nearest remaining site until done',
    () {
      final s = start();
      cleanse(s, s.trackedSite!);
      expect(s.trackedSite?.id, 'moon');
      cleanse(s, s.trackedSite!);
      expect(s.trackedSite?.id, 'sun');
      cleanse(s, s.trackedSite!);
      expect(s.trackedSiteId, null);
      expect(s.mandatoryQuestsComplete, true);
    },
  );

  test('purifying another site preserves a manual target or explicit off', () {
    final s = start(), target = s.world.sites.last;
    approachForestNpc(s, 'elin');
    expect(s.forestQuests.performAction(), true);
    expect(s.toggleTrackedSite(target), true);
    cleanse(s, s.world.sites.first);
    expect(s.trackedSite?.id, target.id);
    approachForestNpc(s, 'mira');
    expect(s.forestQuests.performAction(), true);
    expect(s.toggleTrackedSite(s.world.sites[1]), true);
    cleanse(s, s.world.sites[1]);
    expect(s.trackedSiteId, null);
    expect(start(saved: GameCheckpoint.capture(s)!).trackedSite, null);
  });

  test(
    'saved null and old missing navigation metadata override fresh defaults',
    () {
      final s = start();
      expect(s.toggleTrackedSite(s.trackedSite!), true);
      final checkpoint = GameCheckpoint.capture(s)!;
      for (final missing in [false, true]) {
        final data = jsonDecode(checkpoint.encode()) as Map<String, dynamic>;
        if (missing) data.remove('trackedSite');
        final restored = start(saved: GameCheckpoint.decode(jsonEncode(data))!);
        expect(restored.trackedSiteId, null);
        expect(restored.progress.toSave(), s.progress.toSave());
        visitHub(restored);
        final warped = start(
          saved: GameCheckpoint.warp(restored, WorldStage.forest, 'hub')!,
        );
        expect(warped.trackedSiteId, null);
      }
    },
  );

  test(
    'fresh chapter advancement selects from its arrival instead of the old hub',
    () {
      final sands = start(stage: WorldStage.sands)
        ..timePath = TimePath.future
        ..cleansedSites.addAll(
          timeCommissions
              .where((q) => q.path == TimePath.future)
              .map((q) => q.id),
        );
      sands.progress.bossDefeated = true;
      sands.progress.kills = WorldStage.sands.killGoal;
      final saved = GameCheckpoint.advance(sands)!;
      expect(saved.data['trackedSite'], 'relay');
      final future = start(saved: saved);
      expect(future.world.spawn, WorldStage.future.arrival);
      expect(future.trackedSite?.id, 'relay');
      expect(start(stage: WorldStage.future).trackedSite?.id, 'uplink');
    },
  );

  for (final targetId in ['gate', null]) {
    test(
      'archived chapter retains manual selection $targetId on either return path',
      () {
        final sands = start(stage: WorldStage.sands)
          ..timePath = TimePath.future
          ..cleansedSites.addAll(
            timeCommissions
                .where((q) => q.path == TimePath.future)
                .map((q) => q.id),
          );
        sands.progress.bossDefeated = true;
        sands.progress.kills = WorldStage.sands.killGoal;
        visitHub(sands);
        final future = start(saved: GameCheckpoint.advance(sands)!);
        final target = targetId == null
            ? future.trackedSite!
            : future.visibleSites.firstWhere((site) => site.id == targetId);
        expect(future.toggleTrackedSite(target), true);
        expect(future.trackedSiteId, targetId);
        visitHub(future);
        final middle = start(
          saved: GameCheckpoint.warp(future, WorldStage.sands, 'hub')!,
        );
        expect(
          middle.travelJournal.archives[WorldStage.future]!['trackedSite'],
          targetId,
        );
        final advanced = start(saved: GameCheckpoint.advance(middle)!);
        expect(advanced.trackedSiteId, targetId);
        final warped = start(
          saved: GameCheckpoint.warp(middle, WorldStage.future, 'hub')!,
        );
        expect(warped.trackedSiteId, targetId);
      },
    );
  }

  for (final path in TimePath.values) {
    test('desert ${path.name} guidance waits for each accepted commission', () {
      final s = start(
        stage: WorldStage.sands,
        hubOrigin: WorldStage.sands.arrival,
      );
      final quests = timeCommissions.where((q) => q.path == path).toList();
      expect(s.trackedSiteId, null);
      expect(s.timePath, null);
      // Authored arrivals may be beside an NPC. Exercise rejection from a
      // genuine field position rather than assuming the hub is out of range.
      inCombatField(s);
      expect(s.nearbyTimeGiver, isNull);
      expect(s.acceptCommission(quests.first), false);
      expect(s.trackedSiteId, null);
      final at = s.world.questGiverAt(path);
      s.hero.position.setValues(at.dx - 14, at.dy - 12);
      expect(s.acceptCommission(quests.first), true);
      expect(s.timePath, path);
      expect(s.trackedSite?.id, quests.first.id);
      expect(s.toggleTrackedSite(s.trackedSite!), true);
      final restored = start(saved: GameCheckpoint.capture(s)!);
      expect(restored.currentCommission?.id, quests.first.id);
      expect(restored.trackedSiteId, null);
      restored.progress.kills += quests.first.goal;
      cleanse(restored, quests.first.site);
      expect(restored.trackedSiteId, null);
      expect(restored.currentCommission, null);
      expect(restored.canAcceptCommission(quests[1]), true);
      expect(restored.acceptCommission(quests[1]), true);
      expect(restored.trackedSite?.id, quests[1].id);
      restored.progress.kills += quests[1].goal;
      cleanse(restored, quests[1].site);
      expect(restored.trackedSiteId, null);
      expect(restored.acceptedCommission, null);
    });
  }
}

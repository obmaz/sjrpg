import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/encounter_beacon_art.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/quest_guide.dart';
import 'package:guardian_new/travel_journal.dart';
import 'package:guardian_new/world_model.dart';

import 'quest_routes_test.dart' show questRoutes;
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure start(WorldStage stage, {TimePath? path}) {
    final s = Adventure(GameArt(), stage: stage, hubOrigin: stage.arrival)
      ..start(TestGame());
    if (path != null) s.timePath = path;
    addTearDown(s.dispose);
    return s;
  }

  Adventure resume(GameCheckpoint checkpoint) {
    final s = checkpoint.restore(GameArt())..start(TestGame());
    addTearDown(s.dispose);
    return s;
  }

  void accept(Adventure s) {
    s.hero.position.setValues(s.world.elderAt.dx - 14, s.world.elderAt.dy - 12);
    expect(s.acceptChapterContract(), true);
    expect(s.acceptChapterContract(), false);
  }

  void complete(Adventure s) {
    s.cleansedSites.addAll(s.world.sites.map((site) => site.id));
    s.progress.kills += s.world.stage.killGoal;
    s.progress.bossDefeated = true;
    expect(s.stageCleared, true);
  }

  void visit(Adventure s, String id) {
    final well = wellSitesForStage(
      s.world.stage,
      hubOrigin: s.world.spawn,
    ).firstWhere((well) => well.id == id);
    final approach = s.world.wellApproach(well);
    s.hero.position.setValues(approach.dx - 14, approach.dy - 12);
    s.hero.lastClearPosition = Offset(s.hero.position.x, s.hero.position.y);
    s.travelJournal.discover(s.world.stage, id);
  }

  test('new stages append identities and use valid existing art families', () {
    expect(WorldStage.values.take(4).map((s) => s.name), [
      'forest',
      'sands',
      'past',
      'future',
    ]);
    for (final stage in WorldStage.values) {
      expect(stage.baseMaterial, inInclusiveRange(0, 11));
      expect(stage.roadMaterial, inInclusiveRange(0, 11));
      expect(
        EncounterBeaconArt.frame(stage, ready: false).source.width,
        greaterThan(0),
      );
      expect(stage.title, isNotEmpty);
      expect(stage.bossActor, isNotEmpty);
    }
    expect(WorldStage.convergence.hasNextStage, false);
    expect(WorldStage.sands.nextStage(null), null);
  });

  for (final path in TimePath.values) {
    test('$path chapter3 advances through its chapter4 and converges in5', () {
      final third = start(
        path == TimePath.past ? WorldStage.past : WorldStage.future,
      );
      complete(third);
      // Existing completed chapter3 saves did not have a contract or travel journal.
      final oldData = GameCheckpoint.capture(third)!.data..remove('travel');
      final oldSave = GameCheckpoint.decode(jsonEncode(oldData));
      expect(oldSave, isNotNull);
      final oldThird = resume(oldSave!);
      final fourthSave = GameCheckpoint.advance(oldThird);
      expect(fourthSave, isNotNull);
      final fourth = resume(fourthSave!);
      expect(
        fourth.world.stage,
        path == TimePath.past ? WorldStage.tombs : WorldStage.foundry,
      );
      expect(fourth.timePath, path);
      expect(fourth.chapterContractAccepted, false);
      expect(fourth.trackedSite, null);
      expect(GameCheckpoint.advance(fourth), null);
      accept(fourth);
      expect(fourth.chapterContractAccepted, true);
      expect(fourth.trackedSite, isNotNull);
      visit(fourth, 'hub');
      complete(fourth);
      final fifth = resume(GameCheckpoint.advance(fourth)!);
      expect(fifth.world.stage, WorldStage.convergence);
      expect(fifth.timePath, path);
      expect(fifth.world.spawn, WorldStage.convergence.arrival);
      expect(fifth.stageContract!.id, 'convergence-${path.name}');
      expect(
        fifth.stageContract!.giver,
        path == TimePath.past ? '왕국의 기록관' : '저항군 기술자',
      );
      expect(fifth.mainQuestNext, contains(fifth.stageContract!.giver));
      accept(fifth);
      final contract = fifth.acceptedCommission;
      final corruptedArchive =
          jsonDecode(GameCheckpoint.capture(fifth)!.encode())
              as Map<String, dynamic>;
      ((corruptedArchive['travel'] as Map)['archives']
          as Map)[fourth.world.stage.name]['timePath'] = path == TimePath.past
          ? 'future'
          : 'past';
      expect(
        GameCheckpoint.decode(jsonEncode(corruptedArchive)),
        null,
        reason: 'another era cannot enter a new chapter archive',
      );
      complete(fifth);
      final restoredFifth = resume(GameCheckpoint.capture(fifth)!);
      expect(restoredFifth.stageCleared, true);
      expect(restoredFifth.acceptedCommission, contract);
      expect(restoredFifth.timePath, path);
      expect(GameCheckpoint.advance(restoredFifth), null);
      visit(restoredFifth, 'hub');
      final back = resume(
        GameCheckpoint.warp(restoredFifth, fourth.world.stage, 'hub')!,
      );
      expect(back.stageCleared, true);
      expect(back.timePath, path);
      visit(back, 'hub');
      final returned = resume(
        GameCheckpoint.warp(back, WorldStage.convergence, 'hub')!,
      );
      expect(returned.stageCleared, true);
      expect(returned.acceptedCommission, contract);
      expect(returned.timePath, path);
    });
  }

  for (final path in TimePath.values) {
    test(
      '$path entire five-chapter route preserves every prior well archive',
      () {
        final forest = start(WorldStage.forest);
        visit(forest, 'hub');
        complete(forest);
        final desert = resume(GameCheckpoint.advance(forest)!);
        visit(desert, 'hub');
        final giver = timeQuestGivers.firstWhere((giver) => giver.path == path);
        final at = desert.world.questGiverAt(giver.path);
        desert.hero.position.setValues(at.dx - 14, at.dy - 12);
        expect(desert.nearbyTimeGiver, giver);
        for (final quest in timeCommissions.where(
          (quest) => quest.path == path,
        )) {
          expect(desert.acceptCommission(quest), true);
          desert.progress.kills += quest.goal;
          desert.hero.position.setValues(
            quest.site.at.dx - 14,
            quest.site.at.dy + 65,
          );
          desert.mobs.clear();
          expect(desert.cleanseNearbySite(), true);
        }
        desert.progress.kills =
            desert.stageStartKills + desert.world.stage.killGoal;
        desert.progress.bossDefeated = true;
        final third = resume(GameCheckpoint.advance(desert)!);
        visit(third, 'hub');
        complete(third);
        final fourth = resume(GameCheckpoint.advance(third)!);
        accept(fourth);
        visit(fourth, 'hub');
        complete(fourth);
        final fifth = resume(GameCheckpoint.advance(fourth)!);
        expect(fifth.travelJournal.archives, hasLength(4));
        expect(
          fifth.travelJournal.hasDiscovered(WorldStage.forest, 'hub'),
          true,
        );
        accept(fifth);
        visit(fifth, 'hub');
        final home = resume(
          GameCheckpoint.warp(fifth, WorldStage.forest, 'hub')!,
        );
        expect(home.travelJournal.archives, hasLength(4));
        expect(home.stageCleared, true);
        visit(home, 'hub');
        final returned = resume(
          GameCheckpoint.warp(home, WorldStage.convergence, 'hub')!,
        );
        expect(returned.timePath, path);
        expect(returned.acceptedCommission, 'convergence-${path.name}');
        expect(returned.travelJournal.archives, hasLength(4));
      },
    );
  }

  test(
    'final map and objectives match while branch contract and giver differ',
    () {
      final past = start(WorldStage.convergence, path: TimePath.past);
      final future = start(WorldStage.convergence, path: TimePath.future);
      expect(
        past.world.sites.map((s) => (s.id, s.at)),
        future.world.sites.map((s) => (s.id, s.at)),
      );
      expect(
        past.world.trails.map((t) => t.points),
        future.world.trails.map((t) => t.points),
      );
      expect(past.stageContract!.giver, isNot(future.stageContract!.giver));
      expect(past.stageContract!.actor, isNot(future.stageContract!.actor));
      expect(past.stageContract!.title, isNot(future.stageContract!.title));
      expect(past.stageContract!.story, isNot(future.stageContract!.story));
      expect(past.world.elderAt, future.world.elderAt);
    },
  );

  test('chapter contracts require an actual NPC visit before objectives', () {
    for (final stage in [
      WorldStage.tombs,
      WorldStage.foundry,
      WorldStage.convergence,
    ]) {
      final s = start(stage);
      final site = s.world.sites.first;
      s.hero.position.setValues(site.at.dx - 14, site.at.dy + 65);
      expect(s.acceptChapterContract(), false);
      expect(s.nearbySite, null);
      expect(s.cleanseNearbySite(), false);
      expect(s.toggleTrackedSite(site), false);
      expect(s.nearbyQuestGuide!.message, contains(s.stageContract!.giver));
      accept(s);
      s.hero.position.setValues(site.at.dx - 14, site.at.dy + 65);
      s.mobs.clear();
      expect(s.nearbySite?.id, site.id);
      expect(s.cleanseNearbySite(), true);
      expect(
        s.acceptedCommission,
        s.stageContract!.id,
        reason: 'one contract covers all three shared objectives',
      );
    }
  });

  test('invalid era and foreign chapter contract saves are rejected', () {
    final s = start(WorldStage.tombs);
    accept(s);
    final data = GameCheckpoint.capture(s)!.data;
    expect(
      GameCheckpoint.decode(jsonEncode({...data, 'timePath': 'future'})),
      null,
    );
    expect(
      GameCheckpoint.decode(
        jsonEncode({...data, 'commission': 'foundry-contract'}),
      ),
      null,
    );
    final finalStage = start(WorldStage.convergence);
    accept(finalStage);
    final finalData = GameCheckpoint.capture(finalStage)!.data;
    expect(
      GameCheckpoint.decode(
        jsonEncode({...finalData, 'commission': 'convergence-future'}),
      ),
      null,
      reason: 'a past finale cannot accept the future NPC contract',
    );
    expect(
      GameCheckpoint.decode(
        jsonEncode({
          ...GameCheckpoint.capture(finalStage)!.data,
          'timePath': null,
        }),
      ),
      null,
    );
  });

  test(
    'new map layouts have distinct distributed sites and traversable services',
    () {
      final roads = <String>{};
      for (final stage in [
        WorldStage.tombs,
        WorldStage.foundry,
        WorldStage.convergence,
      ]) {
        final s = start(stage), w = s.world;
        expect(w.blocked(s.hero.body), false);
        expect(w.sanctuary.protects(s.hero.body), true);
        expect(w.settlementCollision, isNotEmpty);
        for (final uv in const [
          Offset(.09, .19),
          Offset(.80, .135),
          Offset(.045, .72),
          Offset(.95, .70),
        ]) {
          expect(
            w.blocked(
              Rect.fromCenter(
                center: w.authoredSettlement.point(uv),
                width: 28,
                height: 24,
              ),
            ),
            true,
            reason: '$stage painted perimeter must remain solid',
          );
        }
        expect(
          w.sites.map((s) => s.at.dx).reduce((a, b) => a < b ? a : b),
          lessThan(worldSize.width * .4),
        );
        expect(
          w.sites.map((s) => s.at.dx).reduce((a, b) => a > b ? a : b),
          greaterThan(worldSize.width * .6),
        );
        expect(
          w.sites.map((s) => s.at.dy).reduce((a, b) => a > b ? a : b),
          greaterThan(worldSize.height * .75),
        );
        roads.add(w.trails.map((t) => t.points).toString());
        for (final at in [
          w.elderAt,
          w.merchantAt,
          w.wellApproach(
            wellSitesForStage(
              stage,
              hubOrigin: w.spawn,
            ).firstWhere((well) => well.id == 'hub'),
          ),
        ]) {
          final safe = w.spawnNear(at, const Size(28, 24));
          expect(safe, isNotNull);
          expect((safe! - at).distance, lessThan(160));
          expect(w.sanctuary.protects(safe & const Size(28, 24)), true);
        }
        w.openedChests.addAll(List.generate(w.chests.length, (i) => i));
        final routes = questRoutes(w, const Size(28, 24));
        expect(routes.keys, containsAll(w.sites.map((site) => site.id)));
        for (final site in w.sites) {
          var from = w.spawn;
          for (final center in routes[site.id]!.skip(1)) {
            final target = center - const Offset(14, 12);
            final moved = w.move(from, target - from, const Size(28, 24));
            expect(
              (moved - target).distance,
              lessThan(.05),
              reason:
                  '$stage quest ${site.id} follows actual connected full-body approaches',
            );
            from = moved;
          }
          expect(
            (from + const Offset(14, 12) - site.at).distance,
            lessThan(115),
          );
        }
        for (final site in w.sites) {
          expect(
            w.blocked(
              Rect.fromCenter(
                center: site.at + const Offset(0, 65),
                width: 28,
                height: 24,
              ),
            ),
            false,
          );
        }
      }
      expect(roads, hasLength(3));
    },
  );
}

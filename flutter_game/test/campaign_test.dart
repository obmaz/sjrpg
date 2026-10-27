import 'dart:convert';
import 'dart:ui' show Size, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session(WorldStage stage) {
    final s = Adventure(GameArt(), stage: stage);
    s.start(TestGame());
    s.mobs.clear();
    addTearDown(s.dispose);
    return s;
  }

  for (final stage in WorldStage.values.skip(1)) {
    test(
      '${stage.name} roads admit full bodies after breakable chests are cleared',
      () {
        final world = AdventureWorld(stage: stage);
        expect(worldSize, const Size(34560, 25920));
        expect(
          world.blocked(Rect.fromLTWH(world.spawn.dx, world.spawn.dy, 40, 32)),
          false,
        );
        world.openedChests.addAll(List.generate(world.chests.length, (i) => i));
        for (final size in const [Size(24, 22), Size(40, 32)]) {
          final half = Offset(size.width / 2, size.height / 2);
          for (final trail in world.trails) {
            var at = trail.points.first - half;
            expect(world.blocked(at & size), false);
            for (final to in trail.points.skip(1)) {
              final target = to - half;
              at = world.move(at, target - at, size);
              expect(
                (at - target).distance,
                lessThan(2),
                reason: '${stage.name} road $to / $size',
              );
            }
          }
        }
        expect(world.chests.length, 26 + world.sites.length * 2);
        for (final at in world.chests) {
          expect(
            world.blocked(Rect.fromCenter(center: at, width: 28, height: 24)),
            false,
            reason: 'chest $at',
          );
        }
      },
    );
  }
  test('camp services and ruined arch openings stay physically accessible', () {
    for (final stage in WorldStage.values.skip(1)) {
      final world = AdventureWorld(stage: stage);
      expect(
        world.blocked(
          Rect.fromCenter(
            center: world.merchantAt + const Offset(14, 24),
            width: 28,
            height: 24,
          ),
        ),
        false,
      );
      expect(
        world.blocked(
          Rect.fromCenter(
            center: world.healAt + const Offset(0, 60),
            width: 28,
            height: 24,
          ),
        ),
        false,
      );
      expect(world.campProps.length, 2);
    }
    final world = AdventureWorld(stage: WorldStage.past);
    final arches = world.props.where((p) => p.kind == 'ruin-4');
    expect(arches, isNotEmpty);
    var checked = 0;
    for (final arch in arches.take(10)) {
      for (final size in const [Size(28, 24), Size(40, 32)]) {
        final start =
            arch.body.center - Offset(size.width / 2, 80 + size.height / 2);
        final end = start + const Offset(0, 160);
        if (world.blocked(start & size) || world.blocked(end & size)) continue;
        expect(
          (world.move(start, end - start, size) - end).distance,
          lessThan(2),
        );
        expect(
          world.blocked(
            Rect.fromCenter(
              center: arch.body.centerLeft + const Offset(10, 0),
              width: 10,
              height: 10,
            ),
          ),
          true,
        );
        checked++;
      }
    }
    expect(checked, greaterThanOrEqualTo(10));
  });
  test('stages use distinct geography, starts and monster themes', () {
    final worlds = [
      for (final stage in WorldStage.values) AdventureWorld(stage: stage),
    ];
    expect(worlds.map((w) => w.spawn).toSet().length, WorldStage.values.length);
    expect(
      worlds.map((w) => w.trails.first.points.first).toSet().length,
      WorldStage.values.length,
    );
    for (final stage in WorldStage.values.skip(1)) {
      final s = session(stage);
      final field = s.world.trails.first.points.firstWhere(
        (point) =>
            (point - s.world.sanctuary.center).distance >
                s.world.sanctuary.radius + 900 &&
            !s.world.blocked(
              Rect.fromCenter(center: point, width: 28, height: 24),
            ),
      );
      s.hero.position.setValues(field.dx - 14, field.dy - 12);
      s.spawnPack(initial: true);
      final kinds = s.mobs.map((m) => m.kind).toSet();
      expect(kinds, isNotEmpty);
      if (stage == WorldStage.future) {
        expect(kinds, containsAll(['cyber', 'gunner']));
      }
      expect(
        kinds,
        everyElement(
          isIn(
            stage == WorldStage.sands
                ? ['scorpion', 'mummy', 'cultist', 'basilisk', 'viper']
                : stage == WorldStage.past || stage == WorldStage.tombs
                ? [
                    'skeleton',
                    'troll',
                    'cultist',
                    'wraith',
                    'viper',
                    'bonehound',
                  ]
                : stage == WorldStage.convergence
                ? [
                    'crystal-beetle',
                    'wolf',
                    'wraith',
                    'boar',
                    'skeleton',
                    'cyber',
                    'cultist',
                    'drone',
                    'goblin',
                  ]
                : ['cyber', 'gunner', 'drone', 'clockwork-spider'],
          ),
        ),
      );
    }
  });
  for (final path in TimePath.values) {
    test(
      '${path.name} locks the other four commissions and saves a sequential four-step journey',
      () {
        final s = session(WorldStage.sands);
        s.progress.kills = 200;
        s.stageStartKills = 200;
        s.commissionStartKills = 200;
        final branch = timeCommissions.where((q) => q.path == path).toList();
        final other = timeCommissions.where((q) => q.path != path).toList();
        expect(timeCommissions.length, 8);
        expect(timeCommissions.where(s.canAcceptCommission).length, 2);
        expect(s.acceptCommission(branch.last), false);
        for (final q in branch) {
          if (q.step == 0) {
            final giver = timeQuestGivers.firstWhere((g) => g.path == path);
            s.hero.position.setValues(giver.at.dx - 14, giver.at.dy - 12);
          }
          expect(s.acceptCommission(q), true);
          expect(s.acceptCommission(other.first), false);
          expect(s.acceptCommission(q), false);
          expect(
            s.visibleSites.every(
              (site) => branch.any((b) => b.site.id == site.id),
            ),
            true,
          );
          s.hero.position.setValues(q.site.at.dx - 12, q.site.at.dy - 11);
          expect(s.cleanseNearbySite(), false);
          s.progress.kills += q.goal;
          expect(s.cleanseNearbySite(), true);
          final gold = s.progress.gold;
          expect(s.cleanseNearbySite(), false);
          expect(s.progress.gold, gold);
          final saved = GameCheckpoint.capture(s)!;
          expect(GameCheckpoint.decode(saved.encode()), isNotNull);
          final restored = saved.restore(GameArt());
          addTearDown(restored.dispose);
          expect(restored.cleansedSites, s.cleansedSites);
          expect(restored.timePath, path);
          expect(restored.acceptedCommission, null);
        }
        expect(s.mandatoryQuestsComplete, true);
        expect(s.stageCleared, false);
        expect(s.canAcceptCommission(other.first), false);
        s.progress.kills = s.stageStartKills + WorldStage.sands.killGoal;
        s.tick(.05);
        final boss = s.mobs.firstWhere((m) => m.boss);
        s.hit(boss, 10000000, Offset.zero);
        expect(s.stageCleared, true);
        final next = GameCheckpoint.advance(s)!;
        final n = next.restore(GameArt());
        addTearDown(n.dispose);
        expect(
          n.world.stage,
          path == TimePath.past ? WorldStage.past : WorldStage.future,
        );
        expect(n.timePath, path);
        expect(n.stageKills, 0);
        expect(n.progress.bossDefeated, false);
        expect(n.cleansedSites, isEmpty);
        expect(n.loot.length, s.loot.length);
        expect(
          n.progress.inventory.map((g) => g.toSave()),
          s.progress.inventory.map((g) => g.toSave()),
        );
      },
    );
  }
  test(
    'stage one requires its quests and boss before advancing, and preserves progression',
    () {
      final s = session(WorldStage.forest);
      expect(GameCheckpoint.advance(s), null);
      s.progress.bossDefeated = true;
      expect(GameCheckpoint.advance(s), null);
      s.cleansedSites.addAll(questSites.map((q) => q.id));
      final before = s.progress.toSave();
      final next = GameCheckpoint.advance(s)!;
      expect(next.data['stage'], 'sands');
      expect(next.data['timePath'], null);
      expect(next.progress.gold, s.progress.gold);
      expect(next.progress.ranks, s.progress.ranks);
      expect(next.progress.level, s.progress.level);
      expect(s.progress.toSave(), before);
    },
  );
  test(
    'unknown stages, cross-branch completions and skipped quest chains are rejected',
    () {
      final s = session(WorldStage.sands);
      final giver = timeQuestGivers.first;
      s.hero.position.setValues(giver.at.dx - 14, giver.at.dy - 12);
      expect(s.acceptCommission(timeCommissions.first), true);
      final source = GameCheckpoint.capture(s)!.data;
      for (final patch in [
        {'stage': 'unknown'},
        {'timePath': 'unknown'},
        {
          'sites': ['future-1'],
        },
        {
          'sites': ['past-2'],
        },
        {'commission': 'past-4'},
        {'stageStartKills': 9999},
        {'commissionStartKills': -1},
      ]) {
        expect(
          GameCheckpoint.decode(jsonEncode({...source, ...patch})),
          null,
          reason: '$patch',
        );
      }
    },
  );
  test('final stage quests gate completion and no next stage is invented', () {
    for (final path in TimePath.values) {
      final s = session(WorldStage.convergence);
      s.timePath = path;
      s.hero.position.setValues(
        s.world.elderAt.dx - 14,
        s.world.elderAt.dy - 12,
      );
      expect(s.acceptChapterContract(), true);
      s.progress.bossDefeated = true;
      expect(s.stageCleared, false);
      for (final q in s.world.sites) {
        s.hero.position.setValues(q.at.dx - 12, q.at.dy - 11);
        expect(s.cleanseNearbySite(), true);
      }
      expect(s.stageCleared, true);
      expect(GameCheckpoint.advance(s), null);
    }
  });
}

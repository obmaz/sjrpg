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
      '${stage.name} has its own full-sized layout and all visible roads admit full bodies',
      () {
        final world = AdventureWorld(stage: stage);
        expect(worldSize, const Size(46080, 34560));
        expect(
          world.blocked(Rect.fromLTWH(world.spawn.dx, world.spawn.dy, 40, 32)),
          false,
        );
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
  test('stages use distinct geography, starts and monster themes', () {
    final worlds = [
      for (final stage in WorldStage.values) AdventureWorld(stage: stage),
    ];
    expect(worlds.map((w) => w.spawn).toSet().length, 4);
    expect(worlds.map((w) => w.trails.first.points.first).toSet().length, 4);
    for (final stage in WorldStage.values.skip(1)) {
      final s = session(stage);
      s.spawnPack(initial: true);
      final kinds = s.mobs.map((m) => m.kind).toSet();
      expect(kinds, isNotEmpty);
      expect(
        kinds,
        everyElement(
          isIn(
            stage == WorldStage.sands
                ? ['scorpion', 'mummy', 'cultist']
                : stage == WorldStage.past
                ? ['skeleton', 'troll', 'cultist']
                : ['cyber'],
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
    for (final stage in [WorldStage.past, WorldStage.future]) {
      final s = session(stage);
      s.timePath = stage == WorldStage.past ? TimePath.past : TimePath.future;
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

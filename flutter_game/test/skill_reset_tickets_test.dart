import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/skills_panel.dart';
import 'package:guardian_new/travel_journal.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure start({
    GameCheckpoint? saved,
    WorldStage stage = WorldStage.forest,
  }) {
    final s = saved?.restore(GameArt()) ?? Adventure(GameArt(), stage: stage);
    s.start(TestGame());
    addTearDown(s.dispose);
    return s;
  }

  void finish(Adventure s, TimePath path) {
    if (s.world.stage == WorldStage.sands) {
      s.timePath = path;
      s.cleansedSites.addAll(
        timeCommissions.where((q) => q.path == path).map((q) => q.id),
      );
      s.acceptedCommission = null;
    } else {
      if (s.world.stage.requiresContract) {
        s.hero.position.setValues(
          s.world.elderAt.dx - 14,
          s.world.elderAt.dy - 12,
        );
        expect(s.acceptChapterContract(), isTrue);
      }
      s.cleansedSites.addAll(s.world.sites.map((site) => site.id));
    }
    s.progress.bossDefeated = true;
    s.progress.kills += s.world.stage.killGoal;
    s.completeStageIfReady();
    expect(s.stageCleared, isTrue);
    expect(s.won, isTrue);
  }

  void visitHub(Adventure s) {
    final well = wellSitesForStage(
      s.world.stage,
      hubOrigin: s.world.spawn,
    ).firstWhere((w) => w.id == 'hub');
    s.travelJournal.discover(s.world.stage, 'hub');
    s.hero.position.setValues(well.at.dx - 14, well.at.dy + 65);
    s.hero.lastClearPosition = Offset(s.hero.position.x, s.hero.position.y);
  }

  test(
    'a first completed stage awards one ticket only after all mandatory work',
    () {
      final s = start();
      s.progress.bossDefeated = true;
      s.completeStageIfReady();
      expect(s.progress.skillResetTickets, 0);
      expect(s.won, isFalse);
      s.cleansedSites.addAll(s.world.sites.map((site) => site.id));
      s.completeStageIfReady();
      expect(s.progress.skillResetTickets, 1);
      expect(s.progress.claimedResetStages, {WorldStage.forest});
      s.completeStageIfReady();
      expect(s.progress.skillResetTickets, 1);
      s.continueExploring();
      s.completeStageIfReady();
      expect(s.progress.skillResetTickets, 1);
    },
  );

  for (final path in TimePath.values) {
    test(
      '$path each of five chapters earns one ticket and spending survives reload, warps and reclear',
      () {
        var s = start();
        final claimed = <WorldStage>{};
        while (true) {
          finish(s, path);
          final p = s.progress;
          claimed.add(s.world.stage);
          expect(p.claimedResetStages, claimed);
          expect(p.skillResetTickets, 1);
          s.continueExploring();
          s.pause();
          p.gold = 0;
          expect(s.learn(p.skills.first), isTrue);
          final before = p.skillPoints, refund = p.investedSkillPoints;
          expect(s.resetSkills(), isTrue);
          expect(p.skillPoints, before + refund);
          expect(p.skillResetTickets, 0);
          expect(p.gold, 0);
          visitHub(s);
          var saved = GameCheckpoint.capture(s)!;
          s = start(saved: GameCheckpoint.decode(saved.encode())!);
          s.completeStageIfReady();
          expect(
            s.progress.skillResetTickets,
            0,
            reason: 'reload/reclear cannot re-mint spent stage tickets',
          );
          s.continueExploring();
          if (s.world.stage != WorldStage.forest) {
            final activeStage = s.world.stage;
            visitHub(s);
            saved = GameCheckpoint.warp(s, WorldStage.forest, 'hub')!;
            final home = start(saved: saved);
            home.completeStageIfReady();
            expect(home.progress.skillResetTickets, 0);
            home.continueExploring();
            visitHub(home);
            s = start(saved: GameCheckpoint.warp(home, activeStage, 'hub')!);
            s.completeStageIfReady();
            expect(s.progress.skillResetTickets, 0);
            s.continueExploring();
          }
          if (!s.world.stage.hasNextStage) break;
          s = start(saved: GameCheckpoint.advance(s)!);
        }
        expect(claimed.length, 5);
        expect(s.progress.claimedResetStages, claimed);
        expect(s.progress.skillResetTickets, 0);
      },
    );

    test(
      '$path legacy active and archived completed scenes receive retroactive tickets exactly once',
      () {
        var s = start();
        var completed = 0;
        while (true) {
          finish(s, path);
          completed++;
          visitHub(s);
          if (!s.world.stage.hasNextStage) break;
          s = start(saved: GameCheckpoint.advance(s)!);
        }
        final legacy =
            jsonDecode(GameCheckpoint.capture(s)!.encode())
                as Map<String, dynamic>;
        (legacy['progress'] as Map).remove('skillResetRewards');
        final migrated = GameCheckpoint.decode(jsonEncode(legacy))!;
        expect(completed, 5);
        expect(migrated.progress.skillResetTickets, completed);
        expect(migrated.progress.claimedResetStages.length, completed);
        expect(
          GameCheckpoint.decode(migrated.encode())!.progress.skillResetTickets,
          completed,
        );
        final revived = start(saved: migrated);
        revived.progress.gold = 0;
        revived.learn(revived.progress.skills.first);
        expect(revived.resetSkills(), isTrue);
        expect(revived.progress.skillResetTickets, 4);
        visitHub(revived);
        final home = start(
          saved: GameCheckpoint.warp(revived, WorldStage.forest, 'hub')!,
        );
        home.completeStageIfReady();
        expect(home.progress.skillResetTickets, 4);
        expect(
          GameCheckpoint.decode(
            GameCheckpoint.capture(home)!.encode(),
          )!.progress.skillResetTickets,
          4,
        );
      },
    );
  }

  test(
    'legacy boss-only proof gets an empty persisted ledger, then real completion earns one',
    () {
      final s = start();
      s.progress.bossDefeated = true;
      final legacy =
          jsonDecode(GameCheckpoint.capture(s)!.encode())
              as Map<String, dynamic>;
      (legacy['progress'] as Map).remove('skillResetRewards');
      final migrated = GameCheckpoint.decode(jsonEncode(legacy))!;
      expect(migrated.progress.skillResetTickets, 0);
      expect(
        (migrated.data['progress'] as Map).containsKey('skillResetRewards'),
        isTrue,
      );
      expect(
        GameCheckpoint.decode(migrated.encode())!.progress.skillResetTickets,
        0,
      );
      final restored = start(saved: migrated);
      restored.cleansedSites.addAll(
        restored.world.sites.map((site) => site.id),
      );
      restored.completeStageIfReady();
      expect(restored.progress.skillResetTickets, 1);
    },
  );

  test(
    'ticket ledger validation preserves earned and spent counts without mutable aliases',
    () {
      final p = Progress();
      p.awardSkillResetTicket(WorldStage.forest);
      expect(p.awardSkillResetTicket(WorldStage.forest), isFalse);
      p.learn(p.skills.first);
      expect(p.resetSkills(), isTrue);
      final saved = p.toSave();
      final restored = Progress.fromSave(saved)!;
      expect(restored.skillResetTickets, 0);
      expect(restored.claimedResetStages, {WorldStage.forest});
      expect(() => restored.claimedResetStages.clear(), throwsUnsupportedError);
      for (final invalid in [
        null,
        {'version': 2, 'claimed': [], 'spent': 0},
        {
          'version': 1,
          'claimed': ['unknown'],
          'spent': 0,
        },
        {
          'version': 1,
          'claimed': ['forest', 'forest'],
          'spent': 0,
        },
        {
          'version': 1,
          'claimed': ['forest'],
          'spent': 2,
        },
        {
          'version': 1,
          'claimed': ['forest'],
          'spent': -1,
        },
        {
          'version': 1,
          'claimed': ['forest'],
          'spent': .5,
        },
      ]) {
        expect(
          Progress.fromSave({...saved, 'skillResetRewards': invalid}),
          isNull,
        );
      }
    },
  );

  for (final size in [const Size(320, 420), const Size(844, 390)]) {
    testWidgets(
      'ticket badge, free reset and no-ticket information fit $size at 1.3',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = start()..pause();
        final p = s.progress..gold = 0;
        p.awardSkillResetTicket(WorldStage.forest);
        p.learn(p.skills.first);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: SkillsPanel(session: s, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('초기화권 1장'), findsOneWidget);
        await tester.tap(find.byTooltip('스킬 초기화'));
        await tester.pumpAndSettle();
        expect(find.textContaining('골드는 사용하지 않습니다'), findsOneWidget);
        final confirm = find.bySemanticsLabel('초기화권 1장 · 초기화');
        expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(size.height));
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(p.skillResetTickets, 0);
        expect(p.gold, 0);
        expect(find.bySemanticsLabel('초기화권 0장'), findsOneWidget);
        expect(s.learn(p.skills.first), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            home: SkillsPanel(session: s, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('스킬 초기화'));
        await tester.pumpAndSettle();
        expect(find.text('초기화권이 없습니다'), findsOneWidget);
        final action = tester.widget<GameAction>(
          find.byWidgetPredicate(
            (w) => w is GameAction && w.label == '초기화권 1장 · 초기화',
          ),
        );
        expect(action.onTap, isNull);
        expect(p.gold, 0);
        expect(tester.takeException(), isNull);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

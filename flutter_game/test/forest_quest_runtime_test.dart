import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/forest_quest_panel.dart';
import 'package:guardian_new/forest_quest_runtime.dart';
import 'package:guardian_new/forest_quests.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/rpg_widgets.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Adventure start({GameCheckpoint? checkpoint}) {
    final s = checkpoint?.restore(GameArt()) ?? Adventure(GameArt());
    s.start(TestGame());
    addTearDown(s.dispose);
    if (checkpoint == null) {
      for (final enemy in s.mobs.toList()) {
        enemy.combatReady = false;
        enemy.removeFromParent();
      }
      s.mobs.clear();
      s.dormantEnemies.clear();
      s.enemySpacing.clear();
    }
    // Tests drive the quest runtime explicitly, never the regional pack clock.
    s.waveTime = 100000;
    return s;
  }

  void moveHero(Adventure s, ui.Offset center) {
    final body = s.hero.body.size;
    final at = s.world.spawnNear(
      center - ui.Offset(body.width / 2, body.height / 2),
      body,
      occupied: (candidate) =>
          s.mobs.any((m) => !m.isDead && candidate.overlaps(m.body)),
    );
    expect(at, isNotNull, reason: 'authored quest NPC needs a safe approach');
    s.hero.stop();
    s.hero.position.setValues(at!.dx, at.dy);
    s.hero.lastClearPosition = at;
  }

  ForestQuestNpcInfo approach(Adventure s, String key) {
    final r = s.forestQuests;
    final npc = r.npcs.firstWhere((n) => n.key == key);
    final body = s.hero.body.size;
    final at = s.world.spawnNear(
      npc.at + ui.Offset(50 - body.width / 2, -body.height / 2),
      body,
      occupied: (candidate) {
        final d = npc.at - candidate.center;
        if (d.distance > 120 || d.distance < 32) return true;
        final face = npc.at - d / d.distance * 24;
        return !s.world.clearLine(
              candidate.center,
              face,
              const ui.Size(3, 3),
            ) ||
            s.mobs.any((m) => !m.isDead && candidate.overlaps(m.body));
      },
    );
    expect(at, isNotNull, reason: 'safe person interaction: ${npc.name}');
    s.hero.stop();
    s.hero.position.setValues(at!.dx, at.dy);
    s.hero.lastClearPosition = at;
    expect(r.openNpc(npc), true, reason: npc.name);
    return npc;
  }

  List<HuntEnemy> tagged(Adventure s) =>
      s.mobs.where((m) => s.forestQuests.saveEnemyTags(m).isNotEmpty).toList();

  void beginDefense(Adventure s) {
    approach(s, 'rowen');
    expect(s.forestQuests.performAction(), true, reason: 'accept from scholar');
    expect(
      s.forestQuests.performAction(),
      true,
      reason: 'explicitly start defense',
    );
    expect(s.forestQuests.protectionActive, true);
    expect(tagged(s).length, ForestQuestProgress.threatCount);
  }

  test(
    'a structure cannot self-give a quest; a person accepts and rewards once',
    () {
      final s = start(), r = s.forestQuests;
      final altar = s.world.sites.firstWhere((site) => site.id == 'roots');
      moveHero(s, altar.at + const ui.Offset(0, 90));
      expect(
        s.cleanseNearbySite(),
        false,
        reason: 'forest objectives are accepted from named people, not wells',
      );
      expect(r.ledger['roots']!.phase, ForestQuestPhase.offered);
      expect(s.cleansedSites, isEmpty);
      approach(s, 'elin');
      expect(r.performAction(), true);
      expect(r.ledger['roots']!.phase, ForestQuestPhase.accepted);
      expect(r.performAction(), true);
      expect(r.ledger['roots']!.phase, ForestQuestPhase.ready);
      expect(
        s.cleansedSites,
        isEmpty,
        reason: 'report to the giver before awarding',
      );
      final gold = s.progress.gold;
      expect(r.performAction(), true);
      expect(s.cleansedSites, contains('roots'));
      expect(s.progress.gold, gold + forestQuest('roots')!.reward.gold);
      final paid = s.progress.gold;
      expect(r.performAction(), false);
      expect(s.progress.gold, paid);
    },
  );

  test(
    'parcel pickup survives a real checkpoint and only the recipient can turn it in',
    () {
      final s = start(), r = s.forestQuests;
      approach(s, 'noah');
      expect(r.actionEnabled, false);
      expect(
        r.performAction(),
        false,
        reason: 'recipient does not give this quest',
      );
      approach(s, 'mira');
      expect(r.performAction(), true);
      expect(r.performAction(), true);
      expect(r.ledger['moon']!.hasParcel, true);
      expect(
        r.performAction(),
        false,
        reason: 'cannot collect duplicate parcels',
      );
      final encoded = GameCheckpoint.capture(s)!.encode();
      final checkpoint = GameCheckpoint.decode(encoded);
      expect(checkpoint, isNotNull);
      final restored = start(checkpoint: checkpoint!);
      final delivery = restored.forestQuests;
      expect(delivery.ledger['moon']!.hasParcel, true);
      approach(restored, 'noah');
      expect(delivery.performAction(), true);
      expect(delivery.ledger['moon']!.phase, ForestQuestPhase.ready);
      final gold = restored.progress.gold;
      expect(delivery.performAction(), true);
      expect(restored.progress.gold, gold + forestQuest('moon')!.reward.gold);
      expect(restored.cleansedSites, contains('moon'));
      expect(delivery.performAction(), false);
    },
  );

  test(
    'finite guard enemies really damage the solid NPC; failure cleans them and retry creates only three',
    () {
      final s = start(), r = s.forestQuests;
      beginDefense(s);
      expect(r.performAction(), false);
      expect(
        tagged(s).length,
        3,
        reason: 'holding the action cannot create extra waves',
      );
      final at = r.defenderAt!, q = r.ledger['sun']!;
      expect(s.world.blocked(r.scholar!.body), true);
      moveHero(s, at + const ui.Offset(320, 80));
      final enemy = tagged(s).first;
      final foot = s.world.spawnNear(
        at + ui.Offset(48 - enemy.body.width / 2, -enemy.body.height / 2),
        enemy.body.size,
        occupied: (candidate) {
          final d = (candidate.center - at).distance;
          return d > 52 || d < 36 || candidate.overlaps(s.hero.body);
        },
      );
      expect(foot, isNotNull);
      enemy.position.setValues(foot!.dx, foot.dy);
      enemy.attackClock = 0;
      enemy.meleeWindup = .3;
      enemy.windup = .3;
      enemy.pounceGoal = s.hero.body.center;
      expect(r.updateThreat(enemy, .01), true);
      expect(enemy.meleeWindup, 0);
      expect(enemy.windup, 0);
      expect(
        enemy.pounceGoal,
        null,
        reason: 'pending hero attacks cancel on scholar handoff',
      );
      final initial = q.defenderHealth;
      for (var i = 0; i < 40 && q.defenderHealth == initial; i++) {
        enemy.update(.05);
      }
      expect(
        q.defenderHealth,
        lessThan(initial),
        reason: 'solid NPC center must not block its own near-face damage ray',
      );
      for (var i = 0; i < 5000 && q.protectionActive; i++) {
        r.tick(.05);
        enemy.update(.05);
      }
      expect(q.phase, ForestQuestPhase.failed);
      expect(q.failure, ForestQuestFailure.defenderFallen);
      expect(tagged(s), isEmpty);
      expect(s.mobs.where((m) => !m.isDead && !m.isRemoving), isEmpty);
      r.tick(1000);
      expect(tagged(s), isEmpty, reason: 'failed quests never auto-respawn');
      approach(s, 'rowen');
      final oldAttempt = q.attempt;
      expect(
        r.performAction(),
        true,
        reason: 'explicit retry starts a new finite attempt',
      );
      expect(q.attempt, oldAttempt + 1);
      expect(tagged(s).length, 3);
    },
  );

  test(
    'protection requires the timer plus real kill events, and pays once',
    () {
      final s = start(), r = s.forestQuests;
      beginDefense(s);
      for (final enemy in tagged(s)) {
        expect(s.hit(enemy, 1000000, ui.Offset.zero, hitStop: false), true);
      }
      final q = r.ledger['sun']!;
      expect(
        q.threatsRemaining,
        0,
        reason: 'Adventure hit/death hook records finite tokens',
      );
      expect(q.phase, ForestQuestPhase.accepted);
      r.tick(ForestQuestProgress.protectionDuration - .01);
      expect(q.phase, ForestQuestPhase.accepted);
      r.tick(.01);
      expect(q.phase, ForestQuestPhase.ready);
      approach(s, 'rowen');
      final gold = s.progress.gold;
      expect(r.performAction(), true);
      expect(s.progress.gold, gold + forestQuest('sun')!.reward.gold);
      expect(s.cleansedSites, contains('sun'));
      expect(r.performAction(), false);
      r.tick(1000);
      expect(tagged(s), isEmpty);
    },
  );

  test(
    'a checkpoint restores exact NPC damage, timer and unresolved threat tags without a fresh wave',
    () {
      final s = start(), r = s.forestQuests;
      beginDefense(s);
      expect(
        s.hit(tagged(s).first, 1000000, ui.Offset.zero, hitStop: false),
        true,
      );
      r.ledger.damageDefender(17.25);
      r.tick(4.5);
      final raw = GameCheckpoint.capture(s)!.encode();
      final checkpoint = GameCheckpoint.decode(raw);
      expect(checkpoint, isNotNull);
      final restored = start(checkpoint: checkpoint!);
      final q = restored.forestQuests.ledger['sun']!;
      expect(q.protectionActive, true);
      expect(q.defenderHealth, 222.75);
      expect(q.protectedFor, 4.5);
      expect(q.threatsRemaining, 2);
      expect(tagged(restored).length, 2);
      restored.forestQuests.tick(.05);
      expect(tagged(restored).length, 2);
    },
  );

  test(
    'a dormant threat keeps its token without a kill and wakes without duplicate registration',
    () {
      final s = start(), r = s.forestQuests;
      beginDefense(s);
      final enemy = tagged(s).first;
      final raw = s.saveEnemy(enemy);
      expect(raw['forestGuardToken'], isNotNull);
      r.forgetDormantEnemy(enemy);
      enemy.combatReady = false;
      enemy.encounterDormant = true;
      s.mobs.remove(enemy);
      s.enemySpacing.remove(enemy);
      enemy.removeFromParent();
      s.dormantEnemies.add(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(raw))),
      );
      expect(r.ledger['sun']!.threatsRemaining, 3);
      s.lastEnemyWake = -1;
      s.wakeEnemies();
      expect(s.dormantEnemies, isEmpty);
      expect(tagged(s).length, 3);
      expect(r.ledger['sun']!.threatsRemaining, 3);
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(320, 420),
  ]) {
    testWidgets('NPC panel centers short disabled actions at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = start();
      approach(s, 'noah');
      s.pause();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: ForestQuestPanel(runtime: s.forestQuests, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester.getRect(find.byType(FramedSurface));
      expect(surface.center.dx, closeTo(size.width / 2, 1));
      expect(surface.center.dy, closeTo(size.height / 2, 1));
      final action = find.widgetWithText(GameAction, '수락');
      expect(tester.widget<GameAction>(action).onTap, isNull);
      final label = find.descendant(of: action, matching: find.text('수락'));
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        false,
      );
      expect(tester.getRect(action).bottom, lessThan(size.height));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

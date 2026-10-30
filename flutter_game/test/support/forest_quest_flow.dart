import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/forest_quest_runtime.dart';
import 'package:guardian_new/forest_quests.dart';

/// Uses the same safe person interaction and reward paths as the game UI.
ForestQuestNpcInfo approachForestNpc(Adventure s, String key) {
  final npc = s.forestQuests.npcs.firstWhere((n) => n.key == key);
  final body = s.hero.body.size;
  final at = s.world.spawnNear(
    npc.at + Offset(50 - body.width / 2, -body.height / 2),
    body,
    occupied: (candidate) {
      final d = npc.at - candidate.center;
      if (d.distance > 120 || d.distance < 32) return true;
      return !s.world.clearLine(
        candidate.center,
        npc.at - d / d.distance * 24,
        const Size(3, 3),
      );
    },
  );
  expect(at, isNotNull, reason: 'safe interaction with ${npc.name}');
  s.hero.stop();
  s.hero.position.setValues(at!.dx, at.dy);
  s.hero.lastClearPosition = at;
  expect(s.forestQuests.openNpc(npc), true);
  return npc;
}

void completeForestQuest(Adventure s, String id) {
  for (final enemy in s.mobs.toList()) {
    enemy.removeFromParent();
  }
  s.mobs.clear();
  s.dormantEnemies.clear();
  s.enemySpacing.clear();
  final r = s.forestQuests;
  approachForestNpc(s, switch (id) {
    'roots' => 'elin',
    'moon' => 'mira',
    _ => 'rowen',
  });
  if (r.ledger[id]!.phase == ForestQuestPhase.offered) {
    expect(r.performAction(), true, reason: '$id accepted from a person');
  }
  expect(r.performAction(), true, reason: '$id objective starts');
  if (id == 'moon') {
    approachForestNpc(s, 'noah');
    expect(r.performAction(), true, reason: 'parcel delivered to recipient');
  } else if (id == 'sun') {
    final threats = s.mobs.where((m) => r.saveEnemyTags(m).isNotEmpty).toList();
    expect(threats, hasLength(3));
    for (final enemy in threats) {
      expect(s.hit(enemy, 1000000, Offset.zero, hitStop: false), true);
    }
    r.tick(ForestQuestProgress.protectionDuration);
    approachForestNpc(s, 'rowen');
  }
  expect(r.ledger[id]!.phase, ForestQuestPhase.ready);
  expect(r.performAction(), true, reason: '$id reward claimed');
  expect(s.cleansedSites, contains(id));
  expect(r.performAction(), false, reason: '$id never rewards twice');
}

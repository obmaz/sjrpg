import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/world_model.dart' show WorldStage;

import 'support/sorceress_fixture.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure mage() {
    final s = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage))
      ..start(TestGame());
    s.progress.level = 100;
    s.progress.skillPoints = 1000;
    for (final id in [
      'frozenArmor',
      'energyShield',
      'enchant',
      'thunderStorm',
      'blaze',
      'blizzard',
    ]) {
      trainSkill(s.progress, id, 3);
    }
    addTearDown(s.dispose);
    return s;
  }

  void buffs(Adventure s) {
    for (final id in [
      'frozenArmor',
      'energyShield',
      'enchant',
      'thunderStorm',
    ]) {
      final skill = s.progress.skills.firstWhere((v) => v.id == id);
      expect(
        s.hero.sorceressCombat.defenses.activate(
          id,
          s.progress.sorceressSpell(skill),
        ),
        true,
      );
    }
  }

  test(
    'long buffs, shared casting and animation lock roundtrip without refresh',
    () {
      final s = mage();
      buffs(s);
      s.hero.sorceressCombat.sharedDelay = 1.7;
      s.hero.castLock = .41;
      s.hero.sorceressCombat.defenses.update(.23);
      final before = s.hero.sorceressCombat.defenses.captureState();
      final cp = GameCheckpoint.capture(s);
      expect(cp, isNotNull);
      final restored = cp!.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.hero.sorceressCombat.defenses.captureState(), before);
      expect(restored.progress.armor, s.progress.armor);
      expect(restored.hero.sorceressCombat.sharedDelay, 1.7);
      expect(restored.hero.castLock, .41);
      expect(restored.hero.sorceressCombat.defenses.armorTime, greaterThan(60));
    },
  );
  test(
    'refunding a timed spell preserves paid delay and a valid checkpoint',
    () {
      final s = mage();
      s.progress.awardSkillResetTicket(WorldStage.forest);
      expect(s.progress.selectSkill('blizzard'), true);
      s.progress.energy = s.progress.maxEnergy;
      s.hero.skill();
      expect(s.hero.cooldowns['blizzard'], 1.8);
      expect(GameCheckpoint.capture(s), isNotNull);
      expect(s.resetSkills(), true);
      expect(s.progress.rank('blizzard'), 0);
      final cp = GameCheckpoint.capture(s);
      expect(cp, isNotNull);
      final restored = cp!.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.hero.cooldowns['blizzard'], 1.8);
      expect(restored.hero.sorceressCombat.sharedDelay, 1.8);
      expect(restored.progress.rank('blizzard'), 0);
      expect(restored.hero.sorceressCombat.defenses.hasBuffs, false);
    },
  );
  test('malformed or overlong defensive and shared timers are rejected', () {
    final s = mage();
    buffs(s);
    final cp = GameCheckpoint.capture(s)!;
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (d) => (d['sorceress'] as Map)['sharedDelay'] = 1.81,
      (d) =>
          ((d['sorceress'] as Map)['defenses']
                  as Map)['buffs'][0]['remaining'] =
              1e8,
      (d) => (d['castLock'] = 6),
      (d) => (d['sorceress'] as Map)['blazeTime'] = 1e6,
    ]) {
      final d = jsonDecode(cp.encode()) as Map<String, dynamic>;
      mutate(d);
      expect(GameCheckpoint.decode(jsonEncode(d)), isNull);
    }
  });
  test('Blaze rank and remaining lifetime survive normal continue', () {
    final s = mage();
    s.progress.selectedSkill = 'blaze';
    s.progress.energy = s.progress.maxEnergy;
    s.hero.skill();
    s.hero.sorceressCombat.update(.2);
    final before = s.hero.sorceressCombat.captureState();
    expect(before['blazeTime'], greaterThan(0));
    final cp = GameCheckpoint.capture(s);
    expect(cp, isNotNull);
    final restored = cp!.restore(GameArt());
    addTearDown(restored.dispose);
    expect(
      restored.hero.sorceressCombat.captureState()['blazeTime'],
      before['blazeTime'],
    );
    expect(restored.hero.sorceressCombat.captureState()['blazeRank'], 3);
  });
  test(
    'death retry removes all Sorceress buffs instead of granting them again',
    () {
      final s = mage();
      buffs(s);
      s.hero.sorceressCombat.sharedDelay = 1;
      s.hurtHero(1e7);
      expect(s.defeated, true);
      expect(s.hero.sorceressCombat.defenses.hasBuffs, false);
      final cp = GameCheckpoint.capture(s, forDefeat: true);
      expect(cp, isNotNull);
      final restored = cp!.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.hero.sorceressCombat.defenses.hasBuffs, false);
      expect(restored.hero.sorceressCombat.sharedDelay, 0);
      expect(restored.hero.castLock, 0);
    },
  );
  test('chapter transition carries long buffs and the shared timer once', () {
    final s = mage();
    buffs(s);
    s.hero.sorceressCombat.sharedDelay = 1.2;
    s.cleansedSites.addAll(s.world.sites.map((v) => v.id));
    s.progress.kills = 1000;
    s.progress.bossDefeated = true;
    expect(s.stageCleared, true);
    final next = GameCheckpoint.advance(s);
    expect(next, isNotNull);
    final restored = next!.restore(GameArt());
    addTearDown(restored.dispose);
    expect(
      restored.hero.sorceressCombat.defenses.captureState(),
      s.hero.sorceressCombat.defenses.captureState(),
    );
    expect(restored.hero.sorceressCombat.sharedDelay, 1.2);
  });
}

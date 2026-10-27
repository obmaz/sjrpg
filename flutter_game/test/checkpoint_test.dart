import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'checkpoint preserves independent equipment, skills, loot and exploration',
    () {
      final s = Adventure(GameArt(), heroClass: HeroClass.mage);
      s.start(TestGame());
      addTearDown(s.dispose);
      s.progress.gainXp(300);
      s.syncLife();
      s.progress.hp = 37;
      s.progress.gold = 345;
      s.progress.learn(
        mageSkills.firstWhere((skill) => skill.id == 'iceArmor'),
      );
      final gear = s.progress.createGear(
        gearById('frostwand'),
        rarity: Rarity.rare,
        power: 8,
        vitality: 15,
        focus: 9,
      );
      s.progress.collect(gear);
      s.progress.equip(gear);
      s.hero.cooldowns['frostNova'] = 3;
      s.hero.armorTime = 5;
      for (final memory in stageMemories) {
        final at = stageChests[memory.chest];
        s.hero.position.setValues(at.dx, at.dy);
        s.openChest();
      }
      s.elapsed = 68.25;
      final snapshot = GameCheckpoint.capture(s)!;
      final restored = GameCheckpoint.decode(
        snapshot.encode(),
      )!.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.progress.toSave(), s.progress.toSave());
      expect(identical(restored.progress.weapon, gear), false);
      expect(restored.progress.hp, 37);
      expect(restored.openedChests, s.openedChests);
      expect(restored.memoryRewarded, true);
      expect(restored.elapsed, 68.25);
      expect(restored.hero.cooldowns['frostNova'], 3);
      expect(restored.hero.armorTime, 5);
      expect(s.loot, isNotEmpty);
      expect(
        restored.loot.map((loot) => loot.item.toSave()).toList(),
        s.loot.map((loot) => loot.item.toSave()).toList(),
      );
      expect(
        restored.loot
            .map((loot) => (loot.position.x, loot.position.y))
            .toList(),
        s.loot.map((loot) => (loot.position.x, loot.position.y)).toList(),
      );
      expect(restored.hero.position.x, s.hero.position.x);
      expect(restored.hero.position.y, s.hero.position.y);
      expect(restored.world.blocked(restored.hero.body), false);
      final created = restored.progress.createGear(gearById('wand'));
      expect(
        created.serial,
        greaterThan(
          restored.loot
              .map((g) => g.item.serial)
              .reduce((a, b) => a > b ? a : b),
        ),
      );
      restored.progress.gold = 1;
      expect(s.progress.gold, isNot(1));
    },
  );
  test('a wounded boss resumes with the same health without a duplicate', () {
    final s = Adventure(GameArt());
    s.start(TestGame());
    addTearDown(s.dispose);
    s.cleansedSites.addAll(questSites.map((q) => q.id));
    s.progress.kills = stageKillGoal;
    s.tick(.05);
    final boss = s.mobs.firstWhere((m) => m.boss);
    s.hit(boss, 200, const Offset(0, 0));
    final restored = GameCheckpoint.capture(s)!.restore(GameArt());
    addTearDown(restored.dispose);
    restored.start(TestGame());
    restored.tick(.05);
    final bosses = restored.mobs.where((m) => m.boss).toList();
    expect(bosses.length, 1);
    expect(bosses.single.life.value, boss.life.value);
    expect(bosses.single.life.max, boss.life.max);
    expect(restored.progress.kills, stageKillGoal);
  });
  test(
    'broken, unknown and impossible save data cannot block a fresh adventure',
    () {
      final s = Adventure(GameArt());
      s.start(TestGame());
      addTearDown(s.dispose);
      expect(GameCheckpoint.decode('{broken'), null);
      final valid = GameCheckpoint.capture(s)!.encode();
      for (final edit in <void Function(Map<String, dynamic>)>[
        (d) => d['version'] = 99,
        (d) => d['x'] = -1,
        (d) => d['chests'] = [999],
        (d) => d['progress']['level'] = 0,
        (d) => d['progress']['selectedSkill'] = 'missing',
        (d) => d['progress']['inventory'][0]['base'] = 'missing',
        (d) => d['progress']['inventory'].add(d['progress']['inventory'][0]),
        (d) => d['cooldowns'] = {'missing': 3},
      ]) {
        final data = jsonDecode(valid) as Map<String, dynamic>;
        edit(data);
        expect(GameCheckpoint.decode(jsonEncode(data)), null);
      }
      s.progress.hp = 0;
      expect(GameCheckpoint.capture(s), null);
    },
  );
  test(
    'restoration resolves a blocked position and resumes a cleared forest without a new boss',
    () {
      final s = Adventure(GameArt());
      s.start(TestGame());
      addTearDown(s.dispose);
      s.progress.bossDefeated = true;
      s.progress.kills = 130;
      final raw =
          jsonDecode(GameCheckpoint.capture(s)!.encode())
              as Map<String, dynamic>;
      raw['x'] = 5680;
      raw['y'] = 1700;
      final restored = GameCheckpoint.decode(
        jsonEncode(raw),
      )!.restore(GameArt());
      addTearDown(restored.dispose);
      restored.start(TestGame());
      restored.tick(.05);
      expect(restored.bossSummoned, true);
      expect(restored.mobs.where((m) => m.boss), isEmpty);
      expect(restored.world.blocked(restored.hero.body), false);
      expect(restored.progress.bossDefeated, true);
    },
  );
}

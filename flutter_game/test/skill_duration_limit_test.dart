import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session(HeroClass hero) {
    final s = inCombatField(Adventure(GameArt(), heroClass: hero))
      ..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    s.waveTime = 10000;
    while (s.progress.level < 100) {
      s.progress.gainXp(s.progress.nextLevelXp - s.progress.xp);
    }
    s.syncLife();
    return s;
  }

  void train(Adventure s, String id, [int rank = 1]) {
    final def = s.progress.skills.firstWhere((d) => d.id == id);
    for (final parent in def.requires.entries) {
      if (s.progress.rank(parent.key) < parent.value) {
        train(s, parent.key, parent.value);
      }
    }
    while (s.progress.rank(id) < rank) {
      expect(s.learn(def), true, reason: id);
    }
  }

  void advance(Adventure s, double time) {
    var left = time;
    while (left > .000001) {
      final dt = left < .05 ? left : .05;
      s.tick(dt);
      s.hero.update(dt);
      left -= dt;
    }
  }

  for (final id in [
    'frozenArmor',
    'shiverArmor',
    'chillingArmor',
    'energyShield',
  ]) {
    for (final rank in [1, 20]) {
      test(
        'D2 $id rank$rank keeps its source lifetime beyond zero cooldown and pauses',
        () {
          final s = session(HeroClass.mage), p = s.progress;
          train(s, id, rank);
          expect(p.selectSkill(id), true);
          p.energy = p.maxEnergy;
          final def = p.activeSkill, stats = p.sorceressSpell(def);
          s.hero.skill();
          final defenses = s.hero.sorceressCombat.defenses;
          double remaining() => id == 'energyShield'
              ? defenses.energyShieldTime
              : defenses.armorTime;
          expect(remaining(), stats.duration);
          expect(remaining(), greaterThan(100));
          expect(s.hero.cooldowns[id] ?? 0, 0);
          s.pause();
          advance(s, .1);
          expect(remaining(), stats.duration);
          s.resume();
          advance(s, .5);
          expect(remaining(), closeTo(stats.duration - .5, .000001));
          advance(s, remaining() + .1);
          expect(remaining(), 0);
          if (id != 'energyShield') expect(p.sorceressArmorMultiplier, 1);
        },
      );
    }
  }
  for (final id in ['shout', 'battleOrders', 'battleCommand']) {
    test(
      'D2 $id is a refreshable source-duration buff beyond its cooldown',
      () {
        final s = session(HeroClass.warrior), p = s.progress;
        train(s, id);
        expect(p.selectSkill(id), true);
        p.energy = p.maxEnergy;
        final def = p.activeSkill, duration = p.barbarianBuffDuration(id);
        final before = jsonEncode(p.toSave());
        final preview = previewSkill(
          p,
          def,
        ).firstWhere((r) => r.label == '지속 시간');
        expect(preview.current, duration);
        expect(jsonEncode(p.toSave()), before);
        s.hero.skill();
        final cooldown = s.hero.cooldowns[id]!;
        expect(duration, greaterThan(cooldown));
        bool active() => id == 'shout'
            ? p.activeArmorMultiplier > 1
            : id == 'battleOrders'
            ? p.activeLifeMultiplier > 1
            : p.activeSkillBonus == 1;
        expect(active(), true);
        s.pause();
        advance(s, .1);
        expect(active(), true);
        s.resume();
        advance(s, cooldown + .01);
        expect(active(), true);
        expect(s.hero.cooldowns[id], 0);
        advance(s, duration - cooldown + .1);
        expect(active(), false);
      },
    );
  }
  test('shout changes real armor mitigation and Berserk removes defense', () {
    final s = session(HeroClass.warrior), p = s.progress;
    train(s, 'shout');
    p.selectSkill('shout');
    p.energy = p.maxEnergy;
    final ordinary = p.mitigate(100), baseArmor = p.armor;
    s.hero.skill();
    expect(p.armor, greaterThan(baseArmor));
    s.hero.invulnerable = 0;
    final before = p.hp;
    s.hurtHero(100);
    expect(before - p.hp, closeTo(p.mitigate(100), .000001));
    expect(before - p.hp, lessThan(ordinary));
    p.berserkActive = true;
    expect(p.armor, 0);
    expect(p.mitigate(100), 100);
    expect(p.mitigate(100, protection: 10), 25);
  });
  test(
    'Mage source-duration preview matches actual current and next casts without spend',
    () {
      final s = session(HeroClass.mage), p = s.progress;
      train(s, 'frozenArmor', 2);
      p.selectSkill('frozenArmor');
      final def = p.activeSkill, before = jsonEncode(p.toSave());
      final row = previewSkill(p, def).firstWhere((r) => r.label == '효과 지속');
      expect(jsonEncode(p.toSave()), before);
      p.energy = p.maxEnergy;
      s.hero.skill();
      expect(s.hero.sorceressCombat.defenses.armorTime, row.current);
      expect(p.learn(def), true);
      advance(s, p.skillMotionTime(def) + .1);
      p.energy = p.maxEnergy;
      s.hero.skill();
      expect(s.hero.sorceressCombat.defenses.armorTime, row.next);
    },
  );

  test(
    'saved long armor and shield preserve remaining lifetimes, not a cooldown clamp',
    () {
      final s = session(HeroClass.mage), p = s.progress;
      train(s, 'frozenArmor', 3);
      train(s, 'energyShield', 2);
      for (final id in ['frozenArmor', 'energyShield']) {
        expect(p.selectSkill(id), true);
        p.energy = p.maxEnergy;
        s.hero.skill();
        advance(s, p.skillMotionTime(p.activeSkill) + .1);
      }
      final defenses = s.hero.sorceressCombat.defenses;
      final armor = defenses.armorTime, shield = defenses.energyShieldTime;
      expect(armor, greaterThan(100));
      expect(shield, greaterThan(100));
      final cp = GameCheckpoint.capture(s)!;
      final read = GameCheckpoint.decode(cp.encode())!;
      final restored = read.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.hero.sorceressCombat.defenses.armorTime, armor);
      expect(restored.hero.sorceressCombat.defenses.energyShieldTime, shield);
      expect(GameCheckpoint.decode(read.encode())!.encode(), read.encode());
      final invalid = jsonDecode(cp.encode()) as Map<String, dynamic>;
      final buffs = invalid['sorceress']['defenses']['buffs'] as List;
      final buff = buffs.first as Map;
      buff['remaining'] =
          p
              .sorceressSpell(p.skills.firstWhere((d) => d.id == buff['id']))
              .duration +
          1;
      expect(GameCheckpoint.decode(jsonEncode(invalid)), isNull);
    },
  );

  test(
    'Frost Nova source chill duration survives its original zero cast delay',
    () {
      final s = session(HeroClass.mage);
      train(s, 'frostNova', 20);
      s.progress.selectSkill('frostNova');
      s.progress.energy = s.progress.maxEnergy;
      final mob = s.spawnEnemy(
        'goblin',
        s.hero.body.center + const Offset(60, 0),
      )!..life.initial(1000);
      s.hero.skill();
      expect(mob.slow, closeTo(s.progress.novaSlowDuration, .000001));
      expect(mob.slow, 27);
      expect(s.hero.cooldowns['frostNova'] ?? 0, 0);
    },
  );

  test(
    'a pre-Sorceress-tree Mage save is rejected instead of converting removed armor',
    () {
      final s = session(HeroClass.mage);
      final data =
          jsonDecode(GameCheckpoint.capture(s)!.encode())
              as Map<String, dynamic>;
      (data['progress'] as Map).remove('sorceressTreeVersion');
      data['cooldowns'] = {'iceArmor': 1.0};
      data['armor'] = 20.0;
      expect(GameCheckpoint.decode(jsonEncode(data)), isNull);
    },
  );
}

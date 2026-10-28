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

  for (var rank = 1; rank <= 5; rank++) {
    test('iceArmor rank$rank expires before its assigned cooldown', () {
      final s = session(HeroClass.mage);
      train(s, 'iceArmor', rank);
      s.progress.selectSkill('iceArmor');
      s.progress.energy = s.progress.maxEnergy;
      final def = s.progress.activeSkill;
      s.hero.skill();
      final duration = s.hero.armorTime, cooldown = s.hero.cooldowns[def.id]!;
      expect(duration, greaterThan(0));
      expect(duration, lessThanOrEqualTo(cooldown * .9 + .000001));
      expect(cooldown, s.progress.skillCooldown(def));
      s.pause();
      advance(s, .1);
      expect(s.hero.armorTime, duration);
      s.resume();
      advance(s, duration + .01);
      expect(s.hero.armorTime, 0);
      expect(s.hero.cooldowns[def.id], greaterThan(0));
    });
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
    'Mage duration preview matches actual current and next casts without spend',
    () {
      final s = session(HeroClass.mage), p = s.progress;
      train(s, 'iceArmor', 2);
      p.selectSkill('iceArmor');
      final def = p.activeSkill, before = jsonEncode(p.toSave());
      final row = previewSkill(p, def).firstWhere((r) => r.label == '보호 지속');
      expect(jsonEncode(p.toSave()), before);
      p.energy = p.maxEnergy;
      s.hero.skill();
      expect(s.hero.armorTime, row.current);
      expect(p.learn(def), true);
      s.hero.cooldowns.clear();
      s.hero.castLock = 0;
      p.energy = p.maxEnergy;
      s.hero.skill();
      expect(s.hero.armorTime, row.next);
    },
  );
  test(
    'Mage oversized saved armor is limited by remaining cooldown idempotently',
    () {
      final s = session(HeroClass.mage);
      train(s, 'iceArmor', 5);
      s.progress.selectSkill('iceArmor');
      s.hero.cooldowns['iceArmor'] = 1;
      s.hero.armorTime = 60;
      final save = GameCheckpoint.capture(s)!;
      final read = GameCheckpoint.decode(save.encode())!;
      final restored = read.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.hero.armorTime, .9);
      expect(restored.hero.cooldowns, s.hero.cooldowns);
      expect(GameCheckpoint.decode(read.encode())!.encode(), read.encode());
      final ready = Map<String, dynamic>.from(save.data)
        ..['cooldowns'] = <String, double>{};
      expect(GameCheckpoint.decode(jsonEncode(ready))!.data['armor'], 0);
    },
  );
  test('frost nova slow ends before the rank-five cooldown', () {
    final s = session(HeroClass.mage);
    s.progress.ranks['frostNova'] = 5;
    s.progress.selectSkill('frostNova');
    s.progress.energy = s.progress.maxEnergy;
    final mob = s.spawnEnemy('goblin', const Offset(6050, 4200))!
      ..life.initial(1000);
    s.hero.skill();
    expect(mob.slow, greaterThan(0));
    expect(mob.slow, lessThan(s.hero.cooldowns['frostNova']!));
    expect(mob.slow, closeTo(s.progress.novaSlowDuration, .000001));
  });
  test('valid elapsed buffs survive save and legacy cooldown conversion', () {
    final s = session(HeroClass.mage);
    s.progress.ranks['iceArmor'] = 3;
    s.progress.selectSkill('iceArmor');
    s.progress.energy = s.progress.maxEnergy;
    s.hero.skill();
    for (var i = 0; i < 20; i++) {
      s.hero.update(.05);
    }
    final save = GameCheckpoint.capture(s)!;
    expect(
      GameCheckpoint.decode(save.encode())!.data['armor'],
      s.hero.armorTime,
    );
    final data = jsonDecode(save.encode()) as Map<String, dynamic>;
    data['balance'] = 2;
    data['cooldowns']['iceArmor'] = 1.0;
    data['armor'] = 20.0;
    final migrated = GameCheckpoint.decode(jsonEncode(data))!;
    expect(migrated.data['cooldowns']['iceArmor'], closeTo(.9, .000001));
    expect(migrated.data['armor'], closeTo(.81, .000001));
  });
}

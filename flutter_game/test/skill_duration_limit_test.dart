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
  Adventure session(HeroClass heroClass) {
    final s = Adventure(GameArt(), heroClass: heroClass)..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    s.hero.position.setValues(6000, 4200);
    s.progress.gainXp(8000);
    return s;
  }

  for (final id in ['warcry', 'frenzy', 'iceArmor']) {
    for (var rank = 1; rank <= 5; rank++) {
      test('$id rank $rank expires before its actual assigned cooldown', () {
        final s = session(
          id == 'iceArmor' ? HeroClass.mage : HeroClass.warrior,
        );
        s.progress.ranks[id] = rank;
        if (id == 'warcry') s.progress.ranks['battleVigor'] = 5;
        s.progress.selectSkill(id);
        s.progress.energy = s.progress.maxEnergy;
        final def = s.progress.skills.firstWhere((skill) => skill.id == id);
        s.hero.skill();
        final duration = id == 'frenzy' ? s.hero.frenzyTime : s.hero.armorTime;
        final cooldown = s.hero.cooldowns[id]!;
        expect(duration, greaterThan(0));
        expect(duration, lessThan(cooldown));
        expect(duration, lessThanOrEqualTo(cooldown * .9 + .000001));
        expect(cooldown, s.progress.skillCooldown(def));
        s.pause();
        s.hero.update(.05);
        expect(id == 'frenzy' ? s.hero.frenzyTime : s.hero.armorTime, duration);
        s.resume();
        for (var t = 0.0; t <= duration; t += .05) {
          s.hero.update(.05);
        }
        expect(id == 'frenzy' ? s.hero.frenzyTime : s.hero.armorTime, 0);
        expect(s.hero.cooldowns[id], greaterThan(0));
      });
    }
  }
  test('BattleVigor reduces real incoming damage only during warcry', () {
    final s = session(HeroClass.warrior);
    s.progress.selectSkill('warcry');
    double incoming(int rank, {required bool protected}) {
      s.progress.ranks['battleVigor'] = rank;
      s.hero.armorTime = 0;
      s.hero.invulnerable = 0;
      s.progress.hp = s.progress.maxHp;
      s.syncLife();
      if (protected) {
        s.hero.cooldowns.remove('warcry');
        s.progress.energy = s.progress.maxEnergy;
        s.hero.skill();
        expect(s.hero.armorTime, greaterThan(0));
      }
      final hp = s.progress.hp;
      s.hurtHero(100);
      return hp - s.progress.hp;
    }

    final ordinary = incoming(0, protected: false);
    final warcry = incoming(0, protected: true);
    for (var rank = 1; rank <= 5; rank++) {
      expect(incoming(rank, protected: false), closeTo(ordinary, .000001));
      expect(
        incoming(rank, protected: true),
        closeTo(warcry - ordinary * .01 * rank, .000001),
      );
    }
    for (var t = 0.0; t <= s.progress.warcryDuration; t += .05) {
      s.hero.update(.05);
    }
    expect(s.hero.armorTime, 0);
    s.hero.invulnerable = 0;
    final hp = s.progress.hp;
    s.hurtHero(100);
    expect(hp - s.progress.hp, closeTo(ordinary, .000001));
  });
  test(
    'BattleVigor preview and learned ranks share HP and protection benefits',
    () {
      final s = session(HeroClass.warrior), p = s.progress;
      final def = p.skills.firstWhere((d) => d.id == 'battleVigor');
      final hp = p.maxHp;
      final duration = p.warcryDuration;
      final cooldown = p.skillCooldown(p.activeSkill);
      final protection = p.skillProtection('warcry');
      for (var rank = 0; rank < 5; rank++) {
        final before = jsonEncode(p.toSave());
        final preview = previewSkill(p, def);
        expect(jsonEncode(p.toSave()), before);
        final health = preview.firstWhere((row) => row.label == '최대 생명');
        final guard = preview.firstWhere((row) => row.label == '함성 피해 감소');
        expect(health.current, hp + rank * 8);
        expect(health.next, hp + (rank + 1) * 8);
        expect(
          guard.current,
          closeTo((protection + rank * .01) * 100, .000001),
        );
        expect(
          guard.next,
          closeTo((protection + (rank + 1) * .01) * 100, .000001),
        );
        final points = p.skillPoints;
        expect(p.learn(def), true);
        expect(p.skillPoints, points - 1);
        expect(p.maxHp, health.next);
        expect(p.skillProtection('warcry') * 100, closeTo(guard.next, .000001));
        expect(p.warcryDuration, duration);
        expect(p.skillCooldown(p.activeSkill), cooldown);
      }
      final restored = Progress.fromSave(p.toSave())!;
      expect(restored.skillProtection('warcry'), p.skillProtection('warcry'));
      expect(restored.maxHp, p.maxHp);
    },
  );
  test('maximum protection still respects the existing mitigation cap', () {
    final s = session(HeroClass.warrior), p = s.progress;
    p.ranks.addAll({'warcry': 5, 'battleVigor': 5, 'unyieldingOath': 5});
    p.selectSkill('warcry');
    p.energy = p.maxEnergy;
    s.hero.skill();
    expect(s.hero.protection, closeTo(.525, .000001));
    final ordinary = p.mitigate(100);
    s.hero.invulnerable = 0;
    p.hp = p.maxHp;
    s.syncLife();
    final hp = p.hp;
    s.hurtHero(100);
    expect(hp - p.hp, closeTo(ordinary * .475, .000001));
    expect(p.mitigate(100, protection: 10), closeTo(ordinary * .25, .000001));
  });
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
  test(
    'duration preview matches actual current and next casts without spending',
    () {
      for (final id in ['warcry', 'frenzy', 'iceArmor']) {
        final s = session(
          id == 'iceArmor' ? HeroClass.mage : HeroClass.warrior,
        );
        s.progress.ranks[id] = 2;
        s.progress.selectSkill(id);
        final def = s.progress.skills.firstWhere((skill) => skill.id == id);
        final before = jsonEncode(s.progress.toSave());
        final row = previewSkill(
          s.progress,
          def,
        ).firstWhere((r) => r.suffix == '초' && r.label.contains('지속'));
        expect(jsonEncode(s.progress.toSave()), before);
        s.progress.energy = s.progress.maxEnergy;
        s.hero.skill();
        expect(
          row.current,
          id == 'frenzy' ? s.hero.frenzyTime : s.hero.armorTime,
        );
        s.progress.ranks[id] = 3;
        s.hero.cooldowns.clear();
        s.hero.castLock = 0;
        s.progress.energy = s.progress.maxEnergy;
        s.hero.skill();
        expect(row.next, id == 'frenzy' ? s.hero.frenzyTime : s.hero.armorTime);
      }
    },
  );
  test('old save effects are limited by their own remaining cooldown', () {
    final s = session(HeroClass.warrior);
    s.progress.ranks.addAll({'warcry': 5, 'frenzy': 5});
    s.hero.cooldowns.addAll({'warcry': 1, 'frenzy': 2});
    s.hero.armorTime = 60;
    s.hero.frenzyTime = 60;
    final save = GameCheckpoint.capture(s)!;
    final read = GameCheckpoint.decode(save.encode())!;
    final restored = read.restore(GameArt());
    addTearDown(restored.dispose);
    expect(restored.hero.armorTime, .9);
    expect(restored.hero.frenzyTime, 1.8);
    expect(restored.progress.toSave(), s.progress.toSave());
    expect(restored.hero.cooldowns, s.hero.cooldowns);
    expect(GameCheckpoint.decode(read.encode())!.encode(), read.encode());
    final ready = Map<String, dynamic>.from(save.data)
      ..['cooldowns'] = <String, double>{};
    final normalized = GameCheckpoint.decode(jsonEncode(ready))!;
    expect(normalized.data['armor'], 0);
    expect(normalized.data['frenzy'], 0);
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
    expect(migrated.data['cooldowns']['iceArmor'], closeTo(.7, .000001));
    expect(migrated.data['armor'], closeTo(.63, .000001));
  });
}

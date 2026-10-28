import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';

void main() {
  for (final hero in HeroClass.values) {
    test('$hero previews never spend and match subsequently learned ranks', () {
      for (final skill
          in hero == HeroClass.warrior ? allWarriorSkills : mageSkills) {
        final p = Progress(heroClass: hero);
        while (p.level < 100) {
          p.gainXp(p.nextLevelXp - p.xp);
        }
        for (final entry in p.skills) {
          p.ranks[entry.id] = 1;
        }
        p.inventory.first.locked = true;
        final before = jsonEncode(p.toSave());
        final rows = previewSkill(p, skill);
        expect(rows, isNotEmpty, reason: skill.id);
        expect(jsonEncode(p.toSave()), before);
        expect(p.learn(skill), true, reason: skill.id);
        expect(
          previewSkill(p, skill).map((row) => row.current),
          rows.map((row) => row.next),
          reason: skill.id,
        );
        expect(p.inventory.first.locked, true);
      }
    });
  }
  test('locked ranks can be inspected; max ranks never overflow or spend', () {
    final p = Progress(heroClass: HeroClass.mage);
    final meteor = p.skills.firstWhere((s) => s.id == 'meteor');
    final points = p.skillPoints;
    expect(p.canLearn(meteor), false);
    final row = previewSkill(p, meteor).first;
    expect(row.current, 0);
    expect(row.next, greaterThan(0));
    expect(p.rank('meteor'), 0);
    expect(p.skillPoints, points);
    for (final hero in HeroClass.values) {
      final maxed = Progress(heroClass: hero)..level = 100;
      for (final skill in maxed.skills) {
        maxed.ranks[skill.id] = skill.rankLimit;
      }
      final before = jsonEncode(maxed.toSave());
      for (final skill in maxed.skills) {
        expect(
          previewSkill(maxed, skill).every((row) => row.current == row.next),
          true,
          reason: skill.id,
        );
        expect(maxed.canLearn(skill), false);
      }
      expect(jsonEncode(maxed.toSave()), before);
    }
    p.ranks['meteor'] = meteor.rankLimit;
    expect(
      p.skillDamage(meteor, atRank: 99),
      p.skillDamage(meteor, atRank: 20),
    );
    expect(p.skillDamage(meteor, atRank: -1), 0);
    expect(p.skillPoints, points);
  });
  test(
    'spell previews use original spell damage, while gear improves the weapon attack',
    () {
      final p = Progress(heroClass: HeroClass.mage);
      while (p.level < 100) {
        p.gainXp(p.nextLevelXp - p.xp);
      }
      for (final skill in mageSkills) {
        p.ranks[skill.id] = 1;
      }
      final fireball = mageSkills.firstWhere((s) => s.id == 'fireball');
      final staff = sorceressExtraSkills.single;
      final spellDamage = p.skillDamage(fireball);
      final staffDamage = p.skillDamage(staff);
      final weapon = Gear(
        20,
        gearById('frostwand'),
        rarity: Rarity.rare,
        power: 7,
      );
      p.inventory.add(weapon);
      expect(p.equip(weapon), true);
      expect(p.skillDamage(fireball), spellDamage);
      expect(p.skillDamage(staff), greaterThan(staffDamage));
      p.ranks['fireMastery'] = 2;
      final stats = p.sorceressSpell(fireball);
      final before = previewSkill(p, fireball);
      expect(
        before.firstWhere((r) => r.label == '1회 최소 피해').current,
        stats.minDamage,
      );
      expect(
        before.firstWhere((r) => r.label == '1회 최대 피해').current,
        stats.maxDamage,
      );
      expect(p.skillDamage(fireball), greaterThan(spellDamage));
      expect(
        previewSkill(p, staff).firstWhere((r) => r.label == '기본 1타 피해').current,
        p.skillDamage(staff),
      );
      expect(p.learn(fireball), true);
      expect(
        previewSkill(p, fireball).map((r) => r.current),
        before.map((r) => r.next),
      );
      final warrior = Progress();
      expect(previewSkill(warrior, fireball), isEmpty);
      expect(warrior.skillDamage(fireball), 0);
    },
  );
}

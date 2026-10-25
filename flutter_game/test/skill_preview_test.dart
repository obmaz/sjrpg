import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';

void main() {
  for (final hero in HeroClass.values) {
    test('$hero previews never spend and match subsequently learned ranks', () {
      for (final skill
          in hero == HeroClass.warrior ? warriorSkills : mageSkills) {
        final p = Progress(heroClass: hero)..gainXp(5000);
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
    final row = previewSkill(p, meteor).single;
    expect(row.current, 0);
    expect(row.next, greaterThan(0));
    expect(p.rank('meteor'), 0);
    expect(p.skillPoints, points);
    for (final skill in p.skills) {
      p.ranks[skill.id] = SkillDef.maxRank;
    }
    for (final skill in p.skills) {
      expect(
        previewSkill(p, skill).every((row) => row.current == row.next),
        true,
        reason: skill.id,
      );
    }
    expect(p.skillDamage(meteor, atRank: 99), p.skillDamage(meteor, atRank: 5));
    expect(p.skillDamage(meteor, atRank: -1), 0);
    expect(p.skillPoints, points);
  });
  test('damage predictions include equipped gear and elemental mastery', () {
    final p = Progress(heroClass: HeroClass.mage)..gainXp(5000);
    final ice = Gear(20, gearById('frostwand'), rarity: Rarity.rare, power: 7);
    p.inventory.add(ice);
    expect(p.equip(ice), true);
    p.ranks['coldMastery'] = 2;
    final nova = p.skills.firstWhere((s) => s.id == 'frostNova');
    final before = previewSkill(p, nova).single;
    expect(before.current, p.skillDamage(nova));
    expect(before.current, greaterThan(p.swordDamage * 1.4));
    expect(previewSkill(p, p.skills.first).single.current, p.basicDamage);
    expect(p.learn(nova), true);
    expect(p.skillDamage(nova), before.next);
    final warrior = Progress();
    expect(previewSkill(warrior, nova), isEmpty);
    expect(warrior.skillDamage(nova), 0);
  });
}

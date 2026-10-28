import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/sorceress_rules.dart';
import 'package:guardian_new/stage_content.dart';

void main() {
  SkillDef skill(Progress p, String id) =>
      p.skills.firstWhere((s) => s.id == id);
  void train(Progress p, String id, [int rank = 1]) {
    final def = skill(p, id);
    for (final need in def.requires.entries) {
      if (p.rank(need.key) < need.value) train(p, need.key, need.value);
    }
    while (p.rank(id) < rank) {
      expect(p.learn(def), true, reason: '$id rank${p.rank(id) + 1}');
    }
  }

  Progress advanced() => Progress(heroClass: HeroClass.mage)
    ..level = 100
    ..skillPoints = 1000;

  test(
    'the original thirty skills keep source levels, prerequisites and twenty-rank limits',
    () {
      final source =
          jsonDecode(
                File(
                  'test/fixtures/diablo2_sorceress_113.json',
                ).readAsStringSync(),
              )
              as Map;
      final expected = source['skills'] as Map;
      final p = advanced();
      expect(mageSkills.length, 30);
      expect(p.skills.length, 31);
      expect(mageSkills.map((s) => s.id).toSet(), expected.keys.toSet());
      for (final def in mageSkills) {
        final data = expected[def.id] as Map;
        expect(def.requiredLevel, data['level'], reason: def.id);
        expect(def.requires, data['requires'], reason: def.id);
        expect(def.rankLimit, 20, reason: def.id);
        expect(def.requiredLevelForRank(20), def.requiredLevel + 19);
      }
      expect(skill(p, 'sorceressAttack').rankLimit, 1);
      expect(mageSkills, isNot(contains(skill(p, 'sorceressAttack'))));
    },
  );

  test(
    'fresh Sorceress has two points, one spell and a free normal weapon attack',
    () {
      final p = Progress(heroClass: HeroClass.mage);
      expect(p.skillPoints, 2);
      expect(p.ranks, {'firebolt': 1, 'sorceressAttack': 1});
      expect(p.selectedBasic, 'firebolt');
      expect(p.skillSlots, ['firebolt', null, null, null]);
      expect(p.investedSkillPoints, 0);
      expect(p.skillCost(skill(p, 'firebolt')), 2.5);
      expect(p.skillCost(skill(p, 'sorceressAttack')), 0);
      expect(p.canSelectBasic('iceBolt'), false);
      expect(p.canSelectSkill('sorceressAttack'), false);
      expect(Progress.fromSave(p.toSave())!.toSave(), p.toSave());
    },
  );

  test(
    'three original basic spells use original mana while four active slots remain independent',
    () {
      final p = advanced();
      for (final id in ['iceBolt', 'chargedBolt', 'frostNova', 'fireball']) {
        train(p, id);
      }
      expect(p.basicSkills.map((s) => s.id).toSet(), {
        'firebolt',
        'iceBolt',
        'chargedBolt',
        'sorceressAttack',
      });
      final points = p.skillPoints, slots = List<String?>.of(p.skillSlots);
      for (final id in [
        'firebolt',
        'iceBolt',
        'chargedBolt',
        'sorceressAttack',
      ]) {
        expect(p.selectBasic(id), true);
        expect(p.skillPoints, points);
        expect(p.skillSlots, slots);
      }
      for (var i = 0; i < 4; i++) {
        expect(
          p.selectSkill(
            ['firebolt', 'iceBolt', 'chargedBolt', 'frostNova'][i],
            slot: i,
          ),
          true,
        );
      }
      expect(p.skillSlots, ['firebolt', 'iceBolt', 'chargedBolt', 'frostNova']);
      expect(p.selectSkill('blink'), false);
      expect(p.skillCost(skill(p, 'iceBolt')), 3);
      expect(p.skillCost(skill(p, 'chargedBolt')), 3);
      expect(Progress.fromSave(p.toSave())!.skillSlots, p.skillSlots);
    },
  );

  test(
    'original direct parents and the next-rank character level are mandatory',
    () {
      final p = advanced();
      expect(p.learn(skill(p, 'meteor')), false);
      train(p, 'fireball');
      expect(p.learn(skill(p, 'meteor')), false);
      train(p, 'firewall');
      p.level = 23;
      expect(p.learn(skill(p, 'meteor')), false);
      p.level = 24;
      expect(p.learn(skill(p, 'meteor')), true);
      expect(p.learn(skill(p, 'meteor')), false);
      p.level = 25;
      expect(p.learn(skill(p, 'meteor')), true);
      p.level = 100;
      train(p, 'meteor', 20);
      final points = p.skillPoints;
      expect(p.learn(skill(p, 'meteor')), false);
      expect(p.skillPoints, points);
    },
  );

  test(
    'new saves require the Sorceress version and reject invalid skills, ranks and prerequisites',
    () {
      final p = advanced();
      train(p, 'iceBlast');
      final valid = p.toSave();
      expect(valid['sorceressTreeVersion'], 1);
      expect(Progress.fromSave(valid), isNotNull);
      for (final edit in <void Function(Map<String, dynamic>)>[
        (d) => d.remove('sorceressTreeVersion'),
        (d) => d['sorceressTreeVersion'] = 2,
        (d) => (d['ranks'] as Map)['iceBlast'] = 21,
        (d) => (d['ranks'] as Map).remove('iceBolt'),
        (d) => (d['ranks'] as Map)['iceArmor'] = 1,
        (d) => d['selectedBasic'] = 'chargedBolt',
        (d) => d['selectedSkill'] = 'sorceressAttack',
        (d) => d['level'] = 5,
      ]) {
        final data = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
        edit(data);
        expect(Progress.fromSave(data), isNull);
      }
    },
  );

  test(
    'all thirty actual learned maximum ranks save and refund exactly their invested points',
    () {
      final p = advanced();
      for (final def in mageSkills) {
        train(p, def.id, 20);
      }
      expect(p.investedSkillPoints, 599);
      expect(p.skillPoints, 401);
      expect(p.ranks['sorceressAttack'], 1);
      final restored = Progress.fromSave(p.toSave())!;
      expect(restored.ranks, p.ranks);
      restored.awardSkillResetTicket(WorldStage.forest);
      expect(restored.resetSkills(), true);
      expect(restored.skillPoints, 1000);
      expect(restored.ranks, {'firebolt': 1, 'sorceressAttack': 1});
      expect(restored.skillSlots, ['firebolt', null, null, null]);
      expect(restored.selectedBasic, 'firebolt');
      expect(restored.skillResetTickets, 0);
      expect(Progress.fromSave(restored.toSave()), isNotNull);
    },
  );

  test(
    'spell damage comes from original ranks and mastery rather than staff attack power',
    () {
      final p = advanced();
      final bolt = skill(p, 'firebolt');
      final before = p.skillDamage(bolt), normal = p.swordDamage;
      final staff = p.createGear(
        gearById('emberstaff'),
        rarity: Rarity.rare,
        power: 30,
      );
      p.inventory.add(staff);
      expect(p.equip(staff), true);
      expect(p.swordDamage, greaterThan(normal));
      expect(p.skillDamage(bolt), before);
      train(p, 'fireMastery');
      expect(p.skillDamage(bolt), closeTo(before * 1.3, 1e-9));
      expect(p.sorceressSpell(bolt).damageType, SorceressDamageType.fire);
      expect(p.skillCooldown(bolt), 0);
      expect(p.actualBasicInterval(), p.skillMotionTime(bolt));
    },
  );

  test(
    'Warmth changes recovery while original cold armor changes armor without percentage protection',
    () {
      final p = advanced();
      final recovery = p.manaRecovery, armor = p.armor;
      train(p, 'warmth', 20);
      expect(p.manaRecovery, closeTo(recovery * 3.58, 1e-9));
      p.sorceressArmorMultiplier = 2.59;
      expect(p.armor, closeTo(armor * 2.59, 1e-9));
      expect(Progress.fromSave(p.toSave())!.sorceressArmorMultiplier, 1);
      p.sorceressArmorMultiplier = double.nan;
      expect(p.armor, armor);
    },
  );
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/skill_tree_layout.dart';
import 'package:guardian_new/sorceress_combat.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Progress advanced(HeroClass hero) {
    final p = Progress(heroClass: hero)..level = 100;
    for (final def in p.skills) {
      p.ranks[def.id] = def.rankLimit;
    }
    return p;
  }

  test(
    'warrior basic equips every auxiliary slot and shares main recovery',
    () {
      for (var slot = 0; slot < 4; slot++) {
        final p = Progress();
        expect(p.selectSkill('cleave', slot: slot), isTrue);
        expect(p.skillAt(slot)!.id, 'cleave');
        expect(Progress.fromSave(p.toSave())!.skillSlots, p.skillSlots);
      }
      final art = GameArt();
      final s = inCombatField(Adventure(art))..start(TestGame());
      addTearDown(s.dispose);
      addTearDown(art.dispose);
      s.mobs.clear();
      expect(s.progress.selectSkill('cleave', slot: 1), isTrue);
      expect(s.progress.selectPrimary('howl'), isTrue);
      final target = s.spawnEnemy(
        'goblin',
        s.hero.body.center + const Offset(40, 0),
      )!..life.initial(1000);
      final energy = s.progress.energy;
      s.hero.skill(slot: 1);
      expect(target.life.value, lessThan(1000));
      expect(s.hero.attackClock, greaterThan(0));
      expect(s.progress.energy, greaterThanOrEqualTo(energy));
      final health = target.life.value;
      s.progress.selectPrimary('cleave');
      s.hero.slash();
      s.hero.skill(slot: 1);
      expect(target.life.value, health);
    },
  );
  test(
    'primary accepts learned active skills and can be emptied and restored without unlearning',
    () {
      for (final hero in HeroClass.values) {
        final p = advanced(hero),
            id = hero == HeroClass.warrior ? 'bash' : 'meteor';
        expect(p.primarySkill!.id, p.defaultBasicId);
        expect(p.selectPrimary(id), isTrue);
        expect(p.primarySkill!.id, id);
        expect(p.skillAt(Progress.primarySlot)!.id, id);
        final ranks = Map.of(p.ranks), points = p.skillPoints;
        expect(p.selectPrimary(null), isTrue);
        expect(p.primarySkill, isNull);
        expect(p.ranks, ranks);
        expect(p.skillPoints, points);
        expect(p.selectPrimary(p.defaultBasicId), isTrue);
        expect(p.primarySkill!.id, p.defaultBasicId);
        expect(p.selectPrimary('not-a-skill'), isFalse);
        final passive = p.skills.firstWhere((def) => def.passive);
        expect(p.selectPrimary(passive.id), isFalse);
        expect(p.primarySkill!.id, p.defaultBasicId);
      }
    },
  );
  test(
    'empty and active primary slots roundtrip; old saves keep their selected basic',
    () {
      final p = advanced(HeroClass.mage);
      for (final id in <String?>['meteor', null, 'iceBolt']) {
        expect(p.selectPrimary(id), isTrue);
        final restored = Progress.fromSave(jsonDecode(jsonEncode(p.toSave())))!;
        expect(restored.primarySkill?.id, p.primarySkill?.id);
        expect(restored.toSave(), p.toSave());
      }
      final old = p.toSave()..remove('primarySkill');
      expect(Progress.fromSave(old)!.primarySkill!.id, 'iceBolt');
      for (final invalid in ['warmth', 'sorceressAttack', 'unknown', 4]) {
        expect(
          Progress.fromSave(p.toSave()..['primarySkill'] = invalid),
          isNull,
        );
      }
    },
  );
  test(
    'primary uses the same actual cast, resource debit and cooldown as an auxiliary slot',
    () {
      final art = GameArt(), game = TestGame();
      final s = inCombatField(Adventure(art))..start(game);
      addTearDown(s.dispose);
      addTearDown(art.dispose);
      s.mobs.clear();
      s.progress.ranks['bash'] = 1;
      s.progress.energy = s.progress.maxEnergy;
      expect(s.progress.selectPrimary('bash'), isTrue);
      final target = s.spawnEnemy(
        'goblin',
        s.hero.body.center + const Offset(65, 0),
      )!..life.initial(1000);
      final energy = s.progress.energy;
      s.hero.slash();
      expect(target.life.value, lessThan(1000));
      final skill = s.progress.primarySkill!;
      expect(s.progress.energy, energy - s.progress.skillCost(skill));
      expect(s.hero.cooldowns[skill.id], s.progress.skillCooldown(skill));
      final hp = target.life.value, paid = s.progress.energy;
      s.progress.selectSkill(skill.id);
      s.hero.skill();
      s.hero.slash();
      expect(s.progress.energy, paid);
      expect(target.life.value, hp);
      s.progress.selectPrimary(null);
      s.hero.attackClock = s.hero.castLock = 0;
      s.hero.slash();
      expect(s.progress.energy, paid);
      expect(target.life.value, hp);
    },
  );
  test(
    'primary aimed spell retains its owning slot and cancels after unequip',
    () {
      final art = GameArt(), game = TestGame();
      final s = inCombatField(Adventure(art, heroClass: HeroClass.mage))
        ..start(game);
      addTearDown(s.dispose);
      addTearDown(art.dispose);
      s.progress.level = 100;
      for (final def in s.progress.skills) {
        s.progress.ranks[def.id] = def.rankLimit;
      }
      s.progress.energy = s.progress.maxEnergy;
      s.progress.selectPrimary('meteor');
      s.hero.beginAim(Progress.primarySlot);
      expect(s.hero.aim!.slot, Progress.primarySlot);
      s.hero.moveAim(const Offset(25, 5), ownerSlot: Progress.primarySlot);
      final mana = s.progress.energy;
      s.progress.selectPrimary(null);
      s.hero.finishAim(false, ownerSlot: Progress.primarySlot);
      expect(s.progress.energy, mana);
      expect(game.added.whereType<SorceressMeteor>(), isEmpty);
      s.progress.selectPrimary('meteor');
      s.hero.beginAim(Progress.primarySlot);
      s.hero.finishAim(false, ownerSlot: Progress.primarySlot);
      expect(s.progress.energy, lessThan(mana));
      expect(game.added.whereType<SorceressMeteor>(), hasLength(1));
    },
  );
  test(
    'basic attacks are trainable tree nodes; reset clears an unlearned primary',
    () {
      final p = advanced(HeroClass.warrior);
      final basics = p.basicSkills.toList();
      final school = SkillSchoolLayout(p, 3, 300, dense: false, textScale: 1);
      for (final basic in basics) {
        expect(skillTreeSkillVisible(p, basic), isTrue);
        expect(school.rects, contains(basic.id));
      }
      p.selectPrimary('whirlwind');
      p.awardSkillResetTicket(WorldStage.forest);
      expect(p.resetSkills(), isTrue);
      expect(p.primarySkill, isNull);
      expect(p.selectBasic('cleave'), isTrue);
      expect(p.primarySkill!.id, 'cleave');
    },
  );
}

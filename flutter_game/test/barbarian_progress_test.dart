import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'package:guardian_new/stage_content.dart';

import 'support/test_game.dart';

const _originalSkills = {
  'bash',
  'leap',
  'doubleSwing',
  'stun',
  'doubleThrow',
  'leapAttack',
  'concentrate',
  'frenzy',
  'whirlwind',
  'berserk',
  'swordMastery',
  'axeMastery',
  'maceMastery',
  'polearmMastery',
  'throwingMastery',
  'spearMastery',
  'increasedStamina',
  'ironSkin',
  'increasedSpeed',
  'naturalResistance',
  'howl',
  'findPotion',
  'taunt',
  'shout',
  'findItem',
  'battleCry',
  'battleOrders',
  'grimWard',
  'warcry',
  'battleCommand',
};

Map<String, dynamic> detached(Progress p) =>
    jsonDecode(jsonEncode(p.toSave())) as Map<String, dynamic>;

void trainSkill(Progress p, String id, [int rank = 1]) {
  final skill = p.skills.firstWhere((skill) => skill.id == id);
  for (final need in skill.requires.entries) {
    trainSkill(p, need.key, need.value);
  }
  while (p.rank(id) < rank) {
    expect(p.learn(skill), true, reason: '$id rank$rank');
  }
}

void expectValidLoadout(Progress p) {
  expect(p.rank(p.selectedBasic), greaterThan(0));
  expect(p.basicSkill.basic, true);
  expect(p.skillAt(0), isNotNull);
  final assigned = p.skillSlots.whereType<String>().toList();
  expect(assigned.toSet(), hasLength(assigned.length));
  for (final id in assigned) {
    final skill = p.skills.firstWhere((skill) => skill.id == id);
    expect(p.rank(id), greaterThan(0));
    expect(skill.passive || skill.mobility, false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'warrior has thirty original skills with twenty ranks and three extras',
    () {
      final p = Progress();
      expect(_originalSkills, hasLength(30));
      expect(p.skills.map((skill) => skill.id).toSet(), {
        ..._originalSkills,
        'cleave',
        'shadowAssault',
        'battleSprint',
      });
      for (final skill in p.skills) {
        expect(
          skill.rankLimit,
          _originalSkills.contains(skill.id) ? 20 : 5,
          reason: skill.id,
        );
      }
    },
  );

  test(
    'fresh warriors have usable actions and roundtrip with the new skill version',
    () {
      final p = Progress();
      expect(p.selectedBasic, 'cleave');
      expect(p.selectedSkill, 'howl');
      expect(p.ranks, {'cleave': 1, 'howl': 1});
      expect(p.investedSkillPoints, 0);
      expectValidLoadout(p);
      final data = detached(p);
      expect(data['barbarianTreeVersion'], 1);
      final restored = Progress.fromSave(data);
      expect(restored, isNotNull);
      expect(restored!.toSave(), p.toSave());
      expectValidLoadout(restored);
      data.remove('barbarianTreeVersion');
      expect(
        Progress.fromSave(data),
        isNull,
        reason: 'old warrior layouts are deliberately unsupported',
      );
    },
  );

  test(
    'twenty mastery ranks spend exactly twenty points and cannot overflow',
    () {
      final p = Progress()
        ..level = 100
        ..skillPoints = 1000;
      final mastery = p.skills.firstWhere(
        (skill) => skill.id == 'swordMastery',
      );
      final points = p.skillPoints;
      for (var rank = 1; rank <= 20; rank++) {
        expect(p.learn(mastery), true);
        expect(p.rank(mastery.id), rank);
        expect(p.skillPoints, points - rank);
      }
      expect(p.canLearn(mastery), false);
      expect(p.learn(mastery), false);
      final restored = Progress.fromSave(detached(p));
      expect(restored, isNotNull);
      expect(restored!.rank(mastery.id), 20);
      expect(restored.toSave(), p.toSave());
      final invalid = detached(p);
      (invalid['ranks'] as Map)['swordMastery'] = 21;
      expect(Progress.fromSave(invalid), isNull);
    },
  );

  test(
    'Battle Command adds an effective rank without increasing investments or the saved cap',
    () {
      final p = Progress()
        ..level = 100
        ..skillPoints = 1000;
      final mastery = p.skills.firstWhere(
        (skill) => skill.id == 'swordMastery',
      );
      while (p.rank(mastery.id) < mastery.rankLimit) {
        expect(p.learn(mastery), true);
      }
      final points = p.skillPoints, spent = p.investedSkillPoints;
      p.activeSkillBonus = 1;
      expect(p.rank(mastery.id), 20);
      expect(p.effectiveRank(mastery.id), 21);
      expect(p.learn(mastery), false);
      expect(p.skillPoints, points);
      expect(p.investedSkillPoints, spent);
      final restored = Progress.fromSave(detached(p));
      expect(restored, isNotNull);
      expect(restored!.rank(mastery.id), 20);
      expect(restored.effectiveRank(mastery.id), 20);
      expect(restored.skillPoints, points);
    },
  );

  test(
    'Battle Command preserves the invested point budget while expanding learned area caps once',
    () {
      final p = Progress()..level = 100;
      p.ranks['whirlwind'] = 20;
      final skill = p.skills.firstWhere((skill) => skill.id == 'whirlwind');
      final budget = p.investedSkillPoints + p.skillPoints;
      expect(p.skillTargetLimit(skill), 22);
      p.activeSkillBonus = 1;
      expect(p.skillTargetLimit(skill), 23);
      expect(p.rank(skill.id), 20);
      expect(p.investedSkillPoints + p.skillPoints, budget);
    },
  );

  test(
    'mage ranks remain capped at five without requiring the warrior marker',
    () {
      final p = Progress(heroClass: HeroClass.mage)
        ..level = 100
        ..skillPoints = 1000;
      final basic = p.skills.firstWhere((skill) => skill.id == 'firebolt');
      while (p.rank(basic.id) < 5) {
        expect(p.learn(basic), true);
      }
      expect(p.learn(basic), false);
      final saved = detached(p)..remove('barbarianTreeVersion');
      expect(Progress.fromSave(saved), isNotNull);
      (saved['ranks'] as Map)['firebolt'] = 6;
      expect(Progress.fromSave(saved), isNull);
    },
  );

  test(
    'level requirements and impossible loadout fields reject invalid new saves',
    () {
      final p = Progress()..skillPoints = 100;
      for (final skill in p.skills.where((skill) => skill.requiredLevel > 1)) {
        final before = p.skillPoints;
        expect(p.canLearn(skill), false, reason: skill.id);
        expect(p.learn(skill), false, reason: skill.id);
        expect(p.skillPoints, before);
      }
      final highLevelSkill = p.skills.firstWhere(
        (skill) => skill.id == 'warcry',
      );
      final invalidLevel = detached(p);
      (invalidLevel['ranks'] as Map)[highLevelSkill.id] = 1;
      expect(Progress.fromSave(invalidLevel), isNull);
      for (final value in ['swordMastery', 'battleSprint', 'missingSkill']) {
        final bad = detached(Progress()..level = 100)
          ..['selectedSkill'] = value;
        if (value != 'missingSkill') (bad['ranks'] as Map)[value] = 1;
        expect(
          Progress.fromSave(bad),
          isNull,
          reason:
              'known learned passives/mobility cannot occupy an action slot',
        );
      }
      final badBasic = detached(Progress()..level = 100)
        ..['selectedBasic'] = 'swordMastery';
      (badBasic['ranks'] as Map)['swordMastery'] = 1;
      expect(Progress.fromSave(badBasic), isNull);
      final duplicate = detached(p)..['secondarySkill'] = p.selectedSkill;
      expect(Progress.fromSave(duplicate), isNull);
      final impossibleRank = detached(p);
      (impossibleRank['ranks'] as Map)['cleave'] = 6;
      expect(Progress.fromSave(impossibleRank), isNull);
    },
  );

  test(
    'original D2 rank unlocks require one character level per additional point',
    () {
      final p = Progress()
        ..level = 30
        ..skillPoints = 1000;
      trainSkill(p, 'warcry');
      final skill = p.skills.firstWhere((skill) => skill.id == 'warcry');
      expect(p.rank('warcry'), 1);
      final points = p.skillPoints;
      expect(p.canLearn(skill), false);
      expect(p.learn(skill), false);
      expect(p.skillPoints, points);
      p.activeSkillBonus = 1;
      expect(p.effectiveRank('warcry'), 2);
      expect(
        p.canLearn(skill),
        false,
        reason: 'a temporary Battle Command rank cannot bypass the point gate',
      );
      p.activeSkillBonus = 0;
      final invalid = detached(p);
      (invalid['ranks'] as Map)['warcry'] = 2;
      expect(Progress.fromSave(invalid), isNull);
      p.level = 31;
      expect(p.learn(skill), true);
      expect(p.rank('warcry'), 2);
      expect(p.skillPoints, points - 1);
      expect(Progress.fromSave(detached(p)), isNotNull);
    },
  );

  for (final fraction in [1.0, .5, 0.0]) {
    test(
      'active Battle Orders saves and scene checkpoints preserve $fraction of base resources',
      () {
        final session = inCombatField(Adventure(GameArt()))..start(TestGame());
        addTearDown(session.dispose);
        final p = session.progress
          ..level = 100
          ..skillPoints = 1000;
        trainSkill(p, 'battleOrders', 20);
        p.energy = p.maxEnergy;
        expect(p.selectSkill('battleOrders'), true);
        session.hero.skill();
        expect(p.activeLifeMultiplier, greaterThan(1));
        expect(p.activeResourceMultiplier, greaterThan(1));
        p.hp = p.maxHp * fraction;
        p.energy = p.maxEnergy * fraction;
        session.syncLife();
        final liveHp = p.hp, liveEnergy = p.energy;
        final saved = detached(p);
        expect(
          p.hp,
          liveHp,
          reason: 'saving must not change the active health',
        );
        expect(p.energy, liveEnergy);
        final restored = Progress.fromSave(saved);
        expect(restored, isNotNull);
        expect(restored!.activeLifeMultiplier, 1);
        expect(restored.activeResourceMultiplier, 1);
        expect(restored.hp, closeTo(restored.baseMaxHp * fraction, .00001));
        expect(
          restored.energy,
          closeTo(restored.baseMaxEnergy * fraction, .00001),
        );
        final repeated = Progress.fromSave(detached(restored));
        expect(repeated, isNotNull);
        expect(repeated!.toSave(), restored.toSave());
        final checkpoint = GameCheckpoint.capture(session);
        if (fraction == 0) {
          expect(
            checkpoint,
            isNull,
            reason: 'dead sessions must never produce a living save',
          );
          return;
        }
        expect(checkpoint, isNotNull);
        final resumed = checkpoint!.restore(GameArt());
        addTearDown(resumed.dispose);
        expect(
          resumed.progress.hp / resumed.progress.maxHp,
          closeTo(fraction, .00001),
        );
        expect(
          resumed.progress.energy / resumed.progress.maxEnergy,
          closeTo(fraction, .00001),
        );
        expect(resumed.progress.activeLifeMultiplier, 1);
      },
    );
  }

  test(
    'maxing the whole new catalogue preserves points, slots and reset ticket accounting',
    () {
      final p = Progress()
        ..level = 100
        ..skillPoints = 10000;
      final budget = p.skillPoints + p.investedSkillPoints;
      // Learn through actual prerequisites rather than writing ranks directly.
      for (var pass = 0; pass < 1000; pass++) {
        final available = p.skills.where(p.canLearn).firstOrNull;
        if (available == null) break;
        expect(p.learn(available), true);
      }
      for (final skill in p.skills) {
        expect(p.rank(skill.id), skill.rankLimit, reason: skill.id);
      }
      expect(p.skillPoints + p.investedSkillPoints, budget);
      expectValidLoadout(p);
      final saved = detached(p);
      final restored = Progress.fromSave(saved);
      expect(restored, isNotNull);
      expect(restored!.toSave(), p.toSave());
      restored.awardSkillResetTicket(WorldStage.forest);
      expect(restored.resetSkills(), true);
      expect(restored.skillResetTickets, 0);
      expect(restored.skillPoints + restored.investedSkillPoints, budget);
      expect(restored.ranks, {'cleave': 1, 'howl': 1});
      expect(restored.investedSkillPoints, 0);
      expectValidLoadout(restored);
      expect(Progress.fromSave(detached(restored)), isNotNull);
    },
  );

  test('a new warrior scene checkpoint keeps its valid starter action', () {
    final session = Adventure(GameArt())..start(TestGame());
    addTearDown(session.dispose);
    final checkpoint = GameCheckpoint.capture(session);
    expect(checkpoint, isNotNull);
    final restored = checkpoint!.restore(GameArt())..start(TestGame());
    addTearDown(restored.dispose);
    expect(restored.progress.selectedSkill, 'howl');
    expectValidLoadout(restored.progress);
    expect(restored.progress.toSave(), session.progress.toSave());
  });

  test('rank-six previews match a real seventh mastery investment', () {
    final p = Progress()
      ..level = 100
      ..skillPoints = 1000;
    final skill = p.skills.firstWhere((skill) => skill.id == 'swordMastery');
    while (p.rank(skill.id) < 6) {
      expect(p.learn(skill), true);
    }
    final before = jsonEncode(p.toSave());
    final rows = previewSkill(p, skill);
    expect(rows, isNotEmpty);
    expect(
      jsonEncode(p.toSave()),
      before,
      reason: 'opening a preview must not spend or rewrite anything',
    );
    final expected = rows.map((row) => row.next).toList();
    expect(
      rows.any((row) => row.next != row.current),
      true,
      reason: 'rank seven must offer a real benefit beyond rank five',
    );
    expect(p.learn(skill), true);
    final learned = previewSkill(p, skill);
    expect(learned.map((row) => row.current).toList(), expected);
  });
}

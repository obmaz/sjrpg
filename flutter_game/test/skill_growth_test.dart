import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final hero in const [HeroClass.warrior]) {
    test(
      hero == HeroClass.warrior
          ? '$hero canonical ranks preserve fixed cooldowns and single-target roles'
          : '$hero ranks prioritize cooldown, speed and targets over damage',
      () {
        final p = Progress(heroClass: hero);
        for (final skill in p.skills.where((v) => !v.passive && !v.mobility)) {
          final first = p.skillDamage(skill, atRank: 1),
              last = p.skillDamage(skill, atRank: 5);
          if (first > 0) {
            expect(last / first, lessThanOrEqualTo(1.25), reason: skill.id);
          }
          var cooldown = p.skillCooldown(skill, atRank: 1),
              tempo = p.skillTempo(skill, atRank: 1),
              cap = p.skillTargetLimit(skill, atRank: 1);
          final canonical = hero == HeroClass.warrior && skill.rankLimit == 20;
          for (var r = 2; r <= skill.rankLimit; r++) {
            expect(
              p.skillCooldown(skill, atRank: r),
              canonical ? closeTo(cooldown, .000001) : lessThan(cooldown),
              reason: skill.id,
            );
            expect(
              p.skillTempo(skill, atRank: r),
              greaterThan(tempo),
              reason: skill.id,
            );
            expect(
              p.skillTargetLimit(skill, atRank: r),
              greaterThanOrEqualTo(cap),
              reason: skill.id,
            );
            cooldown = p.skillCooldown(skill, atRank: r);
            tempo = p.skillTempo(skill, atRank: r);
            cap = p.skillTargetLimit(skill, atRank: r);
          }
          if (canonical) {
            final expected = switch (skill.id) {
              'leap' ||
              'howl' ||
              'warcry' ||
              'battleCry' ||
              'grimWard' ||
              'whirlwind' => 22,
              'doubleThrow' => 2,
              'bash' ||
              'doubleSwing' ||
              'stun' ||
              'leapAttack' ||
              'concentrate' ||
              'frenzy' ||
              'berserk' ||
              'taunt' ||
              'findPotion' ||
              'findItem' => 1,
              _ => 0,
            };
            expect(cap, expected, reason: skill.id);
          } else if (skill.id != 'iceArmor') {
            expect(
              cap,
              greaterThan(p.skillTargetLimit(skill, atRank: 1)),
              reason: skill.id,
            );
          }
        }
        final basic = p.basicSkill;
        final interval = p.attackInterval;
        p.ranks[basic.id] = 5;
        expect(p.attackInterval, closeTo(interval / 1.06, .000001));
        expect(p.attackInterval, lessThan(interval));
      },
    );
    test(
      '$hero simulation uses the displayed cooldown at every rank and saves it',
      () {
        final s = inCombatField(Adventure(GameArt(), heroClass: hero))
          ..start(TestGame());
        addTearDown(s.dispose);
        s.mobs.clear();
        s.progress.gainXp(50000);
        for (final skill in s.progress.skills) {
          while (s.progress.level <
              skill.requiredLevelForRank(skill.rankLimit)) {
            s.progress.gainXp(s.progress.nextLevelXp);
          }
        }
        for (final skill in s.progress.skills.where(
          (v) => !v.passive && !v.mobility,
        )) {
          for (var r = 1; r <= skill.rankLimit; r++) {
            s.hero.resetCombo();
            s.hero.barbarianCombat.cancelActions();
            s.hero.barbarianCombat.clearBuffs();
            s.barbarianUtilities.clear();
            s.syncBarbarianBuffs();
            s.progress.ranks[skill.id] = r;
            expect(s.progress.selectSkill(skill.id), isTrue);
            s.progress.energy = s.progress.maxEnergy;
            s.hero.cooldowns.clear();
            s.hero.castLock = 0;
            s.hero.spin = s.hero.chargeTime = s.hero.heavyWindup = 0;
            s.hero.heavySkill = null;
            if (hero == HeroClass.warrior) {
              s.mobs.clear();
              final target = s.spawnEnemy(
                'goblin',
                s.hero.body.center + const Offset(80, 0),
              )!;
              target.life.initial(100000);
              if (const {
                'findPotion',
                'findItem',
                'grimWard',
              }.contains(skill.id)) {
                var body = target;
                for (var attempt = 0; attempt < 200; attempt++) {
                  expect(s.hit(body, body.life.max + 1, Offset.zero), isTrue);
                  if (s.barbarianUtilities.corpseCount > 0) break;
                  body = s.spawnEnemy(
                    'goblin',
                    s.hero.body.center + const Offset(80, 0),
                  )!;
                }
                expect(s.barbarianUtilities.corpseCount, 1);
              }
            }
            final energy = s.progress.energy;
            s.hero.skill();
            if (hero == HeroClass.warrior && skill.rankLimit == 20) {
              expect(
                energy - s.progress.energy,
                s.progress.skillCost(skill),
                reason: '${skill.id} rank$r actual resource debit',
              );
            }
            expect(
              s.hero.cooldowns[skill.id],
              closeTo(s.progress.skillCooldown(skill), .000001),
              reason: '${skill.id} rank$r',
            );
            final rows = previewSkill(s.progress, skill);
            final cooldownRow = rows.firstWhere((row) => row.label == '재사용 대기');
            expect(cooldownRow.current, s.progress.skillCooldown(skill));
          }
        }
        final cp = GameCheckpoint.capture(s)!;
        final restored = cp.restore(GameArt());
        addTearDown(restored.dispose);
        expect(restored.hero.cooldowns, s.hero.cooldowns);
      },
    );
  }

  test(
    'Sorceress rank20 growth follows original damage and quantities without invented haste or cooldown perks',
    () {
      final p = Progress(heroClass: HeroClass.mage)
        ..level = 100
        ..skillPoints = 1000;
      for (final def in mageSkills) {
        var damage = 0.0, targets = 0;
        for (var rank = 1; rank <= 20; rank++) {
          final stats = p.sorceressSpell(def, atRank: rank);
          expect(
            p.skillCooldown(def, atRank: rank),
            def.cooldown,
            reason: def.id,
          );
          expect(p.skillTempo(def, atRank: rank), 1);
          expect(p.skillMotionTime(def, atRank: rank), stats.motionTime);
          expect(
            p.skillDamage(def, atRank: rank),
            greaterThanOrEqualTo(damage),
            reason: def.id,
          );
          expect(
            p.skillTargetLimit(def, atRank: rank),
            greaterThanOrEqualTo(targets),
            reason: def.id,
          );
          damage = p.skillDamage(def, atRank: rank);
          targets = p.skillTargetLimit(def, atRank: rank);
        }
        if (const {
          'firebolt',
          'iceBolt',
          'iceBlast',
          'telekinesis',
          'thunderStorm',
        }.contains(def.id)) {
          expect(targets, 1);
        }
        if (def.id == 'chargedBolt') expect(targets, 22);
        if (def.id == 'chainLightning') expect(targets, 9);
      }
      final interval = p.attackInterval;
      p.ranks['firebolt'] = 20;
      expect(
        p.attackInterval,
        interval,
        reason: 'spell rank does not invent a faster casting animation',
      );
      expect(
        p.basicDamage,
        greaterThan(Progress(heroClass: HeroClass.mage).basicDamage),
      );
    },
  );

  test(
    'Sorceress actual casts debit source mana and assign source shared delays at every invested rank',
    () {
      final s = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage))
        ..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.waveTime = 10000;
      final p = s.progress
        ..level = 100
        ..skillPoints = 1000;
      void train(String id, int rank) {
        final def = p.skills.firstWhere((d) => d.id == id);
        for (final parent in def.requires.entries) {
          if (p.rank(parent.key) < parent.value) {
            train(parent.key, parent.value);
          }
        }
        while (p.rank(id) < rank) {
          expect(p.learn(def), true);
        }
      }

      for (final def in mageSkills) {
        train(def.id, 20);
      }
      for (final def in mageSkills.where((d) => !d.passive && !d.mobility)) {
        for (var rank = 1; rank <= 20; rank++) {
          s.hero.sorceressCombat.clear();
          s.hero.cooldowns.clear();
          s.hero.castLock = s.hero.attackClock = 0;
          s.hero.queuedCast = null;
          p.ranks[def.id] = rank;
          expect(p.selectSkill(def.id), true);
          p.energy = p.maxEnergy;
          final before = p.energy, stats = p.sorceressSpell(def);
          s.hero.skill();
          final cost = def.id == 'inferno'
              ? stats.manaPerSecond * stats.interval
              : stats.manaCost;
          expect(
            before - p.energy,
            closeTo(cost, .000001),
            reason: '${def.id} rank$rank',
          );
          expect(
            s.hero.cooldowns[def.id] ?? 0,
            stats.castDelay,
            reason: '${def.id} rank$rank',
          );
          expect(s.hero.sorceressCombat.sharedDelay, stats.castDelay);
          final preview = previewSkill(
            p,
            def,
          ).firstWhere((r) => r.label == '공통 시전 지연');
          expect(preview.current, stats.castDelay);
        }
      }
      final cp = GameCheckpoint.capture(s)!;
      final restored = cp.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.hero.cooldowns, s.hero.cooldowns);
      expect(
        restored.hero.sorceressCombat.sharedDelay,
        s.hero.sorceressCombat.sharedDelay,
      );
    },
  );
}

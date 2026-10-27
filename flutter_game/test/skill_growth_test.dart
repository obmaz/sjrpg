import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final hero in HeroClass.values) {
    test('$hero ranks prioritize cooldown, speed and targets over damage', () {
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
        for (var r = 2; r <= 5; r++) {
          expect(
            p.skillCooldown(skill, atRank: r),
            lessThan(cooldown),
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
        if (skill.id != 'iceArmor') {
          expect(
            cap,
            greaterThan(p.skillTargetLimit(skill, atRank: 1)),
            reason: skill.id,
          );
        }
      }
      final basic = p.skills.first;
      final interval = p.attackInterval;
      p.ranks[basic.id] = 5;
      expect(p.attackInterval, closeTo(interval / 1.06, .000001));
      expect(p.attackInterval, lessThan(interval));
    });
    test(
      '$hero simulation uses the displayed cooldown at every rank and saves it',
      () {
        final s = inCombatField(Adventure(GameArt(), heroClass: hero))
          ..start(TestGame());
        addTearDown(s.dispose);
        s.mobs.clear();
        s.progress.gainXp(50000);
        for (final skill in s.progress.skills.where(
          (v) => !v.passive && !v.mobility,
        )) {
          for (var r = 1; r <= 5; r++) {
            s.progress.ranks[skill.id] = r;
            s.progress.selectSkill(skill.id);
            s.progress.energy = s.progress.maxEnergy;
            s.hero.cooldowns.clear();
            s.hero.castLock = 0;
            s.hero.spin = s.hero.chargeTime = s.hero.heavyWindup = 0;
            s.hero.heavySkill = null;
            s.hero.skill();
            expect(
              s.hero.cooldowns[skill.id],
              closeTo(s.progress.skillCooldown(skill), .000001),
              reason: '${skill.id} rank$r',
            );
            final rows = previewSkill(s.progress, skill);
            expect(rows.first.label, '재사용 대기');
            expect(rows.first.current, s.progress.skillCooldown(skill));
          }
        }
        final cp = GameCheckpoint.capture(s)!;
        final restored = cp.restore(GameArt());
        addTearDown(restored.dispose);
        expect(restored.hero.cooldowns, s.hero.cooldowns);
      },
    );
  }
}

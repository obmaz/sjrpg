import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skills_panel.dart';
import 'package:guardian_new/stage_content.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final hero in HeroClass.values) {
    test(
      'reset refunds only investments once for $hero and preserves equipment',
      () {
        final p = Progress(heroClass: hero)..gold = 200;
        p.awardSkillResetTicket(WorldStage.forest);
        p.gainXp(1000);
        final basic = hero == HeroClass.warrior ? 'cleave' : 'firebolt';
        final starter = hero == HeroClass.warrior ? 'warcry' : 'frostNova';
        final active = hero == HeroClass.warrior ? 'whirlwind' : 'iceArmor';
        final investment = hero == HeroClass.warrior ? 4 : 3;
        for (final id in [
          basic,
          starter,
          if (hero == HeroClass.warrior) 'mastery',
          active,
        ]) {
          expect(p.learn(p.skills.firstWhere((s) => s.id == id)), true);
        }
        p.selectSkill(active);
        final points = p.skillPoints, weapon = p.weapon, kills = p.kills;
        expect(p.investedSkillPoints, investment);
        expect(p.resetSkills(), true);
        expect(p.skillPoints, points + investment);
        expect(p.gold, 200);
        expect(p.ranks, {basic: 1, starter: 1});
        expect(p.skillSlots, [starter, null, null, null]);
        expect(p.weapon, weapon);
        expect(p.kills, kills);
        expect(p.resetSkills(), false);
        expect(p.gold, 200);
        expect(p.skillPoints, points + investment);
        expect(Progress.fromSave(p.toSave())!.toSave(), p.toSave());
      },
    );
  }
  test(
    'empty investment, missing ticket, dead and disposed sessions cannot spend a reset',
    () {
      final s = Adventure(GameArt());
      s.start(TestGame());
      addTearDown(() {
        if (!s.disposed) s.dispose();
      });
      final p = s.progress..gold = 200;
      p.awardSkillResetTicket(WorldStage.forest);
      expect(s.resetSkills(), false);
      expect(p.skillResetTickets, 1);
      p.learn(p.skills.first);
      p.gold = 0;
      expect(s.resetSkills(), true);
      expect(p.skillResetTickets, 0);
      expect(p.gold, 0);
      p.learn(p.skills.first);
      p.gold = 1000000;
      final before = p.toSave();
      expect(s.resetSkills(), false);
      expect(p.toSave(), before);
      p.awardSkillResetTicket(WorldStage.sands);
      s.defeated = true;
      expect(s.resetSkills(), false);
      expect(p.skillResetTickets, 1);
      s.defeated = false;
      s.dispose();
      expect(s.resetSkills(), false);
      expect(p.skillResetTickets, 1);
      expect(p.gold, 1000000);
    },
  );
  test(
    'reset cancels queued whirlwind damage and buffs but retains cooldowns',
    () {
      final s = Adventure(GameArt());
      final game = TestGame();
      s.start(game);
      addTearDown(s.dispose);
      s.progress.gainXp(1000);
      s.progress.gold = 200;
      s.progress.awardSkillResetTicket(WorldStage.forest);
      s.progress.energy = 100;
      expect(
        s.learn(s.progress.skills.firstWhere((d) => d.id == 'mastery')),
        true,
      );
      final skill = s.progress.skills.firstWhere((d) => d.id == 'whirlwind');
      s.learn(skill);
      s.progress.selectSkill(skill.id);
      s.hero.position.setValues(6000, 4200);
      s.mobs.clear();
      final enemy = s.spawnEnemy('skeleton', const Offset(6080, 4200))!
        ..life.initial(1000);
      s.hero.skill();
      final pulse = game.added.whereType<WhirlwindPulse>().single;
      pulse.update(.05);
      final hp = enemy.life.value, cooldowns = Map.of(s.hero.cooldowns);
      s.hero.armorTime = 3;
      s.hero.frenzyTime = 5;
      s.pause();
      expect(s.resetSkills(), true);
      expect(s.hero.spin, 0);
      expect(s.hero.armorTime, 0);
      expect(s.hero.frenzyTime, 0);
      expect(s.hero.cooldowns, cooldowns);
      s.resume();
      for (var i = 0; i < 8; i++) {
        pulse.update(.05);
      }
      expect(enemy.life.value, hp);
      expect(
        s.learn(s.progress.skills.firstWhere((d) => d.id == 'mastery')),
        true,
      );
      expect(s.learn(skill), true);
      s.progress.selectSkill(skill.id);
      final energy = s.progress.energy;
      s.hero.skill();
      expect(s.progress.energy, energy);
      final restored = GameCheckpoint.capture(s)!.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.hero.cooldowns[skill.id], cooldowns[skill.id]);
    },
  );
  test(
    'reset cancels friendly projectiles and delayed meteors while hostile bolts remain',
    () {
      final s = Adventure(GameArt(), heroClass: HeroClass.mage);
      s.start(TestGame());
      addTearDown(s.dispose);
      s.hero.position.setValues(6000, 4200);
      s.mobs.clear();
      s.progress.gold = 200;
      s.progress.awardSkillResetTicket(WorldStage.forest);
      s.progress.gainXp(1000);
      s.learn(s.progress.skills.first);
      final enemy = s.spawnEnemy('goblin', const Offset(6100, 4200))!
        ..life.initial(1000);
      final bolt = ArcaneBolt(s, s.hero.body.center, 0, 300),
          meteor = MeteorFall(s, s.hero.body.center, enemy.body.center, 300);
      final hp = enemy.life.value;
      expect(s.resetSkills(), true);
      for (var i = 0; i < 20; i++) {
        bolt.update(.05);
        meteor.update(.05);
      }
      expect(enemy.life.value, hp);
      expect(bolt.resolved, true);
      expect(meteor.struck, true);
      final heroHp = s.progress.hp;
      final hostile = ShadowBolt(
        s,
        s.hero.body.center - const Offset(20, 0),
        0,
      );
      hostile.update(.05);
      expect(s.progress.hp, lessThan(heroHp));
    },
  );
  for (final size in const [Size(320, 420), Size(390, 844)]) {
    testWidgets('reset confirmation is cancellable and visible at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = Adventure(GameArt());
      s.start(TestGame());
      s.pause();
      addTearDown(s.dispose);
      s.progress.gold = 200;
      s.progress.awardSkillResetTicket(WorldStage.forest);
      s.learn(s.progress.skills.first);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: SkillsPanel(session: s, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final before = s.progress.toSave();
      await tester.tap(find.byTooltip('스킬 초기화'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('취소'));
      await tester.pumpAndSettle();
      expect(s.progress.toSave(), before);
      await tester.tap(find.byTooltip('스킬 초기화'));
      await tester.pumpAndSettle();
      final confirm = find.bySemanticsLabel('초기화권 1장 · 초기화');
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(size.height));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(s.progress.gold, 200);
      expect(s.progress.skillResetTickets, 0);
      expect(s.progress.rank('cleave'), 1);
      expect(s.progress.investedSkillPoints, 0);
      expect(tester.takeException(), null);
      semantics.dispose();
    });
  }
  testWidgets(
    'confirmation cannot run without a reset ticket even with abundant gold',
    (tester) async {
      final s = Adventure(GameArt());
      s.start(TestGame());
      s.pause();
      addTearDown(s.dispose);
      s.learn(s.progress.skills.first);
      s.progress.gold = 1000000;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: SkillsPanel(session: s, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('스킬 초기화'));
      await tester.pumpAndSettle();
      final action = tester.widget<GameAction>(
        find.byWidgetPredicate(
          (w) => w is GameAction && w.label == '초기화권 1장 · 초기화',
        ),
      );
      expect(action.onTap, null);
      expect(s.progress.gold, 1000000);
      expect(s.progress.rank('cleave'), 2);
      await tester.tap(find.bySemanticsLabel('취소'));
      await tester.pumpAndSettle();
      semantics.dispose();
    },
  );
}

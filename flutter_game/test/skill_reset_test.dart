import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skills_panel.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final hero in HeroClass.values) {
    test(
      'reset refunds only investments once for $hero and preserves equipment',
      () {
        final p = Progress(heroClass: hero)..gold = 200;
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
        expect(p.gold, 150);
        expect(p.ranks, {basic: 1, starter: 1});
        expect(p.skillSlots, [starter, null, null, null]);
        expect(p.weapon, weapon);
        expect(p.kills, kills);
        expect(p.resetSkills(), false);
        expect(p.gold, 150);
        expect(p.skillPoints, points + investment);
        expect(Progress.fromSave(p.toSave())!.toSave(), p.toSave());
      },
    );
  }
  test(
    'no investment, low gold and disposed sessions cannot charge a reset',
    () {
      final s = Adventure(GameArt());
      s.start(TestGame());
      addTearDown(() {
        if (!s.disposed) s.dispose();
      });
      s.progress.gold = 200;
      expect(s.resetSkills(), false);
      expect(s.progress.gold, 200);
      s.progress.learn(s.progress.skills.first);
      s.progress.gold = 49;
      final before = s.progress.toSave();
      expect(s.resetSkills(), false);
      expect(s.progress.toSave(), before);
      s.progress.gold = 200;
      s.dispose();
      expect(s.resetSkills(), false);
      expect(s.progress.gold, 200);
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
      final confirm = find.bySemanticsLabel('50 G · 초기화');
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(size.height));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(s.progress.gold, 150);
      expect(s.progress.rank('cleave'), 1);
      expect(s.progress.investedSkillPoints, 0);
      expect(tester.takeException(), null);
      semantics.dispose();
    });
  }
  testWidgets('confirmation cannot run when gold is insufficient', (
    tester,
  ) async {
    final s = Adventure(GameArt());
    s.start(TestGame());
    s.pause();
    addTearDown(s.dispose);
    s.learn(s.progress.skills.first);
    s.progress.gold = 49;
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
      find.byWidgetPredicate((w) => w is GameAction && w.label == '50 G · 초기화'),
    );
    expect(action.onTap, null);
    expect(s.progress.gold, 49);
    expect(s.progress.rank('cleave'), 2);
    await tester.tap(find.bySemanticsLabel('취소'));
    await tester.pumpAndSettle();
    semantics.dispose();
  });
}

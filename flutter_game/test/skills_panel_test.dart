import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skills_panel.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (size, hero) in [
    (const Size(390, 844), HeroClass.warrior),
    (const Size(320, 640), HeroClass.mage),
    (const Size(320, 420), HeroClass.warrior),
    (const Size(844, 390), HeroClass.mage),
  ]) {
    testWidgets('mobile skill learning, swapping and fixed actions at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = Adventure(GameArt(), heroClass: hero);
      s.start(TestGame());
      s.pause();
      addTearDown(s.dispose);
      s.progress.gainXp(1000);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: SkillsPanel(session: s, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final skills = hero == HeroClass.warrior
          ? ['whirlwind', 'frenzy', 'seismicSlam']
          : ['iceArmor', 'chainLightning', 'meteor'];
      final scroll = find
          .descendant(
            of: find.byType(GridView),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final id in skills) {
        final skill = s.progress.skills.firstWhere((v) => v.id == id);
        final card = find.bySemanticsLabel('스킬 보기 · ${skill.name} · 0 등급');
        await tester.scrollUntilVisible(card, 100, scrollable: scroll);
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
        final learn = find.bySemanticsLabel('${skill.name} 습득 · 1P');
        expect(tester.getRect(learn).bottom, lessThanOrEqualTo(size.height));
        await tester.tap(learn);
        await tester.pumpAndSettle();
        expect(s.progress.rank(id), 1);
        expect(s.progress.skillSlots.contains(id), true);
        if (id == skills.last) {
          s.hero.cooldowns[id] = 4;
          final oldPrimary = s.progress.selectedSkill;
          await tester.tap(find.bySemanticsLabel('${skill.name} · 슬롯 1 지정'));
          await tester.pumpAndSettle();
          expect(s.progress.selectedSkill, id);
          expect(s.progress.skillSlots.contains(oldPrimary), true);
          expect(s.hero.cooldowns[id], 4);
          final upgrade = find.bySemanticsLabel('${skill.name} 강화 · 1P');
          final before = tester.getRect(upgrade);
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -150),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(upgrade), before);
          await tester.tap(upgrade);
          await tester.pumpAndSettle();
          expect(s.progress.rank(id), 2);
        }
        await tester.tap(find.byTooltip('스킬 상세 닫기'));
        await tester.pumpAndSettle();
      }
      for (var slot = 0; slot < 4; slot++) {
        final name = s.progress.skillAt(slot)!.name;
        final rect = tester.getRect(
          find.bySemanticsLabel('전투 슬롯 ${slot + 1} · $name'),
        );
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThan(size.height));
      }
      expect(tester.takeException(), null);
      semantics.dispose();
    });
  }
  testWidgets('locked skills and empty points cannot spend progression', (
    tester,
  ) async {
    final s = Adventure(GameArt(), heroClass: HeroClass.mage);
    s.start(TestGame());
    s.pause();
    addTearDown(s.dispose);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: SkillsPanel(session: s, onClose: () {}),
      ),
    );
    await tester.pumpAndSettle();
    final meteor = find.bySemanticsLabel('스킬 보기 · 유성 낙하 · 0 등급');
    await tester.scrollUntilVisible(
      meteor,
      100,
      scrollable: find
          .descendant(
            of: find.byType(GridView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(meteor);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<GameAction>(
            find.byWidgetPredicate(
              (w) => w is GameAction && w.label == 'Lv.4 필요',
            ),
          )
          .onTap,
      null,
    );
    expect(s.progress.skillPoints, 1);
    expect(s.progress.rank('meteor'), 0);
    await tester.tap(find.byTooltip('스킬 상세 닫기'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(GridView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('스킬 보기 · 화염탄 · 1 등급'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('화염탄 강화 · 1P'));
    await tester.pumpAndSettle();
    expect(s.progress.skillPoints, 0);
    expect(s.progress.rank('firebolt'), 2);
    expect(
      tester
          .widget<GameAction>(
            find.byWidgetPredicate(
              (w) => w is GameAction && w.label == '포인트가 없습니다',
            ),
          )
          .onTap,
      null,
    );
    expect(tester.takeException(), null);
    semantics.dispose();
  });
}

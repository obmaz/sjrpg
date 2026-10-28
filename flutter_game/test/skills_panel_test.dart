import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/panel_controls.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree.dart';
import 'package:guardian_new/skills_panel.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> reveal(WidgetTester tester, Finder target) async {
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
  }

  for (final (size, hero) in [
    (const Size(390, 844), HeroClass.warrior),
    (const Size(320, 640), HeroClass.mage),
    (const Size(320, 420), HeroClass.warrior),
    (const Size(844, 390), HeroClass.mage),
    (const Size(667, 375), HeroClass.mage),
    (const Size(600, 320), HeroClass.warrior),
  ]) {
    testWidgets('mobile tree investment, loadout and fixed actions at $size', (
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
      final p = s.progress;
      p.gainXp(4000);
      if (hero == HeroClass.warrior) p.level = 40;
      p.skillPoints = 30;
      for (final id
          in (hero == HeroClass.warrior ? ['swordMastery'] : ['warmth'])) {
        expect(p.learn(p.skills.firstWhere((skill) => skill.id == id)), true);
      }
      if (hero == HeroClass.mage) {
        for (final id in ['arcaneMastery', 'firebolt', 'emberFocus']) {
          expect(p.learn(p.skills.firstWhere((skill) => skill.id == id)), true);
        }
      }
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: SkillsPanel(session: s, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final footer = find.bySemanticsLabel('모험 계속하기');
      final footerRect = tester.getRect(footer);
      final treeRect = tester.getRect(find.byType(SkillTree));
      final firstSlot = tester.getRect(
        find.bySemanticsLabel(RegExp('전투 슬롯 1 ·')),
      );
      final resetRect = tester.getRect(find.byTooltip('스킬 초기화'));
      final infoRect = tester.getRect(find.byTooltip('스킬 설명과 배치'));
      expect(firstSlot.left, closeTo(treeRect.left, .01));
      expect(footerRect.right, closeTo(treeRect.right, .01));
      if (size.height >= 500 || size.width < 600) {
        expect(resetRect.left, closeTo(treeRect.left, .01));
        expect(infoRect.right, closeTo(treeRect.right, .01));
      }
      final schoolHeader = find.byKey(const ValueKey('skill-school-header'));
      final schoolRect = schoolHeader.evaluate().isEmpty
          ? null
          : tester.getRect(schoolHeader);
      final ids = hero == HeroClass.warrior
          ? ['bash', 'doubleSwing', 'stun']
          : ['iceArmor', 'chainLightning', 'meteor'];
      for (final id in ids) {
        final skill = p.skills.firstWhere((v) => v.id == id);
        final node = find.bySemanticsLabel('스킬 보기 · ${skill.name} · 0 등급');
        await reveal(tester, node);
        if (schoolRect != null) {
          final nextHeader = tester.getRect(schoolHeader);
          expect(nextHeader.top, schoolRect.top);
          expect(nextHeader.height, schoolRect.height);
          if (hero == HeroClass.mage) expect(nextHeader, schoolRect);
        }
        await tester.tap(node);
        await tester.pumpAndSettle();
        final learn = find.bySemanticsLabel('${skill.name} 습득 · 1P');
        expect(tester.getRect(learn).bottom, lessThanOrEqualTo(size.height));
        expect(tester.getRect(footer), footerRect);
        await tester.tap(learn);
        await tester.pumpAndSettle();
        expect(p.rank(id), 1);
        expect(p.skillSlots.contains(id), true);
        expect(find.byTooltip('스킬 상세 닫기'), findsNothing);
        if (id == ids.last) {
          s.hero.cooldowns[id] = 4;
          final oldPrimary = p.selectedSkill;
          await tester.tap(find.byTooltip('스킬 설명과 배치'));
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('${skill.name} · 슬롯 1 지정'));
          await tester.pumpAndSettle();
          expect(p.selectedSkill, id);
          expect(p.skillSlots.contains(oldPrimary), true);
          expect(s.hero.cooldowns[id], 4);
          final upgrade = find.bySemanticsLabel('${skill.name} 강화 · 1P').last;
          final before = tester.getRect(upgrade);
          await tester.drag(
            find.byType(SingleChildScrollView).last,
            const Offset(0, -150),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(upgrade), before);
          await tester.tap(upgrade);
          await tester.pumpAndSettle();
          expect(p.rank(id), 2);
          await tester.tap(find.byTooltip('스킬 상세 닫기'));
          await tester.pumpAndSettle();
        }
      }
      for (var slot = 0; slot < 4; slot++) {
        final name = p.skillAt(slot)!.name;
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
  testWidgets(
    'level and prerequisite locks cannot spend points; base upgrades spend exactly one',
    (tester) async {
      final s = Adventure(GameArt(), heroClass: HeroClass.mage);
      s.start(TestGame());
      s.progress.skillPoints = 1;
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
      await reveal(tester, meteor);
      await tester.tap(meteor);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GameAction>(find.widgetWithText(GameAction, 'Lv.4 필요'))
            .onTap,
        null,
      );
      expect(s.progress.skillPoints, 1);
      expect(s.progress.rank('meteor'), 0);
      final base = find.bySemanticsLabel('스킬 보기 · 마력탄 · 1 등급');
      await reveal(tester, base);
      await tester.tap(base);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('마력탄 강화 · 1P'));
      await tester.pumpAndSettle();
      expect(s.progress.skillPoints, 0);
      expect(s.progress.rank('firebolt'), 2);
      expect(
        tester
            .widget<GameAction>(find.widgetWithText(GameAction, '포인트 없음'))
            .onTap,
        null,
      );
      expect(tester.takeException(), null);
      semantics.dispose();
    },
  );
}

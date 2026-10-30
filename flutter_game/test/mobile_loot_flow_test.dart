import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_numbers.dart';
import 'package:guardian_new/equipment_panel.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in const [Size(320, 420), Size(390, 844), Size(844, 390)]) {
    testWidgets(
      'new loot is directly visible and equippable in one tap at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = Adventure(GameArt())
          ..start(TestGame())
          ..pause();
        addTearDown(s.dispose);
        final gear = s.progress.createGear(
          gearById('longsword'),
          rarity: Rarity.rare,
          power: 3,
        );
        expect(s.progress.collect(gear), true);
        await tester.pumpWidget(
          MaterialApp(
            home: EquipmentPanel(session: s, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        final tab = tester.widget<Semantics>(find.bySemanticsLabel('신규'));
        expect(tab.properties.selected, true);
        final row = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label?.startsWith('보관 장비 · ') ?? false) &&
              (w.properties.label?.contains(gear.name) ?? false),
        );
        expect(
          tester.widget<Semantics>(row).properties.hint,
          contains('현재 초당 피해'),
        );
        final equip = find.byKey(ValueKey('equip-${gear.serial}'));
        final box = tester.getRect(equip),
            footer = tester.getRect(find.bySemanticsLabel('모험 계속하기'));
        expect(box.top, greaterThan(0));
        expect(box.bottom, lessThan(footer.top));
        await tester.tap(equip);
        await tester.pumpAndSettle();
        expect(s.progress.isEquipped(gear), true);
        expect(s.progress.unseenGear.contains(gear.serial), false);
        expect(
          find.byKey(ValueKey('equip-${gear.serial}')),
          findsOneWidget,
          reason: 'read items stay in this visit so controls do not jump',
        );
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), null);
      },
    );
  }
  for (final hero in HeroClass.values) {
    testWidgets('$hero training quote is accessible and matches the purchase', (
      tester,
    ) async {
      final s = Adventure(GameArt(), heroClass: hero)
        ..start(TestGame())
        ..pause();
      addTearDown(s.dispose);
      s.progress.gainXp(8000);
      final mastery = s.progress.skills.firstWhere(
        (skill) =>
            skill.id ==
            (hero == HeroClass.warrior ? 'swordMastery' : 'fireMastery'),
      );
      while (s.progress.level < mastery.requiredLevelForRank(2)) {
        s.progress.gainXp(s.progress.nextLevelXp - s.progress.xp);
      }
      expect(s.progress.learn(mastery), true);
      expect(s.progress.learn(mastery), true);
      s.progress.gold = 1000;
      final quoted = s.progress.attackTrainingGain,
          before = s.progress.swordDamage,
          spellBefore = s.progress.basicDamage;
      await tester.pumpWidget(
        MaterialApp(
          home: EquipmentPanel(session: s, startInShop: true, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('축복'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          RegExp('^공격력 \\+${RegExp.escape(CombatNumbers.stat(quoted))} · 수련'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('무기 강화 구매 · 45 골드'));
      await tester.pumpAndSettle();
      expect(s.progress.swordDamage - before, closeTo(quoted, .000001));
      if (hero == HeroClass.mage) {
        expect(
          s.progress.basicDamage,
          spellBefore,
          reason:
              'weapon training improves normal staff contact, not original elemental spell damage',
        );
      }
      expect(
        Progress.fromSave(s.progress.toSave())!.swordDamage,
        s.progress.swordDamage,
      );
      expect(tester.takeException(), null);
    });
  }
}

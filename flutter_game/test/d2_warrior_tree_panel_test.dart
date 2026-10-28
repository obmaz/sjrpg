import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_tree.dart';
import 'package:guardian_new/skills_panel.dart';
import 'support/test_game.dart';

void main() {
  testWidgets(
    'a fresh warrior can discover and learn Sprint from the bonus section',
    (tester) async {
      final session = Adventure(GameArt())..start(TestGame());
      session.pause();
      addTearDown(session.dispose);
      final p = session.progress;
      p.level = 8;
      p.skillPoints = 10;
      expect(
        p.learn(p.skills.firstWhere((skill) => skill.id == 'shout')),
        true,
      );
      final points = p.skillPoints, slots = p.skillSlots.toList();
      await tester.pumpWidget(
        MaterialApp(
          home: SkillsPanel(session: session, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('skill-school-tab-3')));
      await tester.pumpAndSettle();
      final sprint = find.byKey(const ValueKey('skill-node-battleSprint'));
      expect(sprint, findsOneWidget);
      await Scrollable.ensureVisible(tester.element(sprint), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(sprint);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('전투 질주 습득 · 1P'));
      await tester.pumpAndSettle();
      expect(p.rank('battleSprint'), 1);
      expect(p.skillPoints, points - 1);
      expect(p.skillSlots, slots);
      expect(p.mobilityDuration, greaterThan(0));
      expect(tester.takeException(), null);
    },
  );
  testWidgets(
    'mage tab navigation preserves both original Meteor prerequisites',
    (tester) async {
      final session = Adventure(GameArt(), heroClass: HeroClass.mage)
        ..start(TestGame());
      session.pause();
      addTearDown(session.dispose);
      final p = session.progress
        ..level = 40
        ..skillPoints = 40;
      for (final id in ['fireball', 'inferno', 'blaze']) {
        expect(p.learn(p.skills.firstWhere((s) => s.id == id)), isTrue);
      }
      final meteorSkill = p.skills.firstWhere((s) => s.id == 'meteor');
      await tester.pumpWidget(
        MaterialApp(
          home: SkillsPanel(session: session, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> selectNode(int school, String id) async {
        await tester.tap(find.byKey(ValueKey('skill-school-tab-$school')));
        await tester.pumpAndSettle();
        final target = find.byKey(ValueKey('skill-node-$id'));
        await Scrollable.ensureVisible(tester.element(target), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await selectNode(2, 'meteor');
      expect(
        find.bySemanticsLabel('${meteorSkill.name} 선행 필요'),
        findsOneWidget,
      );
      expect(p.rank('meteor'), 0);
      await selectNode(0, 'frozenArmor');
      final armor = p.skills.firstWhere((s) => s.id == 'frozenArmor');
      await tester.tap(find.bySemanticsLabel('${armor.name} 습득 · 1P'));
      await tester.pumpAndSettle();
      await selectNode(2, 'meteor');
      expect(
        find.bySemanticsLabel('${meteorSkill.name} 선행 필요'),
        findsOneWidget,
      );
      await selectNode(2, 'firewall');
      final wall = p.skills.firstWhere((s) => s.id == 'firewall');
      await tester.tap(find.bySemanticsLabel('${wall.name} 습득 · 1P'));
      await tester.pumpAndSettle();
      await selectNode(2, 'meteor');
      await tester.tap(find.bySemanticsLabel('${meteorSkill.name} 습득 · 1P'));
      await tester.pumpAndSettle();
      expect(p.rank('meteor'), 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [const Size(320, 640), const Size(844, 390)]) {
    testWidgets(
      'warrior school tabs replace horizontal panning and preserve the header at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = Adventure(GameArt())..start(TestGame());
        session.pause();
        addTearDown(session.dispose);
        final vertical = ScrollController();
        addTearDown(vertical.dispose);
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkillTree(
                session: session,
                controller: vertical,
                focused: null,
                onFocus: (skill) => selected = skill.id,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final header = find.byKey(const ValueKey('skill-school-header'));
        final headerTop = tester.getTopLeft(header).dy;
        expect(find.byKey(const ValueKey('skill-node-cleave')), findsNothing);
        expect(
          find.byKey(const ValueKey('skill-tree-horizontal')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('skill-school-tab-2')));
        await tester.pumpAndSettle();
        final warcry = find.byKey(const ValueKey('skill-node-berserk'));
        await Scrollable.ensureVisible(tester.element(warcry), alignment: .5);
        await tester.pumpAndSettle();
        expect(tester.getRect(warcry).left, greaterThanOrEqualTo(0));
        expect(tester.getRect(warcry).right, lessThanOrEqualTo(size.width));
        expect(tester.getTopLeft(header).dy, headerTop);
        expect(vertical.offset, greaterThan(0));
        await tester.tap(warcry);
        expect(selected, 'berserk');
        await tester.tap(find.byKey(const ValueKey('skill-school-tab-3')));
        await tester.pumpAndSettle();
        final shadow = find.byKey(const ValueKey('skill-node-shadowAssault'));
        await Scrollable.ensureVisible(tester.element(shadow), alignment: .5);
        await tester.pumpAndSettle();
        expect(tester.getRect(shadow).width, greaterThanOrEqualTo(44));
        expect(tester.getRect(shadow).bottom, lessThanOrEqualTo(size.height));
        expect(tester.getTopLeft(header).dy, headerTop);
        expect(tester.takeException(), null);
      },
    );
  }
}

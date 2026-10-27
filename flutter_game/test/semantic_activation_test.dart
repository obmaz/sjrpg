import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/class_selection.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/quest_guide.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/rpg_widgets.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt art;
  setUpAll(() async => art = await GameArt.load());
  tearDownAll(() {
    for (final shader in art.materials) {
      shader.dispose();
    }
    for (final image in art.images.values) {
      image.dispose();
    }
  });

  Future<void> activate(WidgetTester tester, String label) async {
    final node = tester.getSemantics(find.bySemanticsLabel(label));
    expect(
      node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      true,
      reason: '$label must expose activation to accessibility services',
    );
    tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
      node.id,
      ui.SemanticsAction.tap,
    );
    await tester.pump();
  }

  testWidgets('semantic activation selects the class used for a new game', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      HeroClass? started;
      await tester.pumpWidget(
        MaterialApp(
          home: ClassSelection(art: art, onBegin: (hero) => started = hero),
        ),
      );
      await activate(tester, '마법사 선택');
      expect(
        tester
            .widget<Semantics>(find.bySemanticsLabel('마법사 선택'))
            .properties
            .selected,
        true,
      );
      await activate(tester, '마법사로 모험 시작');
      expect(started, HeroClass.mage);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'semantic field actions open menus, follow guidance and use potions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final s = Adventure(art)..start(TestGame());
        addTearDown(s.dispose);
        s.progress.hp = 60;
        s.progress.energy = 10;
        s.syncLife();
        var menus = 0, guides = 0, uses = 0;
        const guide = QuestGuide(
          '숲의 현자',
          '다음 의뢰를 확인하세요.',
          QuestGuideAction.journal,
          '여정 보기',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MenuButton(
                    art: art,
                    sprite: 'touchInventory',
                    label: '가방',
                    onTap: () => menus++,
                  ),
                  SizedBox(
                    height: 92,
                    child: NearbyQuestCard(guide, onTap: () => guides++),
                  ),
                  PotionBelt(s, onUse: () => uses++),
                ],
              ),
            ),
          ),
        );
        await activate(tester, '가방');
        expect(menus, 1);
        await activate(
          tester,
          '${guide.title}. ${guide.message} ${guide.button}',
        );
        expect(guides, 1);
        final healing = s.progress.healingPotions;
        await activate(tester, '치유 물약 $healing개');
        expect(s.progress.healingPotions, healing - 1);
        expect(s.progress.hp, greaterThan(60));
        final energy = s.progress.energyPotions;
        await activate(tester, '분노 물약 $energy개');
        expect(s.progress.energyPotions, energy - 1);
        expect(s.progress.energy, greaterThan(10));
        expect(uses, 2, reason: 'semantic potion use also restores game focus');
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

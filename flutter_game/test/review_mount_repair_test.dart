import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_panels.dart';
import 'package:guardian_new/panel_controls.dart';
import 'support/test_game.dart';

void main() {
  testWidgets(
    'settings disable stable-only horse repair and explain recovery',
    (tester) async {
      final s = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(s.dispose);
      final horse = withOwnedMounts(
        s,
      ).mounts.firstWhere((m) => m.def.id == 'horse');
      horse.at = s.hero.body.center;
      horse.state.hits = 1;
      horse.durability = 80;
      s.riding = horse;
      s.progress.gold = 1000;
      s.pause();
      expect(s.mountRepairRequiresMerchant, true);
      expect(s.canRepairMount, false);
      await tester.pumpWidget(
        MaterialApp(
          home: AdventurePanel(
            session: s,
            name: 'settings',
            onClose: () {},
            onRestart: () {},
          ),
        ),
      );
      final action = tester
          .widgetList<GameAction>(find.byType(GameAction))
          .singleWhere((w) => w.label.startsWith('탈것 보수'));
      expect(action.onTap, null);
      expect(find.text('말의 피격 회복·쓰러짐 보수는 탈것 상인에게 맡기세요.'), findsOneWidget);
      expect(s.repairMount(), false);
      expect(s.progress.gold, 1000);
      final at = s.mountMerchantAt;
      s.hero.position.setValues(at.dx - 14, at.dy - 12);
      expect(s.canRepairMount, true);
      expect(s.repairMount(), true);
      expect(horse.hits, 0);
      expect(horse.durability, 100);
      expect(s.progress.gold, 988);
      expect(tester.takeException(), null);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/quest_guide.dart';
import 'package:guardian_new/world_map.dart';
import 'package:guardian_new/world_model.dart';
import 'support/forest_quest_flow.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session() {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    return s;
  }

  test(
    'distant dead enemies never poison checkpoint data or duplicate dormant records',
    () {
      final s = session(), mob = s.mobs.first;
      mob.life.remove(mob.life.value);
      mob.position.setValues(18000, 18000);
      final survivors = s.mobs.where((m) => !m.isDead).length;
      s.waveTime = 100;
      s.tick(.05);
      s.tick(.05);
      expect(s.dormantEnemies, isEmpty);
      expect(GameCheckpoint.capture(s), isNotNull);
      expect(
        (GameCheckpoint.capture(s)!.data['enemies'] as List).length,
        survivors,
      );
    },
  );
  test(
    'riding near complete or locked quest sites retains the dismount action',
    () {
      final s = session();
      s.mobs.clear();
      completeForestQuest(s, 'roots');
      approachForestNpc(s, 'elin');
      s.riding = withOwnedMounts(s).mounts.first;
      expect(s.nearbyQuestGuide!.action, QuestGuideAction.dismount);
      expect(s.nearbyAction, NearbyAction.dismount);
      final sands = inCombatField(Adventure(GameArt(), stage: WorldStage.sands))
        ..start(TestGame());
      addTearDown(sands.dispose);
      final q = timeCommissions.first;
      sands.hero.position.setValues(q.site.at.dx, q.site.at.dy + 55);
      sands.riding = withOwnedMounts(sands).mounts.first;
      expect(sands.nearbyQuestGuide, null);
      expect(sands.nearbyAction, NearbyAction.dismount);
      sands.timePath = TimePath.past;
      sands.acceptedCommission = q.id;
      expect(
        sands.nearbyQuestGuide,
        null,
        reason: 'a kill-gated active commission must also retain dismount',
      );
    },
  );
  test(
    'potion feedback reports restored life and resource instead of bottle capacity',
    () {
      final s = session();
      s.progress.hp = s.progress.maxHp - 4;
      s.potion();
      expect(s.texts.last.label, '+4,000 생명');
      s.progress.energy = s.progress.maxEnergy - 7;
      s.potion(energy: true);
      expect(s.texts.last.label, '+70 분노');
    },
  );
  testWidgets('zoom out never jumps inward from a short-screen overview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = session()..pause();
    await tester.pumpWidget(
      MaterialApp(
        home: ExpandedWorldMap(session: s, onClose: () {}),
      ),
    );
    await tester.pump();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final before = viewer.transformationController!.value.storage[0];
    expect(before, lessThan(.15));
    await tester.tap(find.bySemanticsLabel('지도 축소'));
    await tester.pump();
    final after = viewer.transformationController!.value.storage[0];
    expect(after, lessThanOrEqualTo(before));
    expect(after, greaterThan(0));
    expect(viewer.minScale, lessThanOrEqualTo(before));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/quest_giver.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final path in TimePath.values) {
    test('${path.name} starts only with the matching nearby quest giver', () {
      final session = Adventure(GameArt(), stage: WorldStage.sands)
        ..start(TestGame());
      addTearDown(session.dispose);
      final own = timeCommissions.firstWhere((q) => q.path == path);
      final other = timeCommissions.firstWhere((q) => q.path != path);
      inCombatField(session);
      expect(session.nearbyTimeGiver, null);
      expect(
        session.acceptCommission(own),
        false,
        reason: 'the journal cannot preselect a branch',
      );
      expect(session.visibleSites, isEmpty);
      final giver = timeQuestGivers.firstWhere((g) => g.path == path);
      final at = session.world.questGiverAt(path);
      final actor = QuestGiver(session, giver);
      // Body-center arithmetic may round fractional authored world anchors.
      expect(
        (Offset(
                  actor.position.x + actor.size.x / 2,
                  actor.position.y + actor.size.y / 2,
                ) -
                at)
            .distance,
        lessThan(.001),
      );
      session.hero.position.setValues(at.dx - 14, at.dy - 12);
      expect(session.nearbyTimeGiver, giver);
      expect(session.acceptCommission(other), false);
      expect(session.acceptCommission(own), true);
      expect(session.world.stage, WorldStage.sands);
      expect(session.timePath, path);
      expect(
        session.visibleSites.every((s) => s.id.startsWith(path.name)),
        true,
      );
      final saved = GameCheckpoint.capture(session)!;
      final restored = saved.restore(GameArt())..start(TestGame());
      addTearDown(restored.dispose);
      expect(restored.timePath, path);
      expect(restored.acceptedCommission, own.id);
      final wrong = timeQuestGivers.firstWhere((g) => g.path != path);
      final wrongAt = restored.world.questGiverAt(wrong.path);
      final wrongActor = QuestGiver(restored, wrong);
      expect(
        (Offset(
                  wrongActor.position.x + wrongActor.size.x / 2,
                  wrongActor.position.y + wrongActor.size.y / 2,
                ) -
                wrongAt)
            .distance,
        lessThan(.001),
      );
      restored.hero.position.setValues(wrongAt.dx - 14, wrongAt.dy - 12);
      expect(restored.nearbyTimeGiver, wrong);
      expect(restored.acceptCommission(other), false);
      expect(restored.timePath, path);
      restored.cleansedSites.add(own.id);
      restored.acceptedCommission = null;
      inCombatField(restored);
      expect(restored.nearbyTimeGiver, isNull);
      final next = timeCommissions.firstWhere(
        (q) => q.path == path && q.step == 1,
      );
      expect(
        restored.acceptCommission(next),
        true,
        reason: 'later instructions continue remotely from the same giver',
      );
    });
  }
}

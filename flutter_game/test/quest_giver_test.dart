import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
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
      expect(session.nearbyTimeGiver, null);
      expect(
        session.acceptCommission(own),
        false,
        reason: 'the journal cannot preselect a branch',
      );
      expect(session.visibleSites, isEmpty);
      final giver = timeQuestGivers.firstWhere((g) => g.path == path);
      session.hero.position.setValues(giver.at.dx - 14, giver.at.dy - 12);
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
      restored.hero.position.setValues(wrong.at.dx - 14, wrong.at.dy - 12);
      expect(restored.acceptCommission(other), false);
      expect(restored.timePath, path);
      restored.cleansedSites.add(own.id);
      restored.acceptedCommission = null;
      restored.hero.position.setValues(6000, 4200);
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

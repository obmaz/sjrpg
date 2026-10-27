import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/quest_guide.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'continue exploring retains finite normal packs and never resummons the defeated boss',
    () {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      s.cleansedSites.addAll(s.world.sites.map((q) => q.id));
      s.progress.kills = 120;
      s.progress.bossDefeated = true;
      s.completeStageIfReady();
      expect(s.won, true);
      s.spawnPack();
      expect(s.living, 0);
      s.continueExploring();
      s.spawnPack();
      expect(s.living, greaterThan(0));
      final area = s.encounterAreas[s.encounterKey]!;
      for (var i = 0; i < 3; i++) {
        s.mobs.clear();
        s.spawnPack();
      }
      expect(area.waves, 3);
      expect(s.living, 0);
      s.hero.position.setValues(area.stone.dx - 14, area.stone.dy - 12);
      for (var i = 0; i < 3; i++) {
        expect(s.strikeEncounterStone(150), true);
      }
      expect(area.waves, 0);
      s.spawnPack();
      expect(s.living, greaterThan(0));
      final mob = s.mobs.first;
      s.hit(mob, 100000, Offset.zero);
      expect(s.won, false);
      expect(s.stageCleared, true);
      s.tick(.05);
      expect(s.mobs.any((m) => m.boss), false);
      final restored = GameCheckpoint.capture(s)!.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.stageCleared, true);
      expect(restored.won, false);
    },
  );
  for (final path in TimePath.values) {
    test(
      'convergence $path ending does not promise a nonexistent next chapter',
      () {
        final s = Adventure(GameArt(), stage: WorldStage.convergence)
          ..start(TestGame());
        addTearDown(s.dispose);
        s.timePath = path;
        s.hero.position.setValues(
          s.world.elderAt.dx - 14,
          s.world.elderAt.dy - 12,
        );
        expect(s.acceptChapterContract(), true);
        s.cleansedSites.addAll(s.world.sites.map((q) => q.id));
        s.progress.bossDefeated = true;
        s.won = true;
        expect(s.mainQuestNext, isNot(contains('다음 모험')));
        s.continueExploring();
        expect(s.notice, isNot(contains('다음 의뢰')));
      },
    );
  }
}

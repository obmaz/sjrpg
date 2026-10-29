import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/level_up_effect.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'accepted XP triggers a bounded celebration that follows, pauses and ends',
    () {
      final game = TestGame(), session = inCombatField(Adventure(GameArt()));
      session.start(game);
      addTearDown(session.dispose);
      session.mobs.clear();
      session.progress.xp = session.progress.nextLevelXp - 1;
      final target = session.spawnEnemy(
        'goblin',
        session.hero.body.center + const Offset(70, 0),
      )!;
      session.hit(target, target.life.max + 1, Offset.zero);
      final effect = game.added.whereType<LevelUpEffect>().single;
      expect(session.progress.level, 2);
      expect(effect.priority, lessThan(session.hero.priority));
      session.hero.position.x += 20;
      effect.update(.05);
      expect(effect.position.toOffset(), session.hero.body.bottomCenter);
      session.pause();
      effect.update(.05);
      expect(effect.age, .05);
      session.resume();
      for (var i = 0; i < 40; i++) {
        effect.update(.05);
      }
      expect(effect.finished, isTrue);
      expect(effect.age, LevelUpEffect.duration);
    },
  );
}

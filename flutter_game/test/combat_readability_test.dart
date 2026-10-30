import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'critical feedback stays damage, does not multiply damage twice, and shares its bounded text pool',
    () {
      final s = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(s.dispose);
      final mob = s.spawnEnemy(
        'goblin',
        s.hero.body.center + const Offset(90, 0),
      )!;
      mob.life.initial(10000);
      final before = mob.life.value;
      expect(s.hit(mob, 24, Offset.zero, critical: true), true);
      expect(mob.life.value, closeTo(before - 24, 1e-8));
      final text = s.texts.last;
      expect(text.label, '24');
      expect(text.critical, true);
      expect(text.isReward, false);
      expect(text.textSize, 32);
      expect(
        text.combatBounds.height,
        greaterThanOrEqualTo(text.textSize + 17),
      );
      for (var i = 0; i < 25; i++) {
        expect(s.hit(mob, 1, Offset.zero, critical: i.isEven), true);
      }
      expect(s.texts.where((t) => !t.isReward).length, 1);
      expect(mob.life.value, closeTo(before - 49, 1e-8));
      for (var i = 0; i < s.texts.length; i++) {
        for (var j = i + 1; j < s.texts.length; j++) {
          expect(
            s.texts[i].combatBounds.overlaps(s.texts[j].combatBounds),
            false,
          );
        }
      }
    },
  );
  test(
    'rarity light stays narrow, grows by rarity, and its bounds include the full pillar',
    () {
      final s = Adventure(GameArt());
      addTearDown(s.dispose);
      var lastHeight = 0.0;
      for (final rarity in [Rarity.magic, Rarity.rare, Rarity.unique]) {
        final item = s.progress.createGear(gearById('axe'), rarity: rarity);
        final drop = GroundLoot(s, item, const Offset(500, 500));
        expect(drop.effectBounds.width, 36);
        expect(drop.effectBounds.height, greaterThan(lastHeight));
        expect(drop.effectBounds.bottom, 508);
        lastHeight = drop.effectBounds.height;
      }
    },
  );
}

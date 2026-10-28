import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/player_afflictions.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final keyboard in [false, true]) {
    for (final mounted in [false, true]) {
      test(
        'IDLE ${keyboard ? 'keyboard' : 'touch'} cancellation during root cannot move after release ${mounted ? 'mounted' : 'on foot'}',
        () {
          final s = inCombatField(Adventure(GameArt()))..start(TestGame());
          s.mobs.clear();
          addTearDown(s.dispose);
          if (mounted) {
            final mount = withOwnedMounts(
              s,
            ).mounts.firstWhere((mount) => mount.def.id == 'horse');
            mount.at = s.hero.body.center;
            expect(s.boardNearbyMount(), true);
          }
          s.afflictions.apply(PlayerStatus.root);
          s.hero.onJoystickChangeDirectional(
            JoystickDirectionalEvent(
              directional: JoystickMoveDirectional.MOVE_RIGHT,
              intensity: 1,
              isKeyboard: keyboard,
            ),
          );
          s.hero.update(.05);
          expect(s.hero.velocity.x, greaterThan(0));
          final at = s.hero.position.clone(), condition = s.riding?.durability;
          s.hero.onJoystickChangeDirectional(
            JoystickDirectionalEvent(
              directional: JoystickMoveDirectional.IDLE,
              isKeyboard: keyboard,
            ),
          );
          s.tick(1.5);
          s.hero.update(0);
          s.hero.update(.05);
          expect(
            s.hero.position,
            at,
            reason:
                'released velocity must not survive until the first unrooted movement step',
          );
          expect(s.hero.velocity.isZero(), true);
          if (mounted) expect(s.riding!.durability, condition);
        },
      );
    }
  }
}

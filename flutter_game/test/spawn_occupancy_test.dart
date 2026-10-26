import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a boss relocated out of the peace zone cannot appear on the hero', () {
    final s = Adventure(GameArt())..start(TestGame());
    addTearDown(s.dispose);
    const size = Size(48, 40);
    final desired = s.world.sanctuary.center - const Offset(24, 20);
    final first = s.world.spawnNear(desired, size, avoidSanctuary: true)!;
    s.hero.position.setValues(first.dx + 10, first.dy + 8);
    final boss = s.spawnEnemy('golem', desired, boss: true)!;
    expect(boss.body.overlaps(s.hero.body), false);
    expect(s.world.sanctuary.protects(boss.body), false);
  });
  test(
    'a crowded spawn searches for a free body and never returns occupied fallback',
    () {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      const desired = Offset(6000, 4200), size = Size(24, 22);
      final first = s.spawnEnemy('goblin', desired)!;
      final second = s.spawnEnemy('goblin', desired)!;
      expect(second.body.overlaps(first.body), false);
      expect(second.body.overlaps(s.hero.body), false);
      expect(s.world.spawnNear(desired, size, occupied: (_) => true), null);
    },
  );
}

import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'complete village keeps ground services inside its painted safety boundary',
    () {
      final world = AdventureWorld();
      expect(world.spawn, arrival);
      expect(world.settlement.contains(world.chests.first), true);
      expect(world.merchantAt, world.authoredSettlement.merchant);
      expect(world.healAt, world.authoredSettlement.well);
      expect(world.settlement.width, greaterThan(town.width * 2));
      expect(world.settlement.contains(world.blacksmithAt), true);
      for (final at in [
        world.blacksmithAt,
        world.blacksmithAt + const Offset(0, 64),
      ]) {
        final body = Rect.fromCenter(center: at, width: 28, height: 24);
        expect(world.sanctuary.protects(body), true);
        expect(world.blocked(body), false);
      }
      for (final point in world.authoredSettlement.safeBoundary) {
        expect(
          world.sanctuary.protects(
            Rect.fromCenter(center: point, width: 28, height: 24),
          ),
          true,
          reason: 'the protected ground follows the actual village wall',
        );
      }
      // A projected roof or chimney may extend beyond the ground-level wall;
      // it remains solid artwork, without extending safety onto outside fields.
      for (final point in world.settlementCollision[1].points) {
        expect(
          world.blocked(Rect.fromCenter(center: point, width: 28, height: 24)),
          true,
          reason: 'all painted forge vertices remain physical obstacles',
        );
      }
    },
  );

  test(
    'on-foot and mounted bodies can reach the workshop from the old village',
    () {
      final world = AdventureWorld();
      final approach = world.blacksmithAt + const Offset(0, 64);
      for (final size in [Guardian.onFootSize, const Size(40, 32)]) {
        final from = world.spawnNear(arrival, size)!;
        final to = world.spawnNear(approach, size)!;
        final route = world.route(from, to, size);
        expect(route, isNotEmpty, reason: 'eastern gate must be a usable road');
        var at = from;
        for (final next in route) {
          expect(world.clearLine(at, next, size), true);
          expect(world.blocked(next & size), false);
          at = next;
        }
        expect((route.last - to).distance, lessThan(42));
      }
      final forge = world.settlementCollision[1];
      expect(
        world.blocked(
          Rect.fromCenter(center: forge.bounds.center, width: 12, height: 12),
        ),
        true,
      );
      expect(
        world.blocked(
          Rect.fromCenter(center: world.blacksmithAt, width: 28, height: 24),
        ),
        false,
        reason: 'the painted front approach remains walkable',
      );
    },
  );

  test(
    'smith is a local village service even when a panel is opened remotely',
    () {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      s.pause();
      final item = s.progress.weapon;
      expect(s.smithQuote(item), isNull);
      final at = s.world.blacksmithAt + const Offset(0, 60);
      s.hero.position.setValues(at.dx, at.dy);
      expect(s.nearbyBlacksmith, true);
      expect(s.nearbyActions, contains(NearbyAction.smith));
      expect(s.smithQuote(item), isNotNull);
      final quote = s.smithQuote(item)!;
      final gold = s.progress.gold;
      s.hero.position.setValues(6000, 4200);
      expect(s.enhanceWeapon(quote), isNull);
      expect(s.progress.gold, gold);
      final other = Adventure(GameArt(), stage: WorldStage.sands)
        ..start(TestGame());
      addTearDown(other.dispose);
      other.hero.position.setValues(at.dx, at.dy);
      expect(other.nearbyBlacksmith, false);
    },
  );

  test(
    'old saved hero and rare loot remain reachable after the forge is built',
    () {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      final covered = s.world.settlementCollision[1].bounds.center;
      final item = s.progress.createGear(
        gearById('longsword'),
        rarity: Rarity.rare,
      );
      final loot = GroundLoot(s, item, covered)..age = 19;
      s.loot.add(loot);
      final raw =
          jsonDecode(GameCheckpoint.capture(s)!.encode())
              as Map<String, dynamic>;
      raw['x'] = covered.dx;
      raw['y'] = covered.dy;
      final cp = GameCheckpoint.decode(jsonEncode(raw))!;
      final restored = cp.restore(GameArt())..start(TestGame());
      addTearDown(restored.dispose);
      expect(restored.world.blocked(restored.hero.body), false);
      expect(restored.loot.single.item.serial, item.serial);
      expect(restored.loot.single.item.toSave(), item.toSave());
      expect(restored.loot.single.age, 19);
      final at = Offset(
        restored.loot.single.position.x,
        restored.loot.single.position.y,
      );
      expect(restored.world.blocked(at & Guardian.onFootSize), false);
      final heroAt = restored.world.spawnNear(at, Guardian.onFootSize)!;
      restored.hero.position.setValues(heroAt.dx, heroAt.dy);
      restored.loot.single.tryCollect();
      expect(
        restored.progress.inventory.any((g) => g.serial == item.serial),
        true,
      );
      expect(
        restored.progress.inventory
            .where((g) => g.serial == item.serial)
            .length,
        1,
      );
    },
  );
}

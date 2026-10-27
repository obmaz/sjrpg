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

  test('village grows east while its original saved landmarks remain fixed', () {
    final world = AdventureWorld();
    expect(world.spawn, arrival);
    expect(world.chests, stageChests);
    expect(world.merchantAt, const Offset(2964, 2238));
    expect(world.healAt, const Offset(2880, 2250));
    expect(world.settlement.width, greaterThan(town.width * 2));
    expect(world.settlement.contains(world.blacksmithAt), true);
    expect(
      world.sanctuary.protects(world.blacksmithAt & const Size(28, 24)),
      true,
    );
    final forge = world.campProps.singleWhere(
      (p) => p.kind == 'blacksmith-forge',
    );
    final drawing = Rect.fromLTWH(
      forge.body.bottomCenter.dx - forge.drawSize.width / 2,
      forge.body.bottom - forge.drawSize.height,
      forge.drawSize.width,
      forge.drawSize.height,
    );
    for (final point in [
      drawing.topLeft,
      drawing.topRight,
      drawing.bottomLeft,
      drawing.bottomRight,
    ]) {
      expect(
        world.sanctuary.protects(point & const Size(1, 1)),
        true,
        reason: 'the boundary must not cut through the workshop artwork',
      );
    }

    // Every point protected by the old circle remains protected after expansion.
    const oldCenter = Offset(2880, 2144.4);
    for (final edge in [
      Offset(-360, 0),
      Offset(360, 0),
      Offset(0, -360),
      Offset(0, 360),
    ]) {
      expect(
        world.sanctuary.protects((oldCenter + edge) & const Size(1, 1)),
        true,
      );
    }
  });

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
      final forge = world.campProps.singleWhere(
        (p) => p.kind == 'blacksmith-forge',
      );
      for (final solid in forge.collisionBodies) {
        expect(world.blocked(solid.deflate(1)), true);
      }
      expect(
        world.blocked(const Rect.fromLTWH(3330, 2380, 28, 24)),
        false,
        reason: 'the visible open left approach must stay walkable',
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
      final forge = s.world.campProps.singleWhere(
        (p) => p.kind == 'blacksmith-forge',
      );
      final covered = forge.collisionBodies.first.center;
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

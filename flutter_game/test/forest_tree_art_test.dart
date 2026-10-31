import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/forest_tree_art.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'asymmetric willow canopy fades above a hero behind its outer leaves',
    () {
      final s = Adventure(GameArt());
      addTearDown(s.dispose);
      const feet = Offset(1000, 1000);
      final prop = WorldProp(
        Rect.fromCenter(
          center: feet - const Offset(0, 14),
          width: 26,
          height: 28,
        ),
        'tree',
        ForestTreeArt.drawSize(8),
        treeVariant: 8,
      );
      final tree = WoodlandProp(s, prop);
      final body = s.hero.body.size;
      final leaf = feet + const Offset(170, -80);
      s.hero.position.setValues(
        leaf.dx - body.width / 2,
        leaf.dy - body.height / 2,
      );
      expect(tree.effectBounds.contains(leaf), true);
      expect(tree.occludesHero, true);
      s.hero.position.setValues(feet.dx - body.width / 2, feet.dy + 1);
      expect(tree.occludesHero, false);
    },
  );
  test(
    'the actual forest places all nine designs with unchanged solid trunks',
    () {
      final world = AdventureWorld();
      final trees = world.props.where((p) => p.treeVariant != null).toList();
      expect(
        trees.map((p) => p.treeVariant).toSet(),
        containsAll(List.generate(9, (i) => i)),
      );
      for (final tree in trees) {
        expect(tree.kind, 'tree');
        expect(world.blocked(tree.body), true);
        expect(tree.drawSize, ForestTreeArt.drawSize(tree.treeVariant!));
      }
    },
  );
  test(
    'all nine native sprites keep measured roots and complete atlas bounds',
    () {
      expect(ForestTreeArt.frames.length, 9);
      const atlas = Rect.fromLTWH(0, 0, 1440, 1440);
      const feet = Offset(300, 400);
      for (var i = 0; i < ForestTreeArt.frames.length; i++) {
        final frame = ForestTreeArt.frames[i];
        expect(atlas.contains(frame.source.topLeft), true);
        expect(atlas.contains(frame.source.bottomRight), true);
        expect(frame.source.contains(frame.foot), true);
        expect(frame.scale, lessThan(1.3));
        expect(frame.height, [200, 300, 400][i % 3]);
        final bounds = ForestTreeArt.drawBounds(feet, i);
        expect(bounds.top, feet.dy - frame.height);
        expect(bounds.bottom, greaterThanOrEqualTo(feet.dy));
        expect(bounds.bottom - feet.dy, lessThan(8));
        final rootX =
            bounds.left + (frame.foot.dx - frame.source.left) * frame.scale;
        expect(rootX, closeTo(feet.dx, 1e-8));
        for (var j = 0; j < i; j++) {
          expect(frame.source.overlaps(ForestTreeArt.frames[j].source), false);
        }
      }
    },
  );

  test(
    'ecological masks keep open edges short and distinguish three groves',
    () {
      int choose(
        Offset at, {
        bool water = false,
        bool edge = false,
        bool transition = false,
        double depth = .8,
        double town = 9000,
      }) => ForestTreeArt.variant(
        at: at,
        worldSize: const Size(10000, 10000),
        nearWater: water,
        roadEdge: edge,
        roadTransition: transition,
        groveDepth: depth,
        townDistance: town,
      );
      expect(choose(const Offset(4000, 4000), town: 1200), 0);
      expect(choose(const Offset(4000, 4000), depth: .4), 1);
      expect(choose(const Offset(4000, 4000)), 2);
      expect(choose(const Offset(7000, 2000), edge: true), 3);
      expect(choose(const Offset(7000, 2000), transition: true), 4);
      expect(choose(const Offset(7000, 2000)), 5);
      expect(choose(const Offset(7000, 8000)), 5);
      expect(choose(const Offset(1200, 4000), water: true, edge: true), 6);
      expect(
        choose(const Offset(1200, 4000), water: true, transition: true),
        7,
      );
      expect(choose(const Offset(1200, 4000), water: true), 8);
    },
  );
}

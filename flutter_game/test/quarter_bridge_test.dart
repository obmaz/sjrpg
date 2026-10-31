import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/bridge_art.dart';
import 'package:guardian_new/bridge_rail.dart';
import 'package:guardian_new/forest_tree_art.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/village_gateway_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'oblique bridge floors carry whole bodies while front piers stay solid',
    () {
      final w = AdventureWorld();
      w.openedChests.addAll(List.generate(w.chests.length, (i) => i));
      for (final bridge in w.bridges) {
        for (final size in const [Size(28, 24), Size(48, 40)]) {
          final half = Offset(size.width / 2, size.height / 2),
              path = QuarterViewBridgeArt.approach(bridge);
          for (var i = 1; i < path.length; i++) {
            final from = path[i - 1] - half, to = path[i] - half;
            expect(w.blocked(from & size), false);
            expect(w.clearLine(from, to, size), true);
            expect(
              (w.move(from, to - from, size) - to).distance,
              lessThan(.01),
            );
            expect(
              (w.move(to, from - to, size) - from).distance,
              lessThan(.01),
            );
          }
        }
        final pier = QuarterViewBridgeArt.point(bridge, const Offset(590, 900));
        final body = Rect.fromCenter(center: pier, width: 28, height: 24);
        expect(QuarterViewBridgeArt.supports(bridge, body), false);
        expect(
          w.blocked(body, ignoreWater: true),
          true,
          reason: 'the visible front arch/pier is a grounded object',
        );
        final underpass = QuarterViewBridgeArt.point(
          bridge,
          const Offset(1260, 550),
        );
        final underBody = Rect.fromCenter(
          center: underpass,
          width: 28,
          height: 24,
        );
        expect(
          w.blocked(underBody, ignoreWater: true),
          false,
          reason: 'an open arch is not an invisible stone wall',
        );
        final behind = QuarterViewBridgeArt.point(
          bridge,
          const Offset(775, 435),
        );
        expect(
          w.blocked(Rect.fromCenter(center: behind, width: 28, height: 24)),
          false,
        );
      }
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      final b = s.world.bridge;
      final left = BridgeRail(s, b, 14, front: true),
          right = BridgeRail(s, b, 27, front: true);
      expect(
        left.priority,
        greaterThan(right.priority),
        reason: 'rail depth follows the slope instead of one flat front layer',
      );
      _proofs();
    },
  );
  test(
    'all wooded chapters use native tree variants and oasis palms have grounded trunks',
    () {
      for (final stage in WorldStage.values) {
        final w = AdventureWorld(stage: stage);
        for (final p in w.props.where((p) => p.kind == 'tree')) {
          expect(p.treeVariant, isNotNull, reason: stage.name);
          expect(p.drawSize, ForestTreeArt.drawSize(p.treeVariant!));
          expect(w.blocked(p.collisionBodies.first), true);
        }
        for (final p in w.props.where((p) => p.kind == 'ruin-7')) {
          expect(p.drawSize.height, 270);
          expect(p.collisionBodies.single.width, 26);
          expect(w.blocked(p.collisionBodies.single), true);
        }
      }
    },
  );
}

void _proofs() {
  final dir = Platform.environment['SJRPG_QUARTER_PROOF'];
  if (dir == null) return;
  Directory(dir).createSync(recursive: true);
  final base = File('/workspace/scratch/abbey-fixtures/chapel.json');
  final template = base.existsSync()
      ? GameCheckpoint.decode(base.readAsStringSync())?.restore(GameArt())
      : null;
  final progress = template?.progress;
  template?.dispose();
  for (final stage in [WorldStage.forest, WorldStage.sands]) {
    final s = Adventure(
      GameArt(),
      heroClass: HeroClass.mage,
      stage: stage,
      restoredProgress: progress,
    )..start(TestGame());
    try {
      s.mobs.clear();
      s.dormantEnemies.clear();
      s.waveTime = 100000;
      s.progress.hp = s.progress.maxHp;
      s.progress.energy = s.progress.maxEnergy;
      final spots = <String, Offset>{};
      if (stage == WorldStage.forest) {
        spots['bridge'] = QuarterViewBridgeArt.axisPoint(s.world.bridge, .37);
        spots['underpass'] = QuarterViewBridgeArt.point(
          s.world.bridge,
          const Offset(1260, 550),
        );
        spots['pier'] = QuarterViewBridgeArt.point(
          s.world.bridge,
          const Offset(620, 1040),
        );
        spots['gate'] =
            VillageGatewayArt.anchor(s.world.authoredSettlement) +
            const Offset(0, 85);
        final tree = s.world.props.firstWhere((p) => p.treeVariant == 2);
        spots['grove'] = tree.body.bottomCenter + const Offset(105, 65);
        final gateBounds = VillageGatewayArt.bounds(s.world.authoredSettlement);
        spots['chest'] =
            s.world.chests.firstWhere(
              (at) => !gateBounds.inflate(160).contains(at),
            ) +
            const Offset(70, 30);
        s.hero.position.setValues(
          s.world.bridge.center.dx - 14,
          s.world.bridge.center.dy - 12,
        );
        s.spawnPack(initial: true);
        s.mobs.clear();
        if (s.encounterAreas.isNotEmpty) {
          spots['beacon'] =
              s.encounterAreas.values.first.stone + const Offset(65, 30);
        }
      } else {
        final palm = s.world.props.firstWhere((p) => p.kind == 'ruin-7');
        spots['palm'] = palm.body.bottomCenter + const Offset(90, 40);
      }
      for (final e in spots.entries) {
        final half = Offset(s.hero.body.width / 2, s.hero.body.height / 2);
        final at = s.world.spawnNear(e.value - half, s.hero.body.size)!;
        s.hero.position.setValues(at.dx, at.dy);
        expect(s.world.blocked(s.hero.body), false);
        final saved = GameCheckpoint.capture(s)!.encode();
        expect(GameCheckpoint.decode(saved), isNotNull);
        File('$dir/${e.key}.json').writeAsStringSync(saved);
      }
    } finally {
      s.dispose();
    }
  }
}

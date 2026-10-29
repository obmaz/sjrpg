import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/desert_temple_art.dart';
import 'package:guardian_new/field_landscape.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/quest_scenery.dart';
import 'package:guardian_new/world_model.dart';

import 'support/sorceress_fixture.dart';
import 'support/test_game.dart';

Future<Uint8List> raster(void Function(ui.Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(512, 512);
  picture.dispose();
  final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  return Uint8List.fromList(pixels.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'hard road clips follow real sand fields without erasing forest or stone routes',
    () async {
      final world = AdventureWorld(), plan = FieldLandscape(AdventureWorld());
      final before = world.trails.map((road) => road.points.toList()).toList();
      for (final (at, sandy) in [
        (const ui.Offset(16737.47265625, 10768.1474609375), true),
        (world.sandFields[2].bounds.center, true),
        (const ui.Offset(3000, 7000), false),
        (const ui.Offset(17280, 3628), false),
        (world.settlement.center, false),
      ]) {
        expect(plan.isSandyGround(at), sandy, reason: 'material at $at');
        final rgba = await raster((c) {
          c.translate(256 - at.dx, 256 - at.dy);
          plan.clipHardTrailGround(c);
          c.drawRect(
            ui.Rect.fromCenter(center: at, width: 512, height: 512),
            ui.Paint()..color = const ui.Color(0xffffffff),
          );
        });
        expect(
          rgba[(256 * 512 + 256) * 4 + 3],
          sandy ? 0 : 255,
          reason: 'only the sandy part loses its hard paving',
        );
      }
      expect(world.trails.map((road) => road.points.toList()).toList(), before);
    },
  );

  test(
    'sand archive paving is half-buried fragments rather than opaque rounded strips',
    () async {
      final world = AdventureWorld(stage: WorldStage.sands),
          scenery = QuestScenery(AdventureWorld(stage: WorldStage.sands));
      final patch = scenery.patches.firstWhere(
        (p) => p.design == QuestGroundDesign.archiveRows,
      );
      final pixels = await raster((c) {
        c.translate(256 - patch.center.dx, 256 - patch.center.dy);
        scenery.paintGround(c, patch.bounds);
      });
      final alphas = [for (var i = 3; i < pixels.length; i += 4) pixels[i]];
      expect(alphas.where((a) => a > 125).length, 0);
      expect(alphas.where((a) => a > 50).length, inInclusiveRange(1, 18000));
      expect(
        world.sites.firstWhere((s) => s.id == patch.siteId).at,
        patch.center,
      );
    },
  );

  test('ruin court field checkpoints restore beside the real solid props', () {
    final directory = Platform.environment['SJRPG_DESERT_PROOF_DIR'];
    for (final siteIndex in [1, 5]) {
      final session = Adventure(GameArt(), stage: WorldStage.sands)
        ..start(TestGame());
      addTearDown(session.dispose);
      final p = session.progress
        ..level = 12
        ..skillPoints = 60;
      trainSkill(p, 'bash', 3);
      trainSkill(p, 'shout');
      trainSkill(p, 'battleSprint');
      p.selectSkill('bash');
      p.selectSkill('howl', slot: 1);
      p.hp = p.maxHp;
      p.energy = p.maxEnergy;
      final site = session.world.sites[siteIndex];
      final expected = const [
        ui.Offset(-390, -260),
        ui.Offset(370, -240),
        ui.Offset(-420, 90),
        ui.Offset(390, 110),
        ui.Offset(-430, 390),
        ui.Offset(390, 410),
      ].map((offset) => site.at + offset * worldScale).toList();
      final ruins =
          session.world.props
              .where(
                (p) =>
                    DesertTempleArt.supports(p.kind) &&
                    expected.any((at) => (p.body.center - at).distance < .01),
              )
              .toList()
            ..sort(
              (a, b) => (a.body.center - site.at).distanceSquared.compareTo(
                (b.body.center - site.at).distanceSquared,
              ),
            );
      expect(ruins.length, greaterThanOrEqualTo(3));
      final ruin = ruins.first;
      final at = session.world.spawnNear(
        ruin.body.bottomCenter + const ui.Offset(-80, 70),
        session.hero.body.size,
      )!;
      session.hero.position.setValues(at.dx, at.dy);
      session.hero.lastClearPosition = at;
      final checkpoint = GameCheckpoint.capture(session);
      expect(checkpoint, isNotNull);
      expect(GameCheckpoint.decode(checkpoint!.encode()), isNotNull);
      if (directory != null) {
        Directory(directory).createSync(recursive: true);
        File(
          '$directory/ruin-court-$siteIndex.json',
        ).writeAsStringSync(checkpoint.encode());
        File('$directory/ruin-court-$siteIndex-info.json').writeAsStringSync(
          jsonEncode({
            'hero': [at.dx, at.dy],
            'site': [site.at.dx, site.at.dy],
            'siteName': site.name,
            'prop': [ruin.body.center.dx, ruin.body.center.dy],
            'kind': ruin.kind,
            'courtPieces': [
              for (final piece in ruins)
                {
                  'kind': piece.kind,
                  'at': [piece.body.center.dx, piece.body.center.dy],
                },
            ],
          }),
        );
      }
    }
  });

  test(
    'generated temple atlas has four isolated cells within four MiB',
    () async {
      final codec = await ui.instantiateImageCodec(
        await File('art/desert-temple.webp').readAsBytes(),
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      try {
        expect(image.width, 1024);
        expect(image.height, 1024);
        expect(image.width * image.height * 4, 4194304);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        for (var cell = 0; cell < 4; cell++) {
          var visible = 0;
          for (var y = 0; y < 512; y++) {
            for (var x = 0; x < 512; x++) {
              final alpha =
                  data[((cell ~/ 2 * 512 + y) * 1024 + cell % 2 * 512 + x) * 4 +
                      3];
              if (x < 32 || x >= 480 || y < 32 || y >= 480) {
                expect(alpha, 0, reason: 'adjacent props must never bleed');
              } else if (alpha > 16) {
                visible++;
              }
            }
          }
          expect(visible, greaterThan(10000));
        }
      } finally {
        image.dispose();
      }
    },
  );

  test(
    'desert has solid broken columns, piers, fallen drums and walls only in sand stage',
    () {
      final world = AdventureWorld(stage: WorldStage.sands);
      final ruins = world.props
          .where((p) => DesertTempleArt.supports(p.kind))
          .toList();
      expect(ruins.length, greaterThan(60));
      expect(ruins.map((r) => r.kind).toSet(), {
        'temple-0',
        'temple-1',
        'temple-2',
        'temple-3',
      });
      for (final ruin in ruins) {
        expect(world.blocked(ruin.body.deflate(1), ignoreWater: true), true);
        final paint = DesertTempleArt.destination(ruin);
        expect(
          paint.bottom,
          closeTo(ruin.body.bottom + ruin.drawSize.height * .0625, 1e-9),
        );
        expect(paint.contains(ruin.body.center), true);
        expect(ruin.collisionBodies.single, ruin.body);
      }
      for (final stage in [
        WorldStage.forest,
        WorldStage.past,
        WorldStage.tombs,
      ]) {
        expect(
          AdventureWorld(
            stage: stage,
          ).props.where((p) => DesertTempleArt.supports(p.kind)),
          isEmpty,
        );
      }
    },
  );

  test(
    'broken temple props leave the real desert routes open to a mounted body',
    () {
      final world = AdventureWorld(stage: WorldStage.sands);
      final ruins = world.props
          .where((p) => DesertTempleArt.supports(p.kind))
          .toList();
      for (final road in world.trails) {
        for (var i = 1; i < road.points.length; i++) {
          final a = road.points[i - 1], b = road.points[i];
          final steps = ((b - a).distance / 100).ceil().clamp(1, 100000);
          for (var step = 0; step <= steps; step++) {
            final at = ui.Offset.lerp(a, b, step / steps)!;
            final body = ui.Rect.fromCenter(center: at, width: 46, height: 34);
            expect(ruins.any((r) => r.body.overlaps(body)), false);
          }
        }
      }
    },
  );

  test(
    'sand route ribbons feather to transparent and leave industrial ground unchanged',
    () async {
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawRect(
        const ui.Rect.fromLTWH(0, 0, 4, 4),
        ui.Paint()..color = const ui.Color(0xffd3b37e),
      );
      final pic = rec.endRecording();
      final image = await pic.toImage(4, 4);
      pic.dispose();
      final shader = ui.ImageShader(
        image,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      );
      try {
        for (final stage in [WorldStage.sands, WorldStage.future]) {
          final world = AdventureWorld(stage: stage),
              plan = FieldLandscape(AdventureWorld(stage: stage));
          final at =
              world.trails.first.points[world.trails.first.points.length ~/ 2];
          final pixels = await raster((c) {
            c.translate(256 - at.dx, 256 - at.dy);
            plan.paintSandTrails(
              c,
              ui.Rect.fromCenter(center: at, width: 512, height: 512),
              shader,
            );
          });
          final alpha = [for (var i = 3; i < pixels.length; i += 4) pixels[i]];
          if (stage == WorldStage.sands) {
            expect(alpha.where((a) => a > 0), isNotEmpty);
            expect(alpha.reduce((a, b) => a > b ? a : b), lessThan(180));
            expect(alpha.where((a) => a > 0 && a < 16), isNotEmpty);
          } else {
            expect(alpha.every((a) => a == 0), true);
          }
        }
      } finally {
        shader.dispose();
        image.dispose();
      }
    },
  );
}

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';

import 'support/sorceress_fixture.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'new battle artwork has a valid reproducible combat checkpoint',
    () async {
      final session = Adventure(GameArt(), stage: WorldStage.sands)
        ..start(TestGame());
      addTearDown(session.dispose);
      inCombatField(session);
      session.progress.level = 70;
      session.progress.skillPoints = 1000;
      for (final (slot, id) in [
        'whirlwind',
        'leapAttack',
        'howl',
        'concentrate',
      ].indexed) {
        trainSkill(session.progress, id, 5);
        expect(session.progress.selectSkill(id, slot: slot), isTrue);
      }
      session.progress.skillPoints = 2;
      session.progress.selectedBasic = session.progress.defaultBasicId;
      session.progress.energy = session.progress.maxEnergy;
      session.progress.hp = session.progress.maxHp;
      session.syncLife();
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final enemy = session.spawnEnemy(
          i.isEven ? 'mummy' : 'scorpion',
          session.hero.body.center +
              Offset(math.cos(angle), math.sin(angle)) * 160,
        );
        if (enemy != null) enemy.attackClock = 8;
      }
      expect(session.mobs.length, greaterThanOrEqualTo(4));
      final checkpoint = GameCheckpoint.capture(session)!;
      expect(GameCheckpoint.decode(checkpoint.encode()), isNotNull);
      final proof = Platform.environment['CINEMATIC_ART_PROOF_DIR'];
      if (proof != null) {
        await Directory(proof).create(recursive: true);
        await File(
          '$proof/battle-checkpoint.json',
        ).writeAsString(checkpoint.encode());
      }
    },
  );

  test('heroes are newly rendered at native384 without texture upscaling', () {
    final manifest =
        jsonDecode(
              File(
                '../docs/art/character-high-resolution-provenance.json',
              ).readAsStringSync(),
            )
            as Map;
    expect(manifest['sourceCell'], 384);
    expect(manifest['runtimeCell'], 384);
    expect(manifest['worldSizeIncrease'], 1.5);
    for (final role in (manifest['runtimeRoles'] as Map).values) {
      expect(
        (role as Map)['nativeRenderSequenceSha256'],
        matches(RegExp(r'^[a-f0-9]{64}$')),
      );
    }
  });

  test(
    'a sword extending beyond its source cell stays intact in the native atlas',
    () async {
      final sourceCodec = await ui.instantiateImageCodec(
        await File('../docs/art/cinematic/skeleton-original.png').readAsBytes(),
      );
      final source = (await sourceCodec.getNextFrame()).image;
      sourceCodec.dispose();
      final atlasCodec = await ui.instantiateImageCodec(
        await File('art/actors-cinematic-skeleton.webp').readAsBytes(),
      );
      final atlas = (await atlasCodec.getNextFrame()).image;
      atlasCodec.dispose();
      addTearDown(source.dispose);
      addTearDown(atlas.dispose);
      final provenance =
          jsonDecode(
                File(
                  '../docs/art/cinematic/provenance.json',
                ).readAsStringSync(),
              )
              as Map;
      final original =
          (provenance['assets']['skeleton']['sourceRects'][0] as List)
              .cast<int>();
      final record =
          jsonDecode(
                File(
                  'art/actors-cinematic-skeleton-bounds.json',
                ).readAsStringSync(),
              )
              as Map;
      final target = (record['frames'][12] as List).cast<int>();
      final from = (await source.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final to = (await atlas.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      var retained = 0;
      for (var y = 0; y < target[3]; y++) {
        for (var x = 0; x < target[2]; x++) {
          final sourceX = original[0] + x;
          if (sourceX < source.width ~/ 4) continue;
          final a = from[((original[1] + y) * source.width + sourceX) * 4 + 3];
          final b = to[((target[1] + y) * atlas.width + target[0] + x) * 4 + 3];
          if (b > 96) {
            expect(b, a);
            retained++;
          }
        }
      }
      expect(
        retained,
        greaterThan(100),
        reason: 'the complete sword extends beyond the equal-grid boundary',
      );
    },
  );

  test(
    'all21 new enemies preserve measured native crops at 1.5 world height',
    () {
      final provenance =
          jsonDecode(
                File(
                  '../docs/art/cinematic/provenance.json',
                ).readAsStringSync(),
              )
              as Map;
      var count = 0;
      for (final entry in (provenance['assets'] as Map).entries) {
        if (entry.key == 'ui' || entry.key == 'vfx') continue;
        count++;
        final record =
            jsonDecode(
                  File(
                    'art/actors-cinematic-${entry.key}-bounds.json',
                  ).readAsStringSync(),
                )
                as Map;
        expect(record['artworkWorldHeightMultiplier'], 1.5);
        expect(record['frames'], hasLength(16));
        expect(record['feet'], hasLength(16));
        expect(
          (record['sizes'][0][1] as num) * 1.5,
          closeTo(record['nativeBodyHeight'] as num, .0001),
        );
        final originals = entry.value['sourceRects'] as List;
        for (var direction = 0; direction < 8; direction++) {
          for (var phase = 0; phase < 2; phase++) {
            final source = originals[((direction + 2) % 8) * 2 + phase] as List;
            final target = record['frames'][direction * 2 + phase] as List;
            expect(target[2], source[2] - source[0]);
            expect(target[3], source[3] - source[1]);
          }
        }
      }
      expect(count, 21);
    },
  );
}

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_atlas.dart';
import 'package:guardian_new/boss_sprite_mesh.dart';
import 'package:guardian_new/game_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt art;
  late Map provenance;
  late Map smooth;
  setUpAll(() async {
    final data =
        jsonDecode(await rootBundle.loadString('assets/art.json')) as Map;
    art = GameArt()
      ..actors = Map<String, dynamic>.from(data['actors'] as Map)
      ..corpses = Map<String, dynamic>.from(data['corpses'] as Map);
    provenance =
        jsonDecode(
              File(
                '../docs/art/monster-motion/provenance.json',
              ).readAsStringSync(),
            )
            as Map;
    smooth =
        jsonDecode(
              File(
                '../docs/art/monster-motion/smooth-provenance.json',
              ).readAsStringSync(),
            )
            as Map;
    for (final name in [
      'monster-corpses',
      ...((provenance['assets'] as Map).keys
          .where((k) => k.startsWith('walk-'))
          .map((key) => 'actors-$key')),
    ]) {
      final bytes = await rootBundle.load('assets/images/$name.webp');
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      art.images[name] = (await codec.getNextFrame()).image;
      codec.dispose();
    }
  });
  tearDownAll(() => art.dispose());
  test(
    'all21 species have eight walk and eight attack poses in each bearing',
    () {
      final records = smooth['assets'] as Map;
      expect(records, hasLength(21));
      for (final entry in records.entries) {
        final record = art.actors['walk-${entry.key}'] as Map<String, dynamic>;
        final atlas = ActorAtlas.fromJson(record);
        final image = art.images['actors-walk-${entry.key}']!;
        expect(atlas.frames, hasLength(128));
        expect(atlas.walk!.framesPerDirection, 8);
        expect(atlas.enemyAttack!.framesPerDirection, 8);
        expect(entry.value['nativeWalkKeys'], 32);
        expect(entry.value['decodedRGBABytes'], lessThan(24 * 1024 * 1024));
        for (final f in atlas.frames) {
          expect(f.source.left, greaterThanOrEqualTo(4));
          expect(f.source.top, greaterThanOrEqualTo(4));
          expect(f.source.right, lessThanOrEqualTo(image.width - 4));
          expect(f.source.bottom, lessThanOrEqualTo(image.height - 4));
          expect(f.anchor.dy, inInclusiveRange(0, f.source.height + 32));
        }
        for (var d = 0; d < 8; d++) {
          expect(atlas.walk!.frameIndex(d, .999), d * 8 + 7);
          expect(atlas.enemyAttack!.frameIndex(d, 0), 64 + d * 8);
          expect(atlas.enemyAttack!.frameIndex(d, 1), 64 + d * 8 + 7);
        }
      }
    },
  );
  test(
    'continuous locomotion selects eight baked images instead of freezing at pose zero',
    () async {
      for (final kind in ['goblin', 'wolf', 'viper', 'golem', 'gunner']) {
        final hashes = <int>{};
        for (var p = 0; p < 8; p++) {
          final recorder = ui.PictureRecorder();
          art.actor(
            ui.Canvas(recorder),
            kind,
            const ui.Offset(80, 120),
            math.pi / 2,
            0,
            62,
            walkPose: BossVisualPose(walking: true, stride: p / 8, weight: 1),
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(160, 150);
          picture.dispose();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          hashes.add(Object.hashAll(bytes));
          image.dispose();
        }
        expect(
          hashes,
          hasLength(8),
          reason: '$kind must select eight different articulated sprites',
        );
      }
    },
  );
  test(
    'attack rendering selects preparation, strike and return rather than walking',
    () async {
      for (final kind in ['goblin', 'wolf', 'cultist', 'scorpion', 'gunner']) {
        final hashes = <int>{};
        for (var p = 0; p < 8; p++) {
          final recorder = ui.PictureRecorder();
          art.actor(
            ui.Canvas(recorder),
            kind,
            const ui.Offset(80, 120),
            math.pi / 2,
            0,
            62,
            enemyAttackProgress: p / 7,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(160, 150);
          picture.dispose();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          hashes.add(Object.hashAll(bytes));
          image.dispose();
        }
        // The first and last image deliberately return to the same grounded pose.
        expect(hashes.length, greaterThanOrEqualTo(7), reason: kind);
      }
    },
  );
  test(
    'seventeen ground corpse silhouettes retain their own measured aspect',
    () async {
      final kinds = (art.corpses['kinds'] as List).cast<String>();
      expect(kinds.toSet(), hasLength(17));
      expect(
        kinds,
        containsAll(['goblin', 'wolf', 'skeleton', 'viper', 'gunner']),
      );
      for (final kind in kinds) {
        final bounds = art.corpseBounds(kind, const ui.Offset(200, 200), 80);
        expect(bounds.center, const ui.Offset(200, 200));
        expect(bounds.width, 80);
        expect(bounds.height, inInclusiveRange(22, 85));
      }
      final directory = Platform.environment['MONSTER_MOTION_PROOF_DIR'];
      if (directory == null) return;
      Directory(directory).createSync(recursive: true);
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xff5d6249), ui.BlendMode.src);
      for (final (i, kind) in kinds.indexed) {
        final at = ui.Offset(i % 5 * 190 + 95, i ~/ 5 * 210 + 104);
        art.actor(canvas, kind, at, math.pi / 2, 0, 50);
        art.corpse(canvas, kind, at + const ui.Offset(0, 55), 82);
      }
      final picture = recorder.endRecording(),
          image = await picture.toImage(950, 840);
      picture.dispose();
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      File(
        '$directory/living-and-ground-corpses.png',
      ).writeAsBytesSync(data.buffer.asUint8List());
      image.dispose();
    },
  );
}

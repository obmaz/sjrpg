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
  test('all21 species have32 independent padded native walking images', () {
    final walks = (provenance['assets'] as Map).entries
        .where((e) => e.key.startsWith('walk-'))
        .toList();
    expect(walks, hasLength(21));
    for (final entry in walks) {
      final record = art.actors[entry.key] as Map<String, dynamic>;
      final atlas = ActorAtlas.fromJson(record);
      final image = art.images['actors-${entry.key}']!;
      expect(atlas.frames, hasLength(32));
      expect(atlas.walk, isNotNull);
      final crops = entry.value['sourceRects'] as List;
      final columns = entry.value['sourceDirectionColumns'] as List;
      for (var d = 0; d < 8; d++) {
        for (var phase = 0; phase < 4; phase++) {
          final f = atlas.frames[d * 4 + phase];
          final original =
              crops[phase * 8 + (columns[(d + 2) % 8] as int)] as List;
          expect(f.source.width, original[2] - original[0]);
          expect(f.source.height, original[3] - original[1]);
          expect(f.source.left, greaterThanOrEqualTo(4));
          expect(f.source.top, greaterThanOrEqualTo(4));
          expect(f.source.right, lessThanOrEqualTo(image.width - 4));
          expect(f.source.bottom, lessThanOrEqualTo(image.height - 4));
          expect(f.anchor.dy, f.source.height);
        }
      }
    }
  });
  test(
    'continuous locomotion selects four actual images instead of freezing at pose zero',
    () async {
      for (final kind in ['goblin', 'wolf', 'viper', 'golem', 'gunner']) {
        final hashes = <int>{};
        for (var p = 0; p < 4; p++) {
          final recorder = ui.PictureRecorder();
          art.actor(
            ui.Canvas(recorder),
            kind,
            const ui.Offset(80, 120),
            math.pi / 2,
            0,
            62,
            walkPose: BossVisualPose(walking: true, stride: p / 4, weight: 1),
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
          hasLength(4),
          reason: '$kind must select four different articulated sprites',
        );
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

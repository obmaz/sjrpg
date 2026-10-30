import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_atlas.dart';
import 'package:guardian_new/game_art.dart';

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<({ui.Image image, Uint8List rgba})> _raster(
  void Function(ui.Canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 256);
  picture.dispose();
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return (image: image, rgba: Uint8List.fromList(data.buffer.asUint8List()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const roles = ['hero', 'hero-attack', 'hero-backhand', 'hero-cleave'];
  late GameArt art, oldRoll;
  final atlases = <String, ActorAtlas>{};
  final proof = Platform.environment['HELMETED_HERO_PROOF_DIR'];
  setUpAll(() async {
    final metadata =
        jsonDecode(await File('assets/art.json').readAsString()) as Map;
    art = GameArt()..actors = metadata['actors'];
    for (final role in [...roles, 'roll']) {
      art.images['actors-$role'] = await _decode(
        'assets/images/actors-$role.${role == 'roll' ? 'png' : 'webp'}',
      );
      atlases[role] = ActorAtlas.fromJson(art.actors[role]);
    }
    art.images['hero-helmeted-portrait'] = await _decode(
      'assets/images/hero-helmeted-portrait.webp',
    );
    oldRoll = GameArt()
      ..actors = {
        'roll': jsonDecode(await File('art/roll-bounds.json').readAsString()),
      };
    oldRoll.images['actors-roll'] = await _decode('art/actors-roll.png');
    if (proof != null) await Directory(proof).create(recursive: true);
  });
  tearDownAll(() {
    art.dispose();
    oldRoll.dispose();
  });

  test(
    'all packed frames retain clear padding, projected anchors and real poses',
    () async {
      for (final role in roles) {
        final atlas = atlases[role]!, image = art.images['actors-$role']!;
        expect(atlas.projectedOrigin, isTrue);
        expect(atlas.frames.length, role == 'hero' ? 144 : 128);
        expect(atlas.frames.every((f) => !f.mirrored), isTrue);
        if (role == 'hero') {
          expect(atlas.motion!.framesPerDirection, 8);
        } else {
          expect(atlas.action!.framesPerDirection, 8);
        }
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        for (final frame in atlas.frames) {
          final rect = frame.source;
          var visible = 0;
          for (var y = rect.top.toInt(); y < rect.bottom; y++) {
            for (var x = rect.left.toInt(); x < rect.right; x++) {
              final alpha = bytes[(y * image.width + x) * 4 + 3];
              if (alpha == 0) continue;
              visible++;
              expect(x - rect.left, greaterThanOrEqualTo(5));
              expect(rect.right - x, greaterThanOrEqualTo(5));
              expect(y - rect.top, greaterThanOrEqualTo(5));
              expect(rect.bottom - y, greaterThanOrEqualTo(5));
            }
          }
          expect(visible, greaterThan(150));
        }
      }
    },
  );

  for (var direction = 0; direction < 16; direction++) {
    test(
      'helmeted direction $direction renders every idle, gait and attack pose without clipping',
      () async {
        final angle = math.pi / 2 + direction * math.pi / 8;
        final hashes = <String, Set<int>>{};
        final sheet = ui.PictureRecorder(), canvas = ui.Canvas(sheet);
        canvas.drawColor(const ui.Color(0xff24352e), ui.BlendMode.src);
        var row = 0;
        for (final role in roles) {
          final count = role == 'hero' ? 9 : 8;
          for (var pose = 0; pose < count; pose++) {
            final frame = await _raster(
              (c) => art.actor(
                c,
                'hero',
                const ui.Offset(128, 180),
                angle,
                role == 'hero' ? math.max(0, pose - 1) : 0,
                60,
                moving: role == 'hero' && pose > 0,
                attack: role != 'hero',
                comboPose: math.max(0, roles.indexOf(role) - 1),
                actionProgress: (pose + .2) / 8,
              ),
            );
            try {
              var visible = 0, hash = 0;
              for (var y = 0; y < 256; y++) {
                for (var x = 0; x < 256; x++) {
                  final i = (y * 256 + x) * 4;
                  if (frame.rgba[i + 3] == 0) continue;
                  visible++;
                  expect(x, inInclusiveRange(8, 247));
                  expect(y, inInclusiveRange(8, 247));
                  hash = (hash * 31 + x + y * 256 + frame.rgba[i]) & 0x3fffffff;
                }
              }
              expect(visible, greaterThan(250));
              hashes.putIfAbsent(role, () => {}).add(hash);
              canvas.drawImage(
                frame.image,
                ui.Offset((row % 4) * 256.0, (row ~/ 4) * 256.0),
                ui.Paint(),
              );
              row++;
            } finally {
              frame.image.dispose();
            }
          }
        }
        for (final entry in hashes.entries) {
          expect(
            entry.value.length,
            entry.key == 'hero' ? 9 : 8,
            reason: 'each sampled source pose is a distinct real rig frame',
          );
        }
        final picture = sheet.endRecording();
        if (proof != null) {
          final image = await picture.toImage(1024, 2304);
          try {
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '$proof/direction-$direction.png',
            ).writeAsBytes(png.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        }
        picture.dispose();
      },
    );
  }

  test(
    'native384 dodge preserves each pose and ground anchor at the current scale',
    () async {
      final oldAtlas = ActorAtlas.fromJson(oldRoll.actors['roll']);
      final currentAtlas = atlases['roll']!;
      final oldImage = oldRoll.images['actors-roll']!;
      final currentImage = art.images['actors-roll']!;
      expect(
        currentAtlas.heights[1],
        closeTo(oldAtlas.heights[1] * 2, .000001),
      );
      expect(
        currentImage.width * currentImage.height,
        greaterThanOrEqualTo(oldImage.width * oldImage.height * 4),
      );
      for (var direction = 0; direction < 8; direction++) {
        for (var phase = 0; phase < 4; phase++) {
          final angle = math.pi / 2 + direction * math.pi / 4;
          final current = await _raster(
            (c) => art.roll(
              c,
              const ui.Offset(128, 180),
              angle,
              phase,
              mage: true,
            ),
          );
          final original = await _raster((c) {
            c.translate(128, 180);
            c.scale(1.5);
            c.translate(-128, -180);
            oldRoll.roll(
              c,
              const ui.Offset(128, 180),
              angle,
              phase,
              mage: true,
            );
          });
          var intersection = 0, union = 0, currentArea = 0, oldArea = 0;
          for (var i = 3; i < current.rgba.length; i += 4) {
            final now = current.rgba[i] > 20, before = original.rgba[i] > 20;
            if (now) currentArea++;
            if (before) oldArea++;
            if (now && before) intersection++;
            if (now || before) union++;
          }
          expect(
            intersection / union,
            greaterThan(.88),
            reason:
                'native detail must retain the same pose and foot anchor at the requested size',
          );
          expect(
            currentArea / oldArea,
            inInclusiveRange(.86, 1.14),
            reason: 'small sprites can gain or lose edge pixels from sampling',
          );
          current.image.dispose();
          original.image.dispose();
          final warrior = await _raster(
            (c) => art.roll(
              c,
              const ui.Offset(128, 180),
              angle,
              phase,
              mage: false,
            ),
          );
          expect(warrior.rgba.any((b) => b != 0), isTrue);
          warrior.image.dispose();
        }
      }
    },
  );

  test(
    'helmeted HUD portrait paints the approved adult male identity',
    () async {
      final frame = await _raster(
        (c) => art.helmetedWarriorPortrait(
          c,
          const ui.Rect.fromLTWH(16, 16, 224, 224),
        ),
      );
      expect(frame.rgba.where((b) => b > 0).length, greaterThan(60000));
      frame.image.dispose();
    },
  );
}

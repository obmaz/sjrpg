import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_atlas.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/stage_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Guardian',
    )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'))).load();
  });
  final manifestPath = Platform.environment['TRUE_ACTOR_MANIFEST'];
  test('actual rigged actor atlas admission, native poses and decoded memory', () async {
    const roles = [
      'hero',
      'hero-attack',
      'hero-backhand',
      'hero-cleave',
      'mage',
      'mage-cast',
      'roll',
    ];
    final records = <String, dynamic>{},
        images = <String, Map<String, dynamic>>{};
    late final GameArt art;
    late final Map<String, dynamic> manifest;
    Map<String, dynamic>? stagedAdmission;
    if (manifestPath != null) {
      manifest =
          jsonDecode(File(manifestPath).readAsStringSync())
              as Map<String, dynamic>;
      art = GameArt()..actors = records;
    } else {
      // Default CI uses the real assembler output and production load path.
      // The external manifest is only an optional private research override.
      art = await GameArt.loadMenu();
      addTearDown(art.dispose);
      records.addAll(art.actors);
      expect(
        ActorAtlas.fromJson(
          records['hero'] as Map<String, dynamic>,
        ).motion?.framesPerDirection,
        8,
      );
      expect(
        ActorAtlas.fromJson(
          records['mage'] as Map<String, dynamic>,
        ).motion?.framesPerDirection,
        8,
      );
      await art.ensureStage(WorldStage.forest, heroClass: HeroClass.warrior);
      int resident(GameArt a) => roles.fold(0, (n, key) {
        final i = a.images['actors-$key'];
        return n + (i == null ? 0 : i.width * i.height * 4);
      });
      final warNames = roles
          .where((key) => art.images.containsKey('actors-$key'))
          .toList();
      final warBytes = resident(art);
      expect(warNames.toSet(), {
        'hero',
        'mage',
        'roll',
        'hero-attack',
        'hero-backhand',
        'hero-cleave',
      });
      expect(warBytes, 88 * 1024 * 1024);
      // Reuse the already decoded shared textures, with explicit ownership.
      // This admits a fresh staged Mage target, not a second cold decode.
      final mage = await GameArt.loadMenu();
      final borrowed = art.images.values.toSet();
      try {
        for (final image in mage.images.values) {
          image.dispose();
        }
        mage.images.clear();
        mage.images.addAll({
          for (final entry in art.images.entries)
            if (![
              'actors-hero-attack',
              'actors-hero-backhand',
              'actors-hero-cleave',
            ].contains(entry.key))
              entry.key: entry.value,
        });
        await mage.ensureStage(WorldStage.forest, heroClass: HeroClass.mage);
        final mageNames = roles
            .where((key) => mage.images.containsKey('actors-$key'))
            .toList();
        expect(mageNames.toSet(), {'hero', 'mage', 'roll', 'mage-cast'});
        final mageBytes = resident(mage);
        expect(mageBytes, 56 * 1024 * 1024);
        art.images['actors-mage-cast'] = mage.images['actors-mage-cast']!;
        borrowed.add(art.images['actors-mage-cast']!);
        stagedAdmission = {
          'warrior': {'roles': warNames, 'rgbaBytes': warBytes},
          'mageStagedTargetWithBorrowedSharedImages': {
            'roles': mageNames,
            'rgbaBytes': mageBytes,
          },
          'reusedDecodedActorFixture': true,
          'independentSecondColdDecode': false,
        };
      } finally {
        mage.images.removeWhere((_, image) => borrowed.contains(image));
        mage.dispose();
      }
      manifest = {
        '_status': {
          'complete': true,
          'source': 'prepared repo assets via GameArt.loadMenu/ensureStage',
        },
        for (final role in roles)
          role: {
            'image':
                'assets/images/actors-$role.${role == 'mage' || role == 'roll' ? 'png' : 'webp'}',
            'record': records[role],
          },
      };
    }
    final dir = Platform.environment['TRUE_ACTOR_PROOF_DIR'];
    if (dir != null) await Directory(dir).create(recursive: true);
    for (final entry in manifest.entries) {
      if (entry.key.startsWith('_')) continue;
      final value = entry.value as Map<String, dynamic>;
      final path = value['image'] as String;
      late final List<int> encoded;
      late final ui.Image image;
      if (manifestPath != null) {
        encoded = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(
          Uint8List.fromList(encoded),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        image = frame.image;
        addTearDown(image.dispose);
        art.images['actors-${entry.key}'] = image;
      } else {
        final data = await rootBundle.load(path);
        encoded = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        image = art.images['actors-${entry.key}']!;
      }
      records[entry.key] = value['record'];
      final atlas = ActorAtlas.fromJson(
        value['record'] as Map<String, dynamic>,
      );
      expect(
        atlas.projectedOrigin,
        true,
        reason:
            'all final actor roles explicitly declare their fixed ground origin',
      );
      expect(
        ((value['record'] as Map<String, dynamic>)['feet'] as List).length,
        atlas.frames.length,
      );
      if (manifestPath == null) {
        expect(
          atlas.heights.first,
          closeTo(
            entry.key == 'roll' ? 93.8037037037037 : 130.88888888888889,
            .000001,
          ),
          reason:
              'native384 renders retain the authored world reference and ground origin',
        );
        expect(image.width, lessThanOrEqualTo(2048));
        expect(image.height, lessThanOrEqualTo(4096));
      }
      for (final frame in atlas.frames) {
        expect(frame.source.left, greaterThanOrEqualTo(0));
        expect(frame.source.top, greaterThanOrEqualTo(0));
        expect(frame.source.right, lessThanOrEqualTo(image.width));
        expect(frame.source.bottom, lessThanOrEqualTo(image.height));
        expect(frame.mirrored, false);
      }
      images[entry.key] = {
        'path': path,
        'encodedBytes': encoded.length,
        'width': image.width,
        'height': image.height,
        'rgbaBytes': image.width * image.height * 4,
        'frames': atlas.frames.length,
        'referenceHeights': atlas.heights,
      };
    }
    Future<void> save(
      String name,
      int width,
      int height,
      void Function(ui.Canvas) draw,
    ) async {
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xff182b28), ui.BlendMode.src);
      draw(canvas);
      final picture = recorder.endRecording(),
          image = await picture.toImage(width, height);
      picture.dispose();
      if (dir != null) {
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('$dir/$name.png').writeAsBytes(bytes.buffer.asUint8List());
      }
      image.dispose();
    }

    void anchor(ui.Canvas canvas, ui.Offset feet) {
      final p = ui.Paint()
        ..color = const ui.Color(0xff9b8a56)
        ..strokeWidth = .6;
      canvas.drawLine(
        feet - const ui.Offset(5, 0),
        feet + const ui.Offset(5, 0),
        p,
      );
      canvas.drawLine(
        feet - const ui.Offset(0, 3),
        feet + const ui.Offset(0, 3),
        p,
      );
    }

    int hashFrame(List<int> pixels, int width, ui.Rect source) {
      var hash = 0x811c9dc5;
      for (var y = source.top.toInt(); y < source.bottom.toInt(); y++) {
        for (var x = source.left.toInt(); x < source.right.toInt(); x++) {
          final offset = (y * width + x) * 4;
          for (var c = 0; c < 4; c++) {
            hash = ((hash ^ pixels[offset + c]) * 16777619) & 0xffffffff;
          }
        }
      }
      return hash;
    }

    final classes = <String, dynamic>{};
    for (final key in ['hero', 'mage']) {
      if (!records.containsKey(key)) continue;
      final atlas = ActorAtlas.fromJson(records[key] as Map<String, dynamic>),
          motion = atlas.motion!;
      expect(motion.framesPerDirection, 8);
      expect(atlas.frames.length, 144);
      final image = art.images['actors-$key']!;
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      for (var d = 0; d < 16; d++) {
        final hashes = {
          for (var phase = 0; phase < 8; phase++)
            hashFrame(
              pixels,
              image.width,
              atlas.frames[motion.frameIndex(d, phase, moving: true)].source,
            ),
        };
        expect(
          hashes.length,
          8,
          reason: 'every direction needs8 genuinely different source images',
        );
      }
      final attacks = key == 'hero'
          ? ['hero-attack', 'hero-backhand', 'hero-cleave']
          : ['mage-cast'];
      for (final attack in attacks) {
        expect(
          records.containsKey(attack),
          true,
          reason: 'movement must not ship with an unmatched old attack',
        );
        final attackAtlas = ActorAtlas.fromJson(
          records[attack] as Map<String, dynamic>,
        );
        expect(attackAtlas.frames.length, 128);
        final action = attackAtlas.action!;
        expect(action.framesPerDirection, 8);
        final image = art.images['actors-$attack']!;
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        for (var d = 0; d < 16; d++) {
          expect({
            for (var p = 0; p < 8; p++)
              hashFrame(
                pixels,
                image.width,
                attackAtlas.frames[action.frameIndex(d, (p + .1) / 8)].source,
              ),
          }, hasLength(8));
        }
        expect(
          attackAtlas.heights.single,
          closeTo(atlas.heights.single, .00001),
        );
      }
      expect(records.containsKey('roll'), true);
      final roll = ActorAtlas.fromJson(records['roll'] as Map<String, dynamic>);
      final group = key == 'hero' ? 0 : 1;
      expect(roll.frames.length, greaterThanOrEqualTo((group + 1) * 32));
      expect(
        43 / roll.heights[group],
        closeTo(60 / atlas.heights.single, .00001),
        reason: 'run, attack and roll must preserve the same body/head scale',
      );
      await save('$key-idle-run16x8', 9 * 128, 16 * 110, (canvas) {
        for (var direction = 0; direction < 16; direction++) {
          final angle = math.pi / 2 + direction * math.pi * 2 / 16;
          for (var phase = -1; phase < 8; phase++) {
            final feet = ui.Offset(
              (phase + 1) * 128 + 64,
              direction * 110 + 88,
            );
            anchor(canvas, feet);
            art.actor(
              canvas,
              key,
              feet,
              angle,
              math.max(0, phase),
              60,
              moving: phase >= 0,
            );
            art.text(
              canvas,
              'd$direction ${phase < 0 ? 'idle' : 'run$phase'}',
              feet - const ui.Offset(0, 79),
              color: const ui.Color(0xffd9d5b4),
              size: 9,
            );
          }
        }
      });
      for (var combo = 0; combo < attacks.length; combo++) {
        await save('${attacks[combo]}-16x8', 16 * 128, 8 * 110, (canvas) {
          for (var phase = 0; phase < 8; phase++) {
            for (var direction = 0; direction < 16; direction++) {
              final feet = ui.Offset(direction * 128 + 64, phase * 110 + 88);
              anchor(canvas, feet);
              art.actor(
                canvas,
                key,
                feet,
                math.pi / 2 + direction * math.pi * 2 / 16,
                phase,
                60,
                attack: true,
                actionProgress: (phase + .1) / 8,
                comboPose: combo,
              );
            }
          }
        });
      }
      await save('$key-roll8x4', 8 * 128, 4 * 110, (canvas) {
        for (var phase = 0; phase < 4; phase++) {
          for (var direction = 0; direction < 8; direction++) {
            final feet = ui.Offset(direction * 128 + 64, phase * 110 + 88);
            anchor(canvas, feet);
            art.roll(
              canvas,
              feet,
              math.pi / 2 + direction * math.pi * 2 / 8,
              phase,
              mage: key == 'mage',
            );
          }
        }
      });
      classes[key] = {
        'directions': 16,
        'realRunFramesPerDirection': 8,
        'separateIdleFrames': 16,
        'attackRoles': attacks,
        'allSourcesUniquePerDirection': true,
        'sameRollWorldScale': true,
      };
    }
    // The production rider keeps its original clip and46px size. Verify
    // actual new idle sprites fit above/sideways; lower legs are intentionally clipped.
    final legacyMetadata =
        jsonDecode(await rootBundle.loadString('assets/art.json'))
            as Map<String, dynamic>;
    for (final mount in ['horse', 'boat']) {
      if (!art.images.containsKey('actors-$mount')) {
        final data = await rootBundle.load('assets/images/actors-$mount.png');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        addTearDown(image.dispose);
        art.images['actors-$mount'] = image;
        art.actors[mount] =
            (legacyMetadata['actors'] as Map<String, dynamic>)[mount];
      }
    }
    var riderChecks = 0;
    await save(
      'mounted-idle-horse-boat-cardinals',
      4 * 150,
      classes.length * 2 * 200,
      (canvas) {
        var row = 0;
        for (final key in classes.keys) {
          for (final mount in ['horse', 'boat']) {
            final water = mount == 'boat', lift = water ? 8.0 : 20.0;
            for (var direction = 0; direction < 4; direction++) {
              final feet = ui.Offset(direction * 150 + 75, row * 200 + 177),
                  angle = direction * math.pi / 2;
              anchor(canvas, feet);
              art.actor(canvas, mount, feet, angle, 0, water ? 48 : 62);
              canvas.save();
              canvas.clipRect(
                ui.Rect.fromLTRB(
                  feet.dx - 64,
                  feet.dy - 135,
                  feet.dx + 64,
                  feet.dy - lift - 21,
                ),
              );
              art.actor(canvas, key, feet - ui.Offset(0, lift), angle, 0, 46);
              canvas.restore();
              art.text(
                canvas,
                '$key $mount $direction',
                ui.Offset(direction * 150 + 75, row * 200 + 5),
                size: 9,
              );
            }
            row++;
          }
        }
      },
    );
    for (final key in classes.keys) {
      for (final water in [false, true]) {
        final lift = water ? 8.0 : 20.0;
        for (var direction = 0; direction < 4; direction++) {
          final recorder = ui.PictureRecorder();
          art.actor(
            ui.Canvas(recorder),
            key,
            ui.Offset(75, 177 - lift),
            direction * math.pi / 2,
            0,
            46,
          );
          final picture = recorder.endRecording(),
              image = await picture.toImage(150, 200);
          picture.dispose();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          image.dispose();
          var left = 150, top = 200, right = 0, visible = 0;
          for (var y = 0; y < 200; y++) {
            for (var x = 0; x < 150; x++) {
              if (bytes[(y * 150 + x) * 4 + 3] <= 8) continue;
              left = math.min(left, x);
              top = math.min(top, y);
              right = math.max(right, x + 1);
              if (x >= 11 && x < 139 && y >= 42 && y < 177 - lift - 21) {
                visible++;
              }
            }
          }
          expect(
            left,
            greaterThanOrEqualTo(11),
            reason: '$key mounted idle must not lose side clothing/weapon',
          );
          expect(right, lessThanOrEqualTo(139));
          expect(
            top,
            greaterThanOrEqualTo(42),
            reason: 'head/staff must fit the larger native rider clip',
          );
          expect(visible, greaterThan(80));
          riderChecks++;
        }
      }
    }
    int memory(Iterable<String> names) =>
        names.fold(0, (sum, n) => sum + (images[n]?['rgbaBytes'] as int? ?? 0));
    final bothMovement = memory(['hero', 'mage']),
        sharedRoll = memory(['roll']);
    final complete = classes.containsKey('hero') && classes.containsKey('mage');
    final report = {
      'completeBothClasses': complete,
      'assetStatus': manifest['_status'],
      'stagedAdmission': stagedAdmission,
      'mountedIdleClipChecks': riderChecks,
      'roles': images,
      'classes': classes,
      'newFamilyDecodedRgbaBytes': memory(images.keys),
      'sharedBothMovementBytes': bothMovement,
      'sharedRollBytes': sharedRoll,
      'stagedWarriorResidentBytes': complete
          ? bothMovement +
                sharedRoll +
                memory(['hero-attack', 'hero-backhand', 'hero-cleave'])
          : null,
      'stagedMageResidentBytes': complete
          ? bothMovement + sharedRoll + memory(['mage-cast'])
          : null,
      'memoryNote':
          'Current staged loader decodes BOTH movement sheets and shared roll, plus selected class attacks. Values exclude other unchanged game assets.',
    };
    if (dir != null) {
      await File(
        '$dir/actual-actor-report.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    }
    stdout.writeln(jsonEncode(report));
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_atlas.dart';
import 'package:guardian_new/boss_sprite_mesh.dart';

Future<ui.Image> sprite() async {
  final recorder = ui.PictureRecorder(), c = ui.Canvas(recorder);
  final p = ui.Paint()..color = const ui.Color(0xff26a971);
  c.drawRect(const ui.Rect.fromLTWH(31, 8, 34, 61), p);
  c.drawRect(const ui.Rect.fromLTWH(8, 27, 23, 37), p);
  c.drawRect(const ui.Rect.fromLTWH(65, 25, 23, 39), p);
  p.color = const ui.Color(0xff367de0);
  c.drawRect(const ui.Rect.fromLTWH(29, 65, 15, 27), p);
  c.drawRect(const ui.Rect.fromLTWH(53, 65, 15, 27), p);
  p.color = const ui.Color(0xffdfb76a);
  c.drawRect(const ui.Rect.fromLTWH(38, 13, 21, 18), p);
  // A hostile neighboring atlas cell must never leak into the cutout.
  p.color = const ui.Color(0xffff0000);
  c.drawRect(const ui.Rect.fromLTWH(96, 0, 96, 96), p);
  final picture = recorder.endRecording();
  final image = await picture.toImage(192, 96);
  picture.dispose();
  return image;
}

Future<Uint8List> draw(
  BossSpriteMeshPainter mesh,
  ui.Image image,
  BossVisualPose pose,
) async {
  final recorder = ui.PictureRecorder(), c = ui.Canvas(recorder);
  final p = ui.Paint()..filterQuality = ui.FilterQuality.low;
  mesh.paint(
    c,
    image,
    const ui.Rect.fromLTWH(0, 0, 96, 96),
    const ui.Rect.fromLTWH(16, 8, 96, 96),
    p,
    pose,
    groundOrigin: const ui.Offset(64, 96),
  );
  expect(p.shader, isNull, reason: 'the caller Paint must remain reusable');
  final picture = recorder.endRecording();
  final rendered = await picture.toImage(128, 112);
  picture.dispose();
  final bytes = (await rendered.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final result = Uint8List.fromList(bytes);
  rendered.dispose();
  return result;
}

int difference(Uint8List a, Uint8List b) {
  var result = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] ||
        a[i + 1] != b[i + 1] ||
        a[i + 2] != b[i + 2] ||
        a[i + 3] != b[i + 3]) {
      result++;
    }
  }
  return result;
}

int opaque(Uint8List bytes) {
  var result = 0;
  for (var i = 3; i < bytes.length; i += 4) {
    if (bytes[i] > 100) result++;
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all profiles articulate one sprite with fixed feet and isolated UVs',
    () async {
      final image = await sprite(), mesh = BossSpriteMeshPainter();
      addTearDown(() {
        mesh.dispose();
        image.dispose();
      });
      for (final profile in BossMeshProfile.values) {
        final idle = await draw(mesh, image, BossVisualPose(profile: profile));
        final sameIdle = await draw(
          mesh,
          image,
          BossVisualPose(profile: profile, stride: .47),
        );
        expect(difference(idle, sameIdle), 0);
        final a = await draw(
          mesh,
          image,
          BossVisualPose(profile: profile, stride: .2, weight: 1),
        );
        final nearby = await draw(
          mesh,
          image,
          BossVisualPose(profile: profile, stride: .201, weight: 1),
        );
        final opposite = await draw(
          mesh,
          image,
          BossVisualPose(profile: profile, stride: .7, weight: 1),
        );
        expect(difference(a, idle), greaterThan(40), reason: '$profile gait');
        expect(difference(a, nearby), lessThan(difference(a, opposite)));
        final attack = await draw(
          mesh,
          image,
          BossVisualPose(profile: profile, strike: 1, skill: .5),
        );
        expect(
          difference(idle, attack),
          greaterThan(70),
          reason: '$profile attack',
        );
        for (final bytes in [a, opposite, attack]) {
          expect(opaque(bytes), closeTo(opaque(idle), opaque(idle) * .15));
          for (var y = 96; y < 112; y++) {
            expect(
              bytes.sublist(y * 128 * 4, (y + 1) * 128 * 4),
              idle.sublist(y * 128 * 4, (y + 1) * 128 * 4),
            );
          }
          var redLeak = 0;
          for (var i = 0; i < bytes.length; i += 4) {
            if (bytes[i] > 230 &&
                bytes[i + 1] < 10 &&
                bytes[i + 2] < 10 &&
                bytes[i + 3] > 100) {
              redLeak++;
            }
          }
          expect(redLeak, 0, reason: 'no adjacent-cell ghost');
        }
      }
    },
  );

  test(
    'pose sanitization and bounded shader lifecycle keep ownership local',
    () async {
      final images = [for (var i = 0; i < 6; i++) await sprite()];
      final mesh = BossSpriteMeshPainter();
      addTearDown(() {
        mesh.dispose();
        for (final image in images) {
          image.dispose();
        }
      });
      final idle = await draw(mesh, images.first, const BossVisualPose());
      final invalid = await draw(
        mesh,
        images.first,
        const BossVisualPose(
          stride: double.nan,
          weight: double.infinity,
          windup: double.nan,
          strike: double.negativeInfinity,
        ),
      );
      expect(difference(idle, invalid), 0);
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      for (var cell = 0; cell < 40; cell++) {
        mesh.paint(
          canvas,
          images.first,
          ui.Rect.fromLTWH(cell.toDouble(), 0, 96, 96),
          const ui.Rect.fromLTWH(0, 0, 96, 96),
          ui.Paint(),
          const BossVisualPose(),
        );
        expect(mesh.cachedUvCount, lessThanOrEqualTo(32));
      }
      expect(mesh.cachedUvCount, 32);
      recorder.endRecording().dispose();
      for (final image in images) {
        await draw(mesh, image, const BossVisualPose(strike: .5));
        expect(mesh.cachedImageCount, lessThanOrEqualTo(4));
      }
      mesh.trim([images.last]);
      expect(mesh.cachedImageCount, 1);
      expect(mesh.cachedUvCount, 1);
      mesh.dispose();
      mesh.dispose();
      expect(mesh.cachedImageCount, 0);
      expect(mesh.cachedUvCount, 0);
      final empty = await draw(
        mesh,
        images.last,
        const BossVisualPose(strike: 1),
      );
      expect(opaque(empty), 0);
    },
  );

  test(
    'actual four boss sheets render continuous attack and gait poses',
    () async {
      final data =
          jsonDecode(await File('assets/art.json').readAsString()) as Map;
      final mesh = BossSpriteMeshPainter(), recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder), loaded = <ui.Image>[];
      final profiles = BossMeshProfile.values;
      final roles = [
        'creatures-b',
        'sand-warden',
        'ancient-king',
        'cyber-core',
      ];
      final variants = [
        const BossVisualPose(),
        const BossVisualPose(stride: .25, weight: 1),
        const BossVisualPose(windup: 1),
        const BossVisualPose(strike: 1, skill: .6),
      ];
      for (var row = 0; row < 4; row++) {
        final bytes = await File(
          'assets/images/actors-${roles[row]}.webp',
        ).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        loaded.add(image);
        final atlas = ActorAtlas.fromJson(
          Map<String, dynamic>.from(data['actors'][roles[row]] as Map),
        );
        final index = row == 0 ? 8 : 0, frame = atlas.frames[index];
        final heightIndex = row == 0 ? 1 : 0;
        final scale = 105 / atlas.heights[heightIndex];
        for (var col = 0; col < variants.length; col++) {
          final foot = ui.Offset(96 + col * 192, 116 + row * 128);
          final dst = ui.Rect.fromLTWH(
            foot.dx - frame.anchor.dx * scale,
            foot.dy - frame.anchor.dy * scale,
            frame.source.width * scale,
            frame.source.height * scale,
          );
          final p = variants[col];
          mesh.paint(
            canvas,
            image,
            frame.source,
            dst,
            ui.Paint()..filterQuality = ui.FilterQuality.low,
            BossVisualPose(
              profile: profiles[row],
              stride: p.stride,
              weight: p.weight,
              windup: p.windup,
              strike: p.strike,
              skill: p.skill,
            ),
            groundOrigin: foot,
          );
        }
      }
      final picture = recorder.endRecording();
      final proof = await picture.toImage(768, 512);
      picture.dispose();
      final rgba = (await proof.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      for (var row = 0; row < 4; row++) {
        final unique = <int>{};
        for (var col = 0; col < 4; col++) {
          var visible = 0;
          final crop = <int>[];
          for (var y = row * 128; y < (row + 1) * 128; y++) {
            final at = (y * 768 + col * 192) * 4;
            crop.addAll(rgba.sublist(at, at + 192 * 4));
            for (var x = 0; x < 192; x++) {
              if (rgba[at + x * 4 + 3] > 100) visible++;
            }
          }
          expect(visible, greaterThan(500), reason: '${profiles[row]} visible');
          unique.add(Object.hashAll(crop));
        }
        expect(unique.length, 4, reason: '${profiles[row]} four actual poses');
      }
      final output = Platform.environment['BOSS_MESH_PROOF_DIR'];
      if (output != null) {
        await Directory(output).create(recursive: true);
        final png = await proof.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$output/four-boss-mesh.png',
        ).writeAsBytes(png!.buffer.asUint8List());
      }
      proof.dispose();
      mesh.dispose();
      for (final image in loaded) {
        image.dispose();
      }
    },
  );
}

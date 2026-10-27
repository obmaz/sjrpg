import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_motion.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

class _FeetArt extends GameArt {
  final feet = <ui.Offset>[];
  @override
  void actor(
    ui.Canvas canvas,
    String key,
    ui.Offset at,
    double angle,
    int phase,
    double height, {
    bool attack = false,
    int comboPose = 0,
    double opacity = 1,
    double flash = 0,
  }) => feet.add(at);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a viper slithers and lunges on the ground instead of hopping', () {
    final art = _FeetArt(), s = Adventure(art)..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    inCombatField(s);
    final enemy = s.spawnEnemy('viper', const ui.Offset(6160, 4200))!;
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    try {
      enemy.motion.update(.05, distance: 11, bearing: 0);
      enemy.render(canvas);
      enemy.motion.update(.05, distance: 11, bearing: 0);
      enemy.render(canvas);
      enemy.pounceDuration = .4;
      enemy.pounceRemaining = .2;
      enemy.render(canvas);
      expect(art.feet, hasLength(3));
      expect(art.feet.map((p) => p.dy), everyElement(enemy.size.y / 2));
    } finally {
      recorder.endRecording().dispose();
    }
  });

  test(
    'real viper atlas covers eight facings and two distinct complete poses',
    () async {
      final data =
          jsonDecode(await rootBundle.loadString('assets/art.json')) as Map;
      final record = data['actors']['viper'] as Map;
      final bytes = await rootBundle.load('assets/images/actors-viper.webp');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      addTearDown(image.dispose);
      final frames = record['frames'] as List, feet = record['feet'] as List;
      expect(frames, hasLength(16));
      expect(feet, hasLength(16));
      expect(image.width, 960);
      expect(image.height, 640);
      for (var i = 0; i < 16; i++) {
        final f = (frames[i] as List).cast<num>();
        expect(f[0], greaterThanOrEqualTo(i % 4 * 240));
        expect(f[1], greaterThanOrEqualTo(i ~/ 4 * 160));
        expect(f[0] + f[2], lessThanOrEqualTo((i % 4 + 1) * 240));
        expect(f[1] + f[3], lessThanOrEqualTo((i ~/ 4 + 1) * 160));
        expect(f[2], greaterThan(60));
        expect(f[3], greaterThan(80));
        final anchor = (feet[i] as List).cast<num>();
        expect(anchor[0], inInclusiveRange(f[0], f[0] + f[2]));
        expect(anchor[1], inInclusiveRange(f[1], f[1] + f[3]));
      }
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      for (var facing = 0; facing < 8; facing++) {
        final a = facing * 2, b = a + 1;
        var differing = 0;
        for (var y = 0; y < 160; y++) {
          for (var x = 0; x < 240; x++) {
            final ai = ((a ~/ 4 * 160 + y) * image.width + a % 4 * 240 + x) * 4;
            final bi = ((b ~/ 4 * 160 + y) * image.width + b % 4 * 240 + x) * 4;
            if (rgba[ai + 3] > 32 || rgba[bi + 3] > 32) {
              if ((rgba[ai] - rgba[bi]).abs() +
                      (rgba[ai + 1] - rgba[bi + 1]).abs() +
                      (rgba[ai + 2] - rgba[bi + 2]).abs() >
                  35) {
                differing++;
              }
            }
          }
        }
        expect(differing, greaterThan(1500), reason: 'slithering pair $facing');
      }

      final directory = Platform.environment['VIPER_ART_PROOF_DIR'];
      if (directory == null) return;
      await Directory(directory).create(recursive: true);
      final art = GameArt()
        ..actors = Map<String, dynamic>.from(data['actors'] as Map)
        ..images['actors-viper'] = image;
      Future<void> save(
        String name,
        int width,
        int height,
        void Function(ui.Canvas canvas) draw,
      ) async {
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xff314436), ui.BlendMode.src);
        draw(canvas);
        final picture = recorder.endRecording();
        final output = await picture.toImage(width, height);
        picture.dispose();
        final png = (await output.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '$directory/$name.png',
        ).writeAsBytes(png.buffer.asUint8List());
        output.dispose();
      }

      await save('eight-directions-two-slithering-poses', 720, 300, (canvas) {
        for (var facing = 0; facing < 8; facing++) {
          for (var pose = 0; pose < 2; pose++) {
            final at = ui.Offset(
              facing % 4 * 180 + 42 + pose * 85.0,
              facing ~/ 4 * 150 + 75.0,
            );
            canvas.drawCircle(
              at,
              2,
              ui.Paint()..color = const ui.Color(0xff96e1ba),
            );
            art.actor(
              canvas,
              'viper',
              at,
              math.pi / 2 + facing * math.pi / 4,
              pose,
              44,
            );
          }
        }
      });
      final s = Adventure(art)..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      inCombatField(s);
      final enemy = s.spawnEnemy('viper', const ui.Offset(6160, 4200))!
        ..bearing = math.pi
        ..pounceGoal = s.hero.body.center
        ..windup = .3;
      await save('body-and-contact-eight-directions', 720, 300, (canvas) {
        enemy.windup = 0;
        for (var facing = 0; facing < 8; facing++) {
          final angle = math.pi / 2 + facing * math.pi / 4;
          final direction = ui.Offset(math.cos(angle), math.sin(angle));
          final contact = math.min(
            direction.dx.abs() < .001
                ? double.infinity
                : 26 / direction.dx.abs(),
            direction.dy.abs() < .001
                ? double.infinity
                : 23 / direction.dy.abs(),
          );
          final center = ui.Offset(enemy.size.x / 2, enemy.size.y / 2);
          final target = ui.Rect.fromCenter(
            center: center + direction * contact,
            width: 28,
            height: 24,
          );
          canvas.save();
          canvas.translate(facing % 4 * 180 + 78.0, facing ~/ 4 * 150 + 65.0);
          enemy.bearing = enemy.motion.facing = angle;
          enemy.render(canvas);
          canvas.drawRect(
            ui.Offset.zero & ui.Size(enemy.size.x, enemy.size.y),
            ui.Paint()
              ..color = const ui.Color(0xff75e5e5)
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 1,
          );
          canvas.drawRect(
            target,
            ui.Paint()
              ..color = const ui.Color(0xffff8c80)
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 1,
          );
          canvas.restore();
        }
        enemy.bearing = math.pi;
        enemy.windup = .3;
      });
      await save('bite-warning', 400, 200, (canvas) {
        canvas.translate(290, 95);
        enemy.render(canvas);
      });
      enemy.windup = 0;
      enemy.pounceDuration = .4;
      enemy.pounceRemaining = .2;
      enemy.attackMotion.strike(EnemyAttackPose.pounce, math.pi);
      enemy.attackMotion.update(.07);
      await save('bite-lunge', 400, 200, (canvas) {
        canvas.translate(290, 95);
        enemy.render(canvas);
      });
    },
  );
}

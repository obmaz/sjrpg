import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/actor_motion.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/enemy_catalog.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

const _kinds = ['bonehound', 'clockwork-spider', 'crystal-beetle'];

class _GroundArt extends GameArt {
  ui.Offset? lastFeet;
  @override
  void actor(
    ui.Canvas canvas,
    String key,
    ui.Offset feet,
    double angle,
    int phase,
    double height, {
    bool attack = false,
    bool moving = false,
    int comboPose = 0,
    double opacity = 1,
    double flash = 0,
  }) => lastFeet = feet;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt art;
  setUpAll(() async {
    final data =
        jsonDecode(await rootBundle.loadString('assets/art.json')) as Map;
    art = GameArt()..actors = Map<String, dynamic>.from(data['actors'] as Map);
    for (final key in [..._kinds, 'hero']) {
      final bytes = await rootBundle.load('assets/images/actors-$key.webp');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      art.images['actors-$key'] = (await codec.getNextFrame()).image;
      codec.dispose();
    }
  });
  tearDownAll(() {
    for (final image in art.images.values) {
      image.dispose();
    }
  });

  for (final kind in _kinds) {
    test(
      '$kind contains sixteen complete padded frames and independent gaits',
      () async {
        final record = art.actors[kind] as Map;
        final frames = record['frames'] as List,
            anchors = record['feet'] as List;
        final image = art.images['actors-$kind']!;
        expect((image.width, image.height), (768, 640));
        expect(frames, hasLength(16));
        expect(anchors, hasLength(16));
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        for (var i = 0; i < 16; i++) {
          final frame = (frames[i] as List).cast<num>();
          final anchor = (anchors[i] as List).cast<num>();
          expect(frame[0], greaterThanOrEqualTo(i % 4 * 192 + 12));
          expect(frame[1], greaterThanOrEqualTo(i ~/ 4 * 160 + 12));
          expect(
            frame[0] + frame[2],
            lessThanOrEqualTo((i % 4 + 1) * 192 - 12),
          );
          expect(
            frame[1] + frame[3],
            lessThanOrEqualTo((i ~/ 4 + 1) * 160 - 12),
          );
          expect(anchor[0], inInclusiveRange(frame[0], frame[0] + frame[2]));
          expect(anchor[1], inInclusiveRange(frame[1], frame[1] + frame[3]));
        }
        for (var bearing = 0; bearing < 8; bearing++) {
          final first = bearing * 2, second = first + 1;
          var different = 0;
          for (var y = 0; y < 160; y++) {
            for (var x = 0; x < 192; x++) {
              final a =
                  ((first ~/ 4 * 160 + y) * 768 + first % 4 * 192 + x) * 4;
              final b =
                  ((second ~/ 4 * 160 + y) * 768 + second % 4 * 192 + x) * 4;
              if ((rgba[a + 3] > 32 || rgba[b + 3] > 32) &&
                  (rgba[a] - rgba[b]).abs() +
                          (rgba[a + 1] - rgba[b + 1]).abs() +
                          (rgba[a + 2] - rgba[b + 2]).abs() >
                      35) {
                different++;
              }
            }
          }
          expect(
            different,
            greaterThan(400),
            reason: '$kind gait pair $bearing',
          );
        }
      },
    );
  }

  test('low mechanical and crystal bodies do not inherit a canine hop', () {
    for (final kind in ['clockwork-spider', 'crystal-beetle']) {
      final probe = _GroundArt(), s = Adventure(probe)..start(TestGame());
      try {
        s.mobs.clear();
        inCombatField(s);
        final enemy = s.spawnEnemy(kind, const ui.Offset(6160, 4200))!;
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        try {
          enemy.motion.update(.05, distance: 11, bearing: 0);
          enemy.render(canvas);
          expect(probe.lastFeet!.dy, enemy.size.y / 2);
          enemy.pounceRemaining = .2;
          enemy.pounceDuration = .4;
          enemy.render(canvas);
          expect(probe.lastFeet!.dy, enemy.size.y / 2);
        } finally {
          recorder.endRecording().dispose();
        }
      } finally {
        s.dispose();
      }
    }
  });

  test('optional native chapter monster art and attack proofs', () async {
    final directory = Platform.environment['THEMED_MONSTER_PROOF_DIR'];
    if (directory == null) return;
    await Directory(directory).create(recursive: true);
    Future<void> save(
      String name,
      int width,
      int height,
      ui.Color color,
      void Function(ui.Canvas) paint,
    ) async {
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      canvas.drawColor(color, ui.BlendMode.src);
      paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('$directory/$name.png').writeAsBytes(png.buffer.asUint8List());
      image.dispose();
    }

    for (final kind in _kinds) {
      final def = enemyCatalog[kind]!;
      final background = kind == 'bonehound'
          ? const ui.Color(0xff302c2f)
          : kind == 'clockwork-spider'
          ? const ui.Color(0xff25363e)
          : const ui.Color(0xff343d39);
      await save('$kind-directions', 800, 300, background, (canvas) {
        for (var facing = 0; facing < 8; facing++) {
          for (var phase = 0; phase < 2; phase++) {
            final at = ui.Offset(
              facing % 4 * 200 + 48 + phase * 95.0,
              facing ~/ 4 * 150 + 85.0,
            );
            canvas.drawCircle(
              at,
              2,
              ui.Paint()..color = const ui.Color(0xff75e5e5),
            );
            art.actor(
              canvas,
              kind,
              at,
              math.pi / 2 + facing * math.pi / 4,
              phase,
              def.renderHeight,
            );
          }
        }
      });
      final s = inCombatField(Adventure(art))..start(TestGame());
      try {
        s.mobs.clear();
        final enemy = s.spawnEnemy(kind, const ui.Offset(6160, 4200))!;
        await save('$kind-body-and-contact', 880, 360, background, (canvas) {
          for (var facing = 0; facing < 8; facing++) {
            final angle = math.pi / 2 + facing * math.pi / 4;
            final d = ui.Offset(math.cos(angle), math.sin(angle));
            final reach = math.min(
              d.dx.abs() < .001 ? double.infinity : 26 / d.dx.abs(),
              d.dy.abs() < .001 ? double.infinity : 23 / d.dy.abs(),
            );
            final target = ui.Rect.fromCenter(
              center: ui.Offset(12, 11) + d * reach,
              width: 28,
              height: 24,
            );
            void hero() => art.actor(
              canvas,
              'hero',
              target.bottomCenter,
              angle + math.pi,
              0,
              68,
            );
            canvas.save();
            canvas.translate(
              facing % 4 * 220 + 100.0,
              facing ~/ 4 * 180 + 110.0,
            );
            enemy.bearing = enemy.motion.facing = angle;
            if (target.bottom < enemy.size.y) {
              hero();
              enemy.render(canvas);
            } else {
              enemy.render(canvas);
              hero();
            }
            canvas.drawRect(
              const ui.Rect.fromLTWH(0, 0, 24, 22),
              ui.Paint()
                ..color = const ui.Color(0xff75e5e5)
                ..style = ui.PaintingStyle.stroke,
            );
            canvas.drawRect(
              target,
              ui.Paint()
                ..color = const ui.Color(0xffff8c80)
                ..style = ui.PaintingStyle.stroke,
            );
            canvas.restore();
          }
        });
        enemy.bearing = enemy.motion.facing = math.pi;
        enemy.pounceGoal = s.hero.body.center;
        enemy.slamTarget = s.hero.body.center;
        await save('$kind-attack', 1500, 280, background, (canvas) {
          for (var phase = 0; phase < 3; phase++) {
            enemy.windup = phase == 0 ? (def.attackWarning ?? .6) * .5 : 0;
            enemy.attackMotion.cancel();
            if (phase == 1) {
              enemy.attackMotion.strike(switch (def.pattern) {
                'pounce' => EnemyAttackPose.pounce,
                'bolt' => EnemyAttackPose.bolt,
                _ => EnemyAttackPose.sweep,
              }, math.pi);
              enemy.attackMotion.update(.07);
              if (def.pattern == 'pounce') {
                enemy.pounceDuration = .4;
                enemy.pounceRemaining = .2;
              }
            } else {
              enemy.pounceRemaining = 0;
            }
            canvas.save();
            canvas.translate(phase * 500 + 380.0, 145);
            enemy.render(canvas);
            canvas.restore();
          }
        });
      } finally {
        s.dispose();
      }
    }
  });
}

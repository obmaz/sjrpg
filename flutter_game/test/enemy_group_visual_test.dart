import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mixed in [false, true]) {
    test(
      'pursuing ${mixed ? 'desert' : 'forest'} group leaves hero and neighboring sprites visible',
      () async {
        final art = GameArt()..actors = {};
        for (final (key, path) in [
          ('walk-goblin', 'actors-walk-goblin'),
          ('walk-mummy', 'actors-walk-mummy'),
          ('walk-scorpion', 'actors-walk-scorpion'),
          ('hero', 'hero-helmeted'),
        ]) {
          art.actors[key] = jsonDecode(
            await File('art/$path-bounds.json').readAsString(),
          );
          final codec = await ui.instantiateImageCodec(
            await File('art/$path.webp').readAsBytes(),
          );
          art.images['actors-$key'] = (await codec.getNextFrame()).image;
          codec.dispose();
        }
        addTearDown(art.dispose);
        final s = inCombatField(
          Adventure(art, stage: mixed ? WorldStage.sands : WorldStage.forest),
        )..start(TestGame());
        addTearDown(s.dispose);
        s.mobs.clear();
        s.hero.invulnerable = 999;
        final origin = s.hero.body.center;
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final enemy = s.spawnEnemy(
            mixed ? (i.isEven ? 'mummy' : 'scorpion') : 'goblin',
            origin + ui.Offset(math.cos(a), math.sin(a)) * 200,
            reserveSpacing: true,
          )!;
          enemy.combatReady = true;
          enemy.attackClock = 999;
        }
        for (var t = 0; t < 300; t++) {
          s.elapsed += 1 / 30;
          for (final mob in s.mobs.toList()) {
            mob.update(1 / 30);
          }
        }
        const center = ui.Offset(220, 210);
        Future<Uint8List> sprite(
          String key,
          ui.Offset feet,
          double height,
          double bearing,
        ) async {
          final recorder = ui.PictureRecorder();
          art.actor(
            ui.Canvas(recorder),
            key,
            center + feet - origin,
            bearing,
            0,
            height,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(440, 360);
          picture.dispose();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          image.dispose();
          return data;
        }

        final hero = await sprite(
          'hero',
          s.hero.body.bottomCenter,
          60,
          s.hero.bearing,
        );
        final masks = <Uint8List>[];
        for (final mob in s.mobs) {
          masks.add(
            await sprite(
              mob.kind,
              mob.lowProfile ? mob.body.center : mob.body.bottomCenter,
              mob.visualHeight,
              mob.motion.facing,
            ),
          );
        }
        int intersection(Uint8List a, Uint8List b) {
          var count = 0;
          for (var i = 3; i < a.length; i += 4) {
            if (a[i] > 128 && b[i] > 128) count++;
          }
          return count;
        }

        var heroOverlap = 0, pairOverlap = 0;
        for (var i = 0; i < masks.length; i++) {
          heroOverlap += intersection(hero, masks[i]);
          for (var j = i + 1; j < masks.length; j++) {
            pairOverlap += intersection(masks[i], masks[j]);
          }
        }
        expect(heroOverlap, 0, reason: 'monsters should not cover the player');
        expect(pairOverlap, 0, reason: 'monsters should not cover each other');
      },
    );
  }
}

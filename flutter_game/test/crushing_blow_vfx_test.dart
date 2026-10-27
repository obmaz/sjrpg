import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/crushing_blow_vfx.dart';
import 'package:guardian_new/game_art.dart';

import 'support/test_game.dart';

Future<ui.Image> _raster(
  void Function(ui.Canvas) paint, {
  int side = 520,
}) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  picture.dispose();
  return image;
}

Future<int> _hash(ui.Image image) async {
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  var hash = 0;
  for (final byte in bytes) {
    hash = (hash * 31 + byte) & 0x3fffffff;
  }
  return hash;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image atlas;
  late GameArt effectArt;
  setUpAll(() async {
    final data = await rootBundle.load('assets/images/fx-crushing-blow.webp');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    atlas = (await codec.getNextFrame()).image;
    codec.dispose();
    effectArt = GameArt()..images['fx-crushing-blow'] = atlas;
  });
  tearDownAll(() => atlas.dispose());

  test(
    'west mirrors every painted frame around contact without reversing gravity',
    () async {
      Future<ui.Image> frameAt(int frame, double bearing) => _raster((c) {
        paintCrushingFrame(
          effectArt,
          c,
          const ui.Offset(260, 330),
          frame,
          rank: 5,
          charge: 1,
          bearing: bearing,
        );
      });
      for (var frame = 0; frame < 16; frame++) {
        final east = await frameAt(frame, 0),
            west = await frameAt(frame, math.pi);
        final e = (await east.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final w = (await west.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var differences = 0, maximumDifference = 0;
        for (var y = 0; y < 520; y++) {
          for (var x = 0; x < 520; x++) {
            for (var channel = 0; channel < 4; channel++) {
              final difference =
                  (w[(y * 520 + x) * 4 + channel] -
                          e[(y * 520 + 519 - x) * 4 + channel])
                      .abs();
              if (difference > 0) {
                differences++;
              }
              maximumDifference = math.max(maximumDifference, difference);
            }
          }
        }
        // Native bilinear sampling can round a few mirrored color channels by one.
        // Bound that quantization while still rejecting any shift or Y reversal.
        expect(maximumDifference, lessThanOrEqualTo(1));
        expect(
          differences,
          lessThan(100),
          reason: 'painted frame $frame flips x, preserving y',
        );
        if (frame == 2) {
          for (final bearing in [-math.pi / 2, math.pi / 2]) {
            final vertical = await frameAt(frame, bearing);
            final bytes = (await vertical.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            expect(
              bytes,
              orderedEquals(e),
              reason: 'north and south retain upright art',
            );
            vertical.dispose();
          }
        }
        east.dispose();
        west.dispose();
      }
    },
  );

  Adventure session() {
    final s = Adventure(GameArt())..start(TestGame());
    addTearDown(() {
      if (!s.disposed) s.dispose();
    });
    s.hero.position.setValues(6000, 4200);
    s.hero.bearing = 0;
    s.progress.gainXp(8000);
    s.progress.ranks['crushingBlow'] = 1;
    s.progress.selectSkill('crushingBlow');
    s.progress.energy = s.progress.maxEnergy;
    return s;
  }

  test('physical strike captures real charge and only draws after impact', () {
    for (final heldFrames in [0, 12, 24]) {
      final s = session();
      s.hero.beginAim(0);
      for (var i = 0; i < heldFrames; i++) {
        s.hero.update(.05);
      }
      s.hero.finishAim(false);
      final charge = (heldFrames * .05 / s.progress.heavyChargeTime).clamp(
        0.0,
        1.0,
      );
      expect(s.hero.heavyCharge, closeTo(charge, .000001));
      final game = s.game! as TestGame;
      expect(game.added.whereType<CrushingBlowVisual>(), isEmpty);
      for (var i = 0; i < 9; i++) {
        s.hero.update(.05);
      }
      final v = game.added.whereType<CrushingBlowVisual>().single;
      expect(v.charge, closeTo(charge, .000001));
      expect(v.bearing, 0);
      expect(ui.Offset(v.position.x, v.position.y), s.hero.body.center);
      expect(v.priority, 29, reason: 'ground impact stays below the actor');
      expect(v.rank, 1);
    }
  });

  test(
    'visual pauses, expires with tempo and cancels on reset or teardown',
    () {
      final s = session();
      CrushingBlowVisual visual({double tempo = 1}) => CrushingBlowVisual(
        s,
        s.hero.body.center,
        rank: 3,
        charge: 1,
        bearing: 0,
        tempo: tempo,
      );
      final paused = visual();
      paused.update(.05);
      s.pause();
      paused.update(.05);
      expect(paused.age, .05);
      s.resume();
      final fast = visual(tempo: 2);
      for (var i = 0; i < 6; i++) {
        fast.update(.05);
      }
      expect(fast.finished, true);
      expect(s.progress.kills, 0);
      final reset = visual();
      s.progress.gold = 10000;
      expect(s.resetSkills(), true);
      reset.update(.05);
      expect(reset.finished, true);
      final ended = visual();
      s.dispose();
      ended.update(.05);
      expect(ended.finished, true);
    },
  );

  test('windup anticipates contact but cannot survive impact or reset', () {
    final s = session();
    s.hero.skill();
    final windup = (s.game! as TestGame).added
        .whereType<CrushingBlowWindup>()
        .single;
    final time = s.hero.heavyWindup;
    s.pause();
    windup.update(.05);
    expect(windup.finished, false);
    expect(s.hero.heavyWindup, time);
    s.resume();
    s.hero.heavyWindup = 0;
    windup.update(.05);
    expect(windup.finished, true);
    s.hero.cooldowns.clear();
    s.hero.attackClock = 0;
    s.hero.skill();
    final reset = (s.game! as TestGame).added
        .whereType<CrushingBlowWindup>()
        .last;
    s.progress.gold = 10000;
    expect(s.resetSkills(), true);
    reset.update(.05);
    expect(reset.finished, true);
  });

  test(
    'all painted cells have fully transparent padding before their neighbors',
    () async {
      final bytes = (await atlas.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      for (var frame = 0; frame < 16; frame++) {
        var paddingAlpha = 0;
        for (var y = 0; y < 256; y++) {
          for (var x = 0; x < 256; x++) {
            if (x >= 16 && x < 240 && y >= 16 && y < 240) continue;
            final offset =
                ((frame ~/ 4 * 256 + y) * 1024 + frame % 4 * 256 + x) * 4;
            paddingAlpha += bytes[offset + 3];
          }
        }
        expect(paddingAlpha, 0, reason: 'cell $frame has 16px clear padding');
      }
    },
  );

  test(
    'each rank, charge and animation phase produces a distinct physical frame',
    () async {
      for (final phase in [.03, .18, .42, .72]) {
        final hashes = <int>{};
        for (var rank = 1; rank <= 5; rank++) {
          for (final charge in [0.0, 1.0]) {
            final art = CrushingBlowArt(
              effectArt,
              rank: rank,
              charge: charge,
              bearing: .4,
            );
            final frame = await _raster((c) {
              c.translate(260, 260);
              art.paint(c, phase);
            });
            hashes.add(await _hash(frame));
            frame.dispose();
          }
        }
        expect(
          hashes,
          hasLength(10),
          reason: 'ranks and actual held charge both change $phase',
        );
      }
    },
  );

  test(
    'complete effect bounds contain every pixel at all eight bearings',
    () async {
      final s = session();
      s.art.images['fx-crushing-blow'] = atlas;
      for (var direction = 0; direction < 8; direction++) {
        final bearing = direction * math.pi / 4;
        for (final phase in [.03, .18, .42, .72]) {
          final v = CrushingBlowVisual(
            s,
            ui.Offset.zero,
            rank: 5,
            charge: 1,
            bearing: bearing,
            tempo: 1,
          )..age = phase * CrushingBlowVisual.duration;
          final image = await _raster((c) {
            c.translate(260, 260);
            v.render(c);
          });
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          var drawn = 0;
          ui.Offset? outside;
          for (var y = 0; y < 520; y++) {
            for (var x = 0; x < 520; x++) {
              if (bytes[(y * 520 + x) * 4 + 3] == 0) continue;
              drawn++;
              final point = ui.Offset(x - 260.0, y - 260.0);
              if (!v.effectBounds.contains(point)) outside ??= point;
            }
          }
          expect(drawn, greaterThan(200));
          expect(outside, isNull, reason: '$bearing at phase $phase');
          image.dispose();
        }
      }
    },
  );

  test(
    'optional proof against actual ground and raised-weapon actor',
    () async {
      final directory = Platform.environment['CRUSHING_BLOW_PROOF_DIR'];
      if (directory == null) return;
      await Directory(directory).create(recursive: true);
      final meta =
          jsonDecode(await rootBundle.loadString('assets/art.json'))
              as Map<String, dynamic>;
      final art = GameArt()
        ..actors = meta['actors']
        ..controls = meta['controls'];
      for (final asset in [
        'terrain-materials',
        'actors-hero',
        'actors-hero-cleave',
        'fx-crushing-blow',
      ]) {
        final data = await rootBundle.load('assets/images/$asset.webp');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        art.images[asset] = (await codec.getNextFrame()).image;
        codec.dispose();
      }
      addTearDown(() {
        for (final image in art.images.values) {
          image.dispose();
        }
      });
      final soil = art.images['terrain-materials']!;
      for (final charge in [0.0, 1.0]) {
        for (final rank in [1, 3, 5]) {
          for (final phase in [
            .03,
            .18,
            .42,
            .72,
            if (rank == 5 && charge == 1)
              for (var cell = 2; cell < 16; cell++) (cell - 2 + .5) / 14,
          ]) {
            final frame = await _raster((c) {
              c.drawImageRect(
                soil,
                ui.Rect.fromLTWH(
                  soil.width * 2 / 3,
                  soil.height / 2,
                  soil.width / 3,
                  soil.height / 2,
                ),
                const ui.Rect.fromLTWH(0, 0, 520, 520),
                ui.Paint(),
              );
              c.save();
              c.translate(170, 260);
              CrushingBlowArt(
                art,
                rank: rank,
                charge: charge,
                bearing: -.3,
              ).paint(c, phase);
              c.restore();
              art.actor(
                c,
                'hero',
                const ui.Offset(170, 270),
                -.3,
                1,
                60,
                attack: true,
                comboPose: 2,
              );
            });
            final bytes = (await frame.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '$directory/rank$rank-charge${charge.toInt()}-phase$phase.png',
            ).writeAsBytes(bytes.buffer.asUint8List());
            frame.dispose();
          }
        }
      }
    },
  );
}

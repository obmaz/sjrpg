import 'dart:io';
import 'dart:ui' as ui;

import 'package:bonfire/camera/bonfire_camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/encounter_beacon_art.dart';
import 'package:guardian_new/encounters.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

class _TextArt extends GameArt {
  int layouts = 0;
  final labels = <String>[];
  final paragraphs = <ui.Paragraph>[];
  @override
  ui.Paragraph layoutText(
    String value, {
    double size = 16,
    String fontFamily = 'Guardian',
    ui.FontWeight fontWeight = ui.FontWeight.bold,
    ui.Color color = const ui.Color(0xffffedbb),
  }) {
    layouts++;
    labels.add(value);
    final paragraph = super.layoutText(
      value,
      size: size,
      color: color,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
    );
    paragraphs.add(paragraph);
    return paragraph;
  }
}

class _Camera extends BonfireCamera {
  ui.Rect view = ui.Rect.zero;
  @override
  ui.Rect get visibleWorldRect => view;
}

class _Game extends TestGame {
  @override
  final _Camera camera = _Camera();
}

class _CountingStone extends EncounterStone {
  _CountingStone(super.session, super.area);
  int draws = 0;
  @override
  void render(ui.Canvas canvas) {
    draws++;
    super.render(canvas);
  }
}

Future<ui.Image> _raster(
  void Function(ui.Canvas) paint, {
  int width = 192,
  int height = 112,
}) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

Future<Uint8List> _bytes(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image atlas;
  late Uint8List source;
  setUpAll(() async {
    final data = await rootBundle.load('assets/images/encounter-beacons.webp');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    atlas = (await codec.getNextFrame()).image;
    codec.dispose();
    source = await _bytes(atlas);
    await (FontLoader(
      'Guardian',
    )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'))).load();
  });
  tearDownAll(() => atlas.dispose());

  test(
    'all eight measured crops preserve transparent edges and pointed anchors',
    () {
      final crops = <ui.Rect>{};
      for (final stage in WorldStage.values) {
        for (final ready in [false, true]) {
          final frame = EncounterBeaconArt.frame(stage, ready: ready);
          crops.add(frame.source);
          var left = atlas.width, top = atlas.height, right = 0, bottom = 0;
          final opaque = <ui.Offset>[];
          for (var y = frame.source.top.toInt(); y < frame.source.bottom; y++) {
            for (
              var x = frame.source.left.toInt();
              x < frame.source.right;
              x++
            ) {
              if (source[(y * atlas.width + x) * 4 + 3] <= 32) continue;
              final local = ui.Offset(
                x - frame.source.left,
                y - frame.source.top,
              );
              opaque.add(local);
              if (local.dx < left) left = local.dx.toInt();
              if (local.dy < top) top = local.dy.toInt();
              if (local.dx + 1 > right) right = local.dx.toInt() + 1;
              if (local.dy + 1 > bottom) bottom = local.dy.toInt() + 1;
            }
          }
          expect(left, greaterThanOrEqualTo(6));
          expect(top, greaterThanOrEqualTo(6));
          expect(frame.source.width - right, greaterThanOrEqualTo(6));
          expect(frame.source.height - bottom, greaterThanOrEqualTo(6));
          final tipRows = opaque.where((p) => p.dy >= bottom - 4).toList();
          final tipX =
              tipRows.fold(0.0, (sum, p) => sum + p.dx) / tipRows.length;
          expect(frame.tip.dx, closeTo(tipX, .000001));
          expect(frame.tip.dy, bottom);
          expect(
            frame.destination.left + tipX * frame.scale,
            closeTo(0, .000001),
          );
          expect(
            frame.destination.top + bottom * frame.scale,
            closeTo(-6, .000001),
          );
          expect((bottom - top) * frame.scale, closeTo(56, .2));
          expect(
            EncounterBeaconArt.visualBounds.contains(frame.destination.topLeft),
            true,
          );
          expect(
            EncounterBeaconArt.visualBounds.contains(
              frame.destination.bottomRight,
            ),
            true,
          );
          expect(
            EncounterBeaconArt.hintBounds.bottom,
            lessThan(frame.destination.top - 2),
          );
        }
        expect(
          EncounterBeaconArt.frame(stage, ready: false).scale,
          EncounterBeaconArt.frame(stage, ready: true).scale,
        );
      }
      expect(crops.length, 8);
    },
  );

  test(
    'actual eight sprites differ and ready opacity stays isolated per draw',
    () async {
      final signatures = <String>{};
      final paint = ui.Paint();
      for (final stage in WorldStage.values) {
        final alphas = <int>[];
        for (final ready in [false, true, false]) {
          final image = await _raster((canvas) {
            canvas.translate(96, 96);
            EncounterBeaconArt.draw(
              canvas,
              atlas,
              stage,
              ready: ready,
              paint: paint,
            );
          });
          final pixels = await _bytes(image);
          image.dispose();
          var maxAlpha = 0, hash = 0;
          for (var i = 0; i < pixels.length; i++) {
            hash = ((hash * 31) + pixels[i]) & 0x7fffffff;
            if (i % 4 == 3 && pixels[i] > maxAlpha) maxAlpha = pixels[i];
          }
          alphas.add(maxAlpha);
          signatures.add('$hash');
        }
        expect(alphas, [closeTo(140, 1), closeTo(217, 1), closeTo(140, 1)]);
      }
      expect(signatures.length, 8);
    },
  );

  test(
    'each irregular source excludes colored adjacent atlas content',
    () async {
      for (final stage in WorldStage.values) {
        for (final ready in [false, true]) {
          final frame = EncounterBeaconArt.frame(stage, ready: ready);
          final sentinel = await _raster(
            (canvas) {
              canvas.drawPaint(ui.Paint()..color = const ui.Color(0xffff00ff));
              // Preserve the actual atlas's transparent frame separation;
              // sentinel content begins six pixels beyond the crop seam.
              canvas.drawRect(
                frame.source.inflate(6),
                ui.Paint()..blendMode = ui.BlendMode.clear,
              );
              canvas.drawRect(
                frame.source.deflate(6),
                ui.Paint()..color = const ui.Color(0xff00ff00),
              );
            },
            width: atlas.width,
            height: atlas.height,
          );
          final image = await _raster((canvas) {
            canvas.translate(96, 96);
            EncounterBeaconArt.draw(
              canvas,
              sentinel,
              stage,
              ready: ready,
              paint: ui.Paint(),
            );
          });
          final pixels = await _bytes(image);
          sentinel.dispose();
          image.dispose();
          var bodyPixels = 0;
          for (var i = 0; i < pixels.length; i += 4) {
            if (pixels[i + 3] <= 8) continue;
            bodyPixels++;
            expect(
              pixels[i],
              0,
              reason: '$stage/$ready reads outside measured source',
            );
            expect(pixels[i + 2], 0);
          }
          expect(bodyPixels, greaterThan(1000));
        }
      }
    },
  );

  test(
    'stone hides before quota, selects dormant state and caches hit hint',
    () async {
      final art = _TextArt()..images['encounter-beacons'] = atlas;
      final session = Adventure(art);
      addTearDown(session.dispose);
      final area = EncounterArea('1:1', const ui.Offset(6000, 4200));
      final stone = EncounterStone(session, area);
      session.hero.position.setValues(area.stone.dx - 14, area.stone.dy - 12);
      Future<Uint8List> draw() async {
        final image = await _raster((canvas) {
          canvas.translate(74, 48);
          stone.render(canvas);
        });
        final bytes = await _bytes(image);
        image.dispose();
        return bytes;
      }

      expect((await draw()).every((b) => b == 0), true);
      area.waves = 3;
      final ready = await draw();
      expect(art.layouts, 1);
      expect(art.labels.last, '공격해 재소환 · 0/3');
      expect(await draw(), ready);
      expect(art.layouts, 1);
      area.stoneHits = 2;
      expect(await draw(), isNot(ready));
      expect(art.layouts, 2);
      expect(art.labels.last, '공격해 재소환 · 2/3');
      session.dormantEnemies.add({'area': area.key});
      final dormant = await draw();
      expect(dormant, isNot(ready));
      expect(art.layouts, 2);
      // The dormant marker has no near-player hint above its body.
      expect(dormant.sublist(0, 192 * 28 * 4).every((b) => b == 0), true);
      session.dormantEnemies.clear();
      area.waves = 0;
      expect((await draw()).every((b) => b == 0), true);
      stone.onRemove();
      art.images.clear();
    },
  );

  test(
    'actual-font hint has a tight readable backing on bright and dark ground',
    () async {
      final art = _TextArt()..images['encounter-beacons'] = atlas;
      final session = Adventure(art);
      addTearDown(session.dispose);
      final area = EncounterArea('1:1', const ui.Offset(6000, 4200), waves: 3);
      session.hero.position.setValues(5986, 4188);
      final stone = EncounterStone(session, area);
      for (final ground in [
        const ui.Color(0xffe8ca85),
        const ui.Color(0xff243a48),
      ]) {
        final image = await _raster((canvas) {
          canvas.drawPaint(ui.Paint()..color = ground);
          canvas.translate(74, 48);
          stone.render(canvas);
        });
        final bytes = await _bytes(image);
        image.dispose();
        final paragraph = art.paragraphs.single;
        final width = paragraph.longestLine + 12;
        final backing = ui.Rect.fromLTWH(
          -width / 2,
          -86,
          width,
          paragraph.height + 4,
        );
        expect(EncounterBeaconArt.hintBounds.contains(backing.topLeft), true);
        expect(
          EncounterBeaconArt.hintBounds.contains(backing.bottomRight),
          true,
        );
        expect(
          backing.bottom,
          lessThan(
            EncounterBeaconArt.frame(
                  WorldStage.forest,
                  ready: true,
                ).destination.top -
                2,
          ),
        );
        List<int> pixel(int x, int y) =>
            bytes.sublist((y * 192 + x) * 4, (y * 192 + x) * 4 + 4);
        final shaded = pixel(96, 11);
        expect(shaded[0], lessThan(ground.r * 255 * .4 + 1));
        expect(shaded[1], lessThan(ground.g * 255 * .4 + 1));
        final outside = pixel((96 - width / 2 - 3).floor(), 11);
        expect(outside, [
          (ground.r * 255).round(),
          (ground.g * 255).round(),
          (ground.b * 255).round(),
          255,
        ]);
      }
      expect(art.layouts, 1);
      stone.onRemove();
      art.images.clear();
    },
  );

  test('session teardown releases native hints before component removal', () {
    final art = _TextArt();
    final session = Adventure(art);
    final area = EncounterArea('1:1', const ui.Offset(6000, 4200), waves: 3);
    session.hero.position.setValues(5986, 4188);
    final removed = EncounterStone(session, area);
    final retained = EncounterStone(session, area);
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    removed.render(canvas);
    retained.render(canvas);
    expect(art.paragraphs.map((p) => p.debugDisposed), [false, false]);
    removed.onRemove();
    expect(art.paragraphs.map((p) => p.debugDisposed), [true, false]);
    session.dispose();
    expect(art.paragraphs.map((p) => p.debugDisposed), [true, true]);
    retained.render(canvas);
    expect(art.layouts, 2, reason: 'disposed sessions cannot recreate hints');
    // Bonfire may remove the component after the session has already ended.
    retained.onRemove();
    recorder.endRecording().dispose();
  });

  test('culling includes hint edges outside the old component rectangle', () {
    final game = _Game();
    final session = Adventure(GameArt());
    addTearDown(session.dispose);
    final area = EncounterArea('1:1', const ui.Offset(6000, 4200), waves: 3);
    final stone = _CountingStone(session, area)..gameRef = game;
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    game.camera.view = const ui.Rect.fromLTWH(0, 0, 100, 100);
    stone.renderTree(canvas);
    expect(stone.draws, 0);
    game.camera.view = const ui.Rect.fromLTWH(5910, 4110, 20, 15);
    stone.renderTree(canvas);
    expect(stone.draws, 1);
    game.camera.view = const ui.Rect.fromLTWH(5990, 4208, 20, 6);
    stone.renderTree(canvas);
    expect(stone.draws, 2);
    expect(area.waves, 3);
    expect(area.stoneHits, 0);
    recorder.endRecording().dispose();
    stone.onRemove();
  });

  test('empty GameArt retains the vector fallback', () async {
    final session = Adventure(GameArt());
    addTearDown(session.dispose);
    final area = EncounterArea('1:1', const ui.Offset(6000, 4200), waves: 3);
    final stone = EncounterStone(session, area);
    final image = await _raster((canvas) => stone.render(canvas));
    expect((await _bytes(image)).any((b) => b > 0), true);
    image.dispose();
    stone.onRemove();
  });

  test('optional actual-art proof sheet', () async {
    final directory = Platform.environment['BEACON_PROOF_DIR'];
    if (directory == null) return;
    final sessions = <Adventure>[];
    final stones = <EncounterStone>[];
    final image = await _raster(
      (canvas) {
        for (final stage in WorldStage.values) {
          for (final ready in [false, true]) {
            final cell = ui.Offset(ready ? 240 : 0, stage.index * 160.0);
            final art = GameArt()..images['encounter-beacons'] = atlas;
            final session = Adventure(art, stage: stage);
            sessions.add(session);
            final area = EncounterArea(
              '1:1',
              const ui.Offset(6000, 4200),
              waves: 3,
            )..stoneHits = 2;
            session.hero.position.setValues(5986, 4188);
            if (!ready) session.dormantEnemies.add({'area': area.key});
            final stone = EncounterStone(session, area);
            stones.add(stone);
            canvas.save();
            canvas.translate(cell.dx, cell.dy);
            canvas.drawRect(
              const ui.Rect.fromLTWH(0, 0, 240, 160),
              ui.Paint()
                ..color = const [
                  ui.Color(0xff364630),
                  ui.Color(0xffaa8856),
                  ui.Color(0xff67615b),
                  ui.Color(0xff243a48),
                ][stage.index],
            );
            art.text(
              canvas,
              '${stage.name} · ${ready ? "ready" : "dormant"}',
              const ui.Offset(120, 9),
              size: 12,
            );
            canvas.translate(98, 88);
            stone.render(canvas);
            canvas.restore();
          }
        }
      },
      width: 480,
      height: 640,
    );
    await Directory(directory).create(recursive: true);
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File(
      '$directory/encounter-beacons-render.png',
    ).writeAsBytes(png.buffer.asUint8List());
    image.dispose();
    for (final stone in stones) {
      stone.onRemove();
    }
    for (final session in sessions) {
      session.art.images.clear();
      session.dispose();
    }
  });
}

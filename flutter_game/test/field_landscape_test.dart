import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/field_landscape.dart';
import 'package:guardian_new/world_model.dart';

Future<Uint8List> pixels(void Function(ui.Canvas) draw, [int size = 64]) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return Uint8List.fromList(bytes.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<ui.Image> material(ui.Color color) async {
  final recorder = ui.PictureRecorder(), paint = ui.Paint()..color = color;
  final c = ui.Canvas(recorder);
  c.drawRect(const ui.Rect.fromLTWH(0, 0, 16, 16), paint);
  c.drawRect(
    const ui.Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = const ui.Color(0x10000000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(16, 16);
  picture.dispose();
  return image;
}

ui.Offset dryPoint(AdventureWorld world) {
  for (double y = 1400; y < worldSize.height - 1400; y += 769) {
    for (double x = 1400; x < worldSize.width - 1400; x += 877) {
      final p = ui.Offset(x, y);
      if (!world.isWater(p) &&
          !world.settlement.inflate(150).contains(p) &&
          !world.sites.any((s) => s.body.inflate(100).contains(p))) {
        return p;
      }
    }
  }
  throw StateError('No dry field');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<ui.Image> images;
  late List<ui.Shader> shaders;
  setUpAll(() async {
    images = await Future.wait([
      material(const ui.Color(0xff509b39)),
      material(const ui.Color(0xffc9a45c)),
      material(const ui.Color(0xff92928c)),
      material(const ui.Color(0xff55798c)),
    ]);
    shaders = [
      for (final image in images)
        ui.ImageShader(
          image,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          Float64List.fromList([
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
          ]),
        ),
    ];
  });
  tearDownAll(() {
    for (final shader in shaders) {
      shader.dispose();
    }
    for (final image in images) {
      image.dispose();
    }
  });

  test(
    'seven independently authored district plans cover the whole playable world',
    () {
      final signatures = <String>{};
      for (final stage in WorldStage.values) {
        final world = AdventureWorld(stage: stage),
            first = FieldLandscape(AdventureWorld(stage: stage));
        final second = FieldLandscape(world);
        expect(first.regions.length, inInclusiveRange(8, 10));
        expect(
          first.regions.map((r) => r.id).toSet().length,
          first.regions.length,
        );
        signatures.add(
          first.regions.map((r) => '${r.id}:${r.center}').join('|'),
        );
        for (var i = 0; i < first.regions.length; i++) {
          expect(first.regions[i].outline, second.regions[i].outline);
          expect(
            first.regions[i].path.contains(first.regions[i].center),
            isTrue,
          );
          expect(first.regions[i].bounds.width, greaterThan(1000));
          expect(first.regions[i].bounds.height, greaterThan(1000));
        }
        for (var y = 0; y < 9; y++) {
          for (var x = 0; x < 11; x++) {
            final p = ui.Offset(
              (x + .37) / 11 * worldSize.width,
              (y + .29) / 9 * worldSize.height,
            );
            expect(
              first.regions.any((r) => r.path.contains(p)),
              isTrue,
              reason: '${stage.name}: $p',
            );
          }
        }
      }
      expect(signatures.length, 7);
    },
  );

  test(
    'water, wells and actual settlement stay protected without a rectangular exterior band',
    () async {
      final world = AdventureWorld();
      final field = FieldLandscape(world);
      Future<int> alphaAt(ui.Offset p, {bool overview = false}) async {
        final view = ui.Rect.fromCenter(center: p, width: 8, height: 8);
        final rgba = await pixels((c) {
          c.translate(32 - p.dx, 32 - p.dy);
          if (overview) {
            field.paintOverview(c, view);
          } else {
            field.paintGround(c, view, details: shaders);
          }
        });
        return rgba[(32 * 64 + 32) * 4 + 3];
      }

      for (final p in [
        world.settlement.center,
        world.sites.first.body.center,
        world.lakes.first.bounds.center,
      ]) {
        expect(await alphaAt(p), 0);
        expect(await alphaAt(p, overview: true), 0);
      }
      final town = world.settlement;
      final exterior =
          [
            ui.Offset(town.right + 35, town.center.dy),
            ui.Offset(town.left - 35, town.center.dy),
            ui.Offset(town.center.dx, town.bottom + 35),
          ].firstWhere(
            (p) =>
                !world.isWater(p) &&
                !world.sites.any((s) => s.body.inflate(8).contains(p)),
          );
      expect(await alphaAt(exterior), 255);
      expect(await alphaAt(exterior, overview: true), 255);
    },
  );

  test(
    'global material and palette sampling is continuous across sector clips',
    () async {
      final world = AdventureWorld();
      final field = FieldLandscape(world);
      final at = dryPoint(world);
      final view = ui.Rect.fromLTWH(at.dx + .25, at.dy + .25, 1024, 1024);
      final colors = List.generate(
        192,
        (i) => ui.Color.fromARGB(
          255,
          80 + i % 9 * 12,
          90 + i % 7 * 13,
          60 + i % 5 * 17,
        ),
      );
      Future<Uint8List> render(bool split) => pixels((c) {
        c.scale(.125);
        c.translate(-view.left, -view.top);
        if (!split) {
          field.paintGround(c, view, details: shaders, macroColors: colors);
        } else {
          for (var y = 0; y < 2; y++) {
            for (var x = 0; x < 2; x++) {
              field.paintGround(
                c,
                ui.Rect.fromLTWH(
                  view.left + x * 512,
                  view.top + y * 512,
                  512,
                  512,
                ),
                details: shaders,
                macroColors: colors,
              );
            }
          }
        }
      }, 128);
      final direct = await render(false), sectors = await render(true);
      var delta = 0;
      for (var i = 0; i < direct.length; i++) {
        delta += (direct[i] - sectors[i]).abs();
      }
      expect(delta / direct.length, lessThan(.4));
      expect(direct.where((v) => v != 0).length, greaterThan(1000));
    },
  );

  test(
    'generated macro ground colors alter actual playable ground and overview',
    () async {
      final world = AdventureWorld();
      final field = FieldLandscape(world);
      final at = dryPoint(world),
          view = ui.Rect.fromCenter(
            center: dryPoint(world),
            width: 64,
            height: 64,
          );
      Future<Uint8List> render(ui.Color color, bool overview) => pixels((c) {
        c.translate(32 - at.dx, 32 - at.dy);
        final palette = List.filled(192, color);
        if (overview) {
          field.paintOverview(c, view, macroColors: palette);
        } else {
          field.paintGround(c, view, details: shaders, macroColors: palette);
        }
      });
      for (final overview in [false, true]) {
        final warm = await render(const ui.Color(0xffc99e55), overview);
        final cool = await render(const ui.Color(0xff456f99), overview);
        expect(warm, isNot(orderedEquals(cool)));
      }
    },
  );

  test(
    'actual forest sand remains visibly dry beneath biome-specific enemies',
    () async {
      final world = AdventureWorld();
      final field = FieldLandscape(world);
      ui.Offset? sample;
      for (final sand in world.sandFields) {
        for (
          double y = sand.bounds.top + 100;
          y < sand.bounds.bottom;
          y += 150
        ) {
          for (
            double x = sand.bounds.left + 100;
            x < sand.bounds.right;
            x += 150
          ) {
            final p = ui.Offset(x, y);
            if (world.isSand(p) &&
                !world.isWater(p) &&
                !world.settlement.inflate(150).contains(p) &&
                !world.sites.any(
                  (site) => site.body.inflate(100).contains(p),
                )) {
              sample = p;
              break;
            }
          }
          if (sample != null) break;
        }
        if (sample != null) break;
      }
      expect(sample, isNotNull);
      final at = sample!;
      final rgba = await pixels((c) {
        c.translate(32 - at.dx, 32 - at.dy);
        field.paintGround(
          c,
          ui.Rect.fromCenter(center: at, width: 64, height: 64),
          details: shaders,
        );
      });
      final index = (32 * 64 + 32) * 4;
      expect(rgba[index], greaterThan(rgba[index + 1] + 10));
      expect(rgba[index + 1], greaterThan(rgba[index + 2] + 10));
    },
  );

  test(
    'rendering leaves actual biome, road and collision definitions unchanged',
    () async {
      for (final stage in WorldStage.values) {
        final world = AdventureWorld(stage: stage);
        final field = FieldLandscape(world);
        final sand = world.sandFields.map((s) => s.points.toList()).toList();
        final woods = world.woods.map((s) => s.points.toList()).toList();
        final roads = world.trails.map((s) => s.points.toList()).toList();
        final at = dryPoint(world),
            body = ui.Rect.fromCenter(
              center: dryPoint(world),
              width: 28,
              height: 24,
            );
        final blocked = world.blocked(body);
        await pixels((c) {
          c.translate(32 - at.dx, 32 - at.dy);
          field.paintGround(
            c,
            ui.Rect.fromCenter(center: at, width: 64, height: 64),
            details: shaders,
          );
        });
        expect(world.sandFields.map((s) => s.points.toList()).toList(), sand);
        expect(world.woods.map((s) => s.points.toList()).toList(), woods);
        expect(world.trails.map((s) => s.points.toList()).toList(), roads);
        expect(world.blocked(body), blocked);
      }
    },
  );
}

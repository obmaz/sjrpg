import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameArt art;
  late AdventureWorld world;
  setUp(() async {
    world = AdventureWorld();
    world.trails = [];
    art = GameArt();
    final palette = List<ui.Color>.filled(12, const ui.Color(0xff208020));
    palette[3] = const ui.Color(0xffcc8822);
    palette[4] = const ui.Color(0xff156acc);
    palette[5] = const ui.Color(0xffe0bb55);
    for (var i = 0; i < palette.length; i++) {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(palette[i], ui.BlendMode.src);
      final picture = recorder.endRecording(),
          image = await picture.toImage(1, 1);
      picture.dispose();
      art.images['test-$i'] = image;
      art.materials.add(
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
      );
    }
  });
  tearDown(() {
    for (final shader in art.materials) {
      shader.dispose();
    }
    for (final image in art.images.values) {
      image.dispose();
    }
  });
  Future<List<int>> pixel(ui.Offset point) async {
    final col = (point.dx / 512).floor(), row = (point.dy / 512).floor();
    final terrain = TerrainArt(world, art), recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..translate(-col * 512.0, -row * 512.0);
    canvas.drawPicture(terrain.sector(col, row));
    final picture = recorder.endRecording(),
        image = await picture.toImage(512, 512);
    picture.dispose();
    terrain.dispose();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final index =
        ((point.dy.floor() - row * 512) * 512 + point.dx.floor() - col * 512) *
        4;
    final result = [for (var i = 0; i < 3; i++) bytes.getUint8(index + i)];
    image.dispose();
    return result;
  }

  test(
    'river banks inside an overlapping lake remain visually water',
    () async {
      final lake = world.lakes.first;
      final point =
          [
            for (final p in world.river.points)
              for (final dx in [-10.0, 10.0]) p + ui.Offset(dx, 0),
          ].firstWhere(
            (p) =>
                lake.bounds.deflate(120).contains(p) &&
                lake.contains(p) &&
                !world.river.contains(p),
          );
      expect(world.isWater(point), true);
      final rgb = await pixel(point);
      expect(
        rgb[2],
        greaterThan(rgb[0] + 30),
        reason: 'water must not look like a sandy road at $point',
      );
    },
  );
  test(
    'ordinary roads and their shadows cannot paint dry ground over water',
    () async {
      final point = world.lakes.first.bounds.center;
      expect(world.isWater(point), true);
      final water = await pixel(point);
      world.trails = [
        Trail([
          point - const ui.Offset(220, 0),
          point + const ui.Offset(220, 0),
        ], 100),
      ];
      expect(await pixel(point), water);
    },
  );
  test('the real outer shoreline still looks like a bank', () async {
    final edge = world.lakes.first.points.reduce((a, b) => a.dx > b.dx ? a : b);
    final point = edge + const ui.Offset(10, 0);
    expect(world.isWater(point), false);
    final rgb = await pixel(point);
    expect(rgb[0], greaterThan(rgb[2] + 40));
  });
  test('an explicitly walkable bridge is drawn over the water', () async {
    final point = world.bridge.center;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xffaa5533), ui.BlendMode.src);
    final picture = recorder.endRecording();
    art.images['landscape-bridge'] = await picture.toImage(2048, 768);
    picture.dispose();
    expect(
      world.blocked(ui.Rect.fromCenter(center: point, width: 28, height: 24)),
      false,
    );
    final rgb = await pixel(point);
    expect(rgb[0], greaterThan(rgb[2] + 40));
  });
  test(
    'the expanded map uses the same water and explicit bridge boundaries',
    () async {
      final session = Adventure(art);
      addTearDown(session.dispose);
      session.world.trails = [];
      Future<List<int>> mapPixel(ui.Offset point) async {
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        MapPainter(
          session,
          round: false,
        ).paint(canvas, const ui.Size(1200, 900));
        final picture = recorder.endRecording(),
            image = await picture.toImage(1200, 900);
        picture.dispose();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final x = (point.dx / worldSize.width * 1200).floor(),
            y = (point.dy / worldSize.height * 900).floor();
        final index = (y * 1200 + x) * 4;
        final result = [for (var i = 0; i < 3; i++) data.getUint8(index + i)];
        image.dispose();
        return result;
      }

      final lake = session.world.lakes.first,
          center = session.world.lakes.first.bounds.center;
      final insideBank =
          [
            for (final p in session.world.river.points)
              for (final dx in [-45.0, 45.0]) p + ui.Offset(dx, 0),
          ].firstWhere(
            (p) =>
                lake.bounds.deflate(120).contains(p) &&
                lake.contains(p) &&
                !session.world.river.contains(p),
          );
      final water = await mapPixel(center), bank = await mapPixel(insideBank);
      expect(bank[2], greaterThan(bank[0] + 30));
      session.world.trails = [
        Trail([
          center - const ui.Offset(220, 0),
          center + const ui.Offset(220, 0),
        ], 150),
      ];
      expect(await mapPixel(center), water);
      final bridge = await mapPixel(session.world.bridge.center);
      expect(bridge[0], greaterThan(bridge[2] + 40));
    },
  );
}

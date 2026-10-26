import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'actor_atlas.dart';
import 'effect_atlas.dart';
import 'ground_texture.dart';
import 'interface_art.dart';
import 'world_model.dart';

class GameArt {
  final images = <String, ui.Image>{};
  late final effects = EffectAtlas(images);
  late final Map<String, dynamic> actors, controls;
  final materials = <ui.Shader>[];
  final _actorAtlases = <String, ActorAtlas>{};
  late final _actorPaint = ui.Paint()..filterQuality = ui.FilterQuality.low;
  late final _rollPaint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
  ActorAtlas _atlas(String sheet) {
    final cached = _actorAtlases[sheet];
    if (cached != null) return cached;
    final atlas = ActorAtlas.fromJson(actors[sheet] as Map<String, dynamic>);
    _actorAtlases[sheet] = atlas;
    return atlas;
  }

  static Future<GameArt> load() async {
    final art = GameArt();
    final data =
        jsonDecode(await rootBundle.loadString('assets/art.json'))
            as Map<String, dynamic>;
    art.actors = data['actors'];
    art.controls = data['controls'];
    for (final sheet in art.actors.keys) {
      art._atlas(sheet);
    }
    await Future.wait(
      [
            'actors-hero',
            'actors-mage',
            'gear-icons',
            'combat-fx',
            'passive-icons',
            'skill-perks',
            'physical-icons',
            'fx-meteor',
            'fx-ice-nova',
            'fx-whirlwind',
            'fx-steel-whirlwind',
            'victory-crest',
            'well-portal',
            'fx-warcry',
            'dodge-icon',
            'actors-roll',
            'terrain-materials',
            'actors-hero-attack',
            'actors-hero-backhand',
            'actors-hero-cleave',
            'actors-mage-cast',
            'actors-creatures-a',
            'actors-creatures-b',
            'actors-villagers',
            'quest-sites',
            'time-sites',
            'time-paths',
            'stage-materials',
            'actors-cyber',
            'actors-gunner',
            'actors-sand-warden',
            'actors-ancient-king',
            'actors-cyber-core',
            'actors-bicycle',
            'actors-motor',
            'actors-horse',
            'actors-boat',
            'actors-boar',
            'actors-basilisk',
            'actors-wraith',
            'actors-drone',
            'cyber-props',
            'ruin-props',
            'village-scene',
            'landscape-bridge',
            'world-forest',
            'world-desert',
            'controls',
            'popup-frame',
            'atlas',
          ]
          .map<Future<void>>((name) async {
            final extension =
                const {
                  'actors-mage',
                  'actors-motor',
                  'actors-horse',
                  'actors-boat',
                  'gear-icons',
                  'combat-fx',
                  'dodge-icon',
                  'actors-roll',
                }.contains(name)
                ? 'png'
                : 'webp';
            final bytes = await rootBundle.load(
              'assets/images/$name.$extension',
            );
            final codec = await ui.instantiateImageCodec(
              bytes.buffer.asUint8List(),
            );
            art.images[name] = (await codec.getNextFrame()).image;
            codec.dispose();
          })
          .followedBy([prepareInterfaceArtwork()]),
    );
    art.effects.warm();
    final atlas = art.images['terrain-materials']!;
    for (var i = 0; i < 12; i++) {
      final source = i < 6 ? atlas : art.images['stage-materials']!;
      final cell = i % 6;
      const tileSize = 192;
      final recorder = ui.PictureRecorder();
      // A separate recorder per material keeps shaders small and shared by every sector.
      final c = ui.Canvas(recorder);
      final crop = ui.Rect.fromLTWH(
        (cell % 3) * source.width / 3 + 12,
        (cell ~/ 3) * source.height / 2 + 12,
        source.width / 3 - 24,
        source.height / 2 - 24,
      );
      if (i < 6) {
        paintSeamlessGround(c, source, crop, tileSize.toDouble());
      } else {
        c.drawImageRect(
          source,
          crop,
          ui.Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()),
          ui.Paint(),
        );
      }
      final picture = recorder.endRecording(),
          image = await picture.toImage(tileSize, tileSize);
      picture.dispose();
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
      // CanvasKit can rebuild a shader for another paint quality; retain its small image.
      art.images['ground-$i'] = image;
    }
    // Ground draws the baked shader textures, so the two full source atlases can be released.
    art.images.remove('terrain-materials')!.dispose();
    art.images.remove('stage-materials')!.dispose();
    // Bake the edge mask once. Gameplay draws this texture without per-frame layers.
    final village = art.images['village-scene']!,
        rec = ui.PictureRecorder(),
        canvas = ui.Canvas(rec);
    const target = ui.Rect.fromLTWH(0, 0, 640, 960),
        clear = ui.Color(0x00ffffff),
        full = ui.Color(0xffffffff);
    canvas.drawImageRect(
      village,
      ui.Rect.fromLTWH(
        0,
        0,
        village.width.toDouble(),
        village.height.toDouble(),
      ),
      target,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    for (final mask in [
      (
        const ui.Rect.fromLTWH(0, 0, 64, 960),
        const ui.Offset(0, 0),
        const ui.Offset(64, 0),
      ),
      (
        const ui.Rect.fromLTWH(576, 0, 64, 960),
        const ui.Offset(640, 0),
        const ui.Offset(576, 0),
      ),
      (
        const ui.Rect.fromLTWH(0, 0, 640, 64),
        const ui.Offset(0, 0),
        const ui.Offset(0, 64),
      ),
      (
        const ui.Rect.fromLTWH(0, 832, 640, 128),
        const ui.Offset(0, 960),
        const ui.Offset(0, 832),
      ),
    ]) {
      canvas.drawRect(
        mask.$1,
        ui.Paint()
          ..blendMode = ui.BlendMode.dstIn
          ..shader = ui.Gradient.linear(mask.$2, mask.$3, [clear, full]),
      );
    }
    final picture = rec.endRecording();
    art.images['village-blended'] = await picture.toImage(640, 960);
    picture.dispose();
    return art;
  }

  void landmark(
    ui.Canvas canvas,
    int index,
    ui.Offset feet,
    double side, {
    bool themed = false,
    double opacity = 1,
  }) {
    final image = images[themed ? 'time-sites' : 'quest-sites'];
    if (image == null) return;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(
        themed ? index % 4 * image.width / 4 : index * image.width / 3,
        themed ? index ~/ 4 * image.height / 2 : 0,
        image.width / (themed ? 4 : 3),
        image.height / (themed ? 2 : 1),
      ),
      ui.Rect.fromLTWH(feet.dx - side / 2, feet.dy - side * .9375, side, side),
      ui.Paint()
        ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
        ..filterQuality = ui.FilterQuality.medium,
    );
  }

  void cityProp(
    ui.Canvas canvas,
    int index,
    ui.Offset feet,
    double side, {
    double opacity = 1,
  }) {
    final image = images['cyber-props'];
    if (image == null) return;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(
        index % 4 * image.width / 4,
        index ~/ 4 * image.height / 2,
        image.width / 4,
        image.height / 2,
      ),
      ui.Rect.fromLTWH(feet.dx - side / 2, feet.dy - side * .9375, side, side),
      ui.Paint()
        ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
        ..filterQuality = ui.FilterQuality.medium,
    );
  }

  void actor(
    ui.Canvas canvas,
    String key,
    ui.Offset feet,
    double angle,
    int phase,
    double height, {
    bool attack = false,
    int comboPose = 0,
    double opacity = 1,
    double flash = 0,
  }) {
    const definitions = {
      'hero': ('hero', 0, 16),
      'mage': ('mage', 0, 16),
      'goblin': ('creatures-a', 0, 8),
      'boar': ('boar', 0, 8),
      'basilisk': ('basilisk', 0, 8),
      'wraith': ('wraith', 0, 8),
      'drone': ('drone', 0, 8),
      'wolf': ('creatures-a', 1, 8),
      'skeleton': ('creatures-a', 2, 8),
      'cultist': ('creatures-a', 3, 8),
      'golem': ('creatures-b', 1, 8),
      'scorpion': ('creatures-b', 2, 8),
      'mummy': ('creatures-b', 3, 8),
      'troll': ('creatures-b', 0, 8),
      'cyber': ('cyber', 0, 8),
      'gunner': ('gunner', 0, 8),
      'sand-warden': ('sand-warden', 0, 8),
      'ancient-king': ('ancient-king', 0, 8),
      'cyber-core': ('cyber-core', 0, 8),
      'merchant': ('villagers', 0, 8),
      'villager': ('villagers', 1, 8),
      'horse': ('horse', 0, 8),
      'bicycle': ('bicycle', 0, 8),
      'motor': ('motor', 0, 8),
      'boat': ('boat', 0, 8),
    };
    final definition = definitions[key]!;
    final sheet = attack && key == 'hero'
            ? const ['hero-attack', 'hero-backhand', 'hero-cleave'][comboPose
                  .clamp(0, 2)]
            : attack && key == 'mage'
            ? 'mage-cast'
            : definition.$1,
        count = definition.$3;
    final index =
        const {
          'cyber',
          'gunner',
          'sand-warden',
          'ancient-king',
          'cyber-core',
          'bicycle',
          'motor',
          'horse',
          'boat',
          'boar',
          'basilisk',
          'wraith',
          'drone',
        }.contains(key)
        ? facingFrame(angle, 8) * 2 + phase % 2
        : count == 16
        ? facingFrame(angle, count) + (phase % 2) * 16
        : definition.$2 * 8 + facingFrame(angle, count) + (phase % 2) * 32;
    final atlas = _atlas(sheet), frame = atlas.frames[index];
    final scale = height / atlas.heights[definition.$2], src = frame.source;
    final dst = ui.Rect.fromLTWH(
      feet.dx - frame.anchor.dx * scale,
      feet.dy - frame.anchor.dy * scale,
      src.width * scale,
      src.height * scale,
    );
    final mirror = frame.mirrored;
    if (mirror) {
      canvas.save();
      canvas.translate(feet.dx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-feet.dx, 0);
    }
    canvas.drawImageRect(
      images['actors-$sheet']!,
      src,
      dst,
      _actorPaint
        ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
        ..colorFilter = flash > 0
            ? ui.ColorFilter.mode(
                ui.Color.fromRGBO(255, 249, 220, flash.clamp(0, 1)),
                ui.BlendMode.srcATop,
              )
            : null,
    );
    if (mirror) canvas.restore();
  }

  void roll(
    ui.Canvas canvas,
    ui.Offset feet,
    double angle,
    int phase, {
    required bool mage,
  }) {
    final atlas = _atlas('roll');
    final index =
        (mage ? 32 : 0) + (phase.clamp(0, 3) * 8) + facingFrame(angle, 8);
    final src = atlas.frames[index].source;
    final scale = 43 / atlas.heights[mage ? 1 : 0];
    canvas.drawImageRect(
      images['actors-roll']!,
      src,
      ui.Rect.fromLTWH(
        feet.dx - src.width * scale / 2,
        feet.dy - src.height * scale,
        src.width * scale,
        src.height * scale,
      ),
      _rollPaint,
    );
  }

  void prop(ui.Canvas canvas, WorldProp prop, {double opacity = 1}) {
    if (prop.kind.startsWith('ruin-')) {
      final image = images['ruin-props'];
      if (image == null) return;
      final index = int.parse(prop.kind.substring(5)),
          side = prop.drawSize.height;
      final feet = prop.body.bottomCenter;
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(
          index % 4 * image.width / 4,
          index ~/ 4 * image.height / 2,
          image.width / 4,
          image.height / 2,
        ),
        ui.Rect.fromLTWH(
          feet.dx - side / 2,
          feet.dy - side * .9375,
          side,
          side,
        ),
        ui.Paint()
          ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
          ..filterQuality = ui.FilterQuality.medium,
      );
      return;
    }
    if (prop.kind.startsWith('city-')) {
      cityProp(
        canvas,
        int.parse(prop.kind.substring(5)),
        prop.body.bottomCenter,
        prop.drawSize.height,
        opacity: opacity,
      );
      return;
    }
    if (prop.kind == 'ruin' || prop.kind == 'relay') {
      landmark(
        canvas,
        prop.kind == 'relay' ? 5 : 1,
        prop.body.bottomCenter,
        prop.drawSize.height,
        themed: true,
        opacity: opacity,
      );
      return;
    }

    final image =
            images[prop.kind == 'cactus' ? 'world-desert' : 'world-forest']!,
        cell = image.width / 4;
    final index = prop.kind == 'tree'
        ? 8
        : prop.kind == 'cactus'
        ? 1
        : 10;
    final feet = prop.body.bottomCenter;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH((index % 4) * cell, (index ~/ 4) * cell, cell, cell),
      ui.Rect.fromLTWH(
        feet.dx - prop.drawSize.width / 2,
        feet.dy - prop.drawSize.height * .88,
        prop.drawSize.width,
        prop.drawSize.height,
      ),
      ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, opacity),
    );
  }

  void control(ui.Canvas canvas, String key, ui.Rect destination) {
    final v = controls[key] as List;
    canvas.drawImageRect(
      images['controls']!,
      ui.Rect.fromLTWH(
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        (v[2] as num).toDouble(),
        (v[3] as num).toDouble(),
      ),
      destination,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  void text(
    ui.Canvas canvas,
    String value,
    ui.Offset at, {
    double size = 16,
    ui.Color color = const ui.Color(0xffffedbb),
  }) {
    final paragraph = layoutText(value, size: size, color: color);
    canvas.drawParagraph(paragraph, at - const ui.Offset(80, 0));
    paragraph.dispose();
  }

  ui.Paragraph layoutText(
    String value, {
    double size = 16,
    ui.Color color = const ui.Color(0xffffedbb),
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontFamily: 'Guardian',
              fontSize: size,
              textAlign: ui.TextAlign.center,
            ),
          )
          ..pushStyle(
            ui.TextStyle(color: color, fontWeight: ui.FontWeight.bold),
          )
          ..addText(value);
    return builder.build()..layout(const ui.ParagraphConstraints(width: 160));
  }
}

class TerrainArt {
  TerrainArt(this.world, this.art);
  final AdventureWorld world;
  final GameArt art;
  final cache = <String, ui.Picture>{};
  late final ui.Path waterPath = [...world.lakes, world.river]
      .map((region) => region.path)
      .reduce((a, b) => ui.Path.combine(ui.PathOperation.union, a, b));
  late final ui.Path dryGroundPath = ui.Path.combine(
    ui.PathOperation.difference,
    ui.Path()..addRect(ui.Offset.zero & worldSize),
    waterPath,
  );
  ui.Picture sector(int col, int row) {
    final key = '$col:$row';
    if (cache.containsKey(key)) return cache[key]!;
    final recorder = ui.PictureRecorder(),
        c = ui.Canvas(recorder),
        area = ui.Rect.fromLTWH(col * 512.0, row * 512.0, 512, 512);
    c.clipRect(area);
    final base = world.stage == WorldStage.forest ? 0 : 5 + world.stage.index;
    final road = world.stage == WorldStage.forest ? 5 : 8 + world.stage.index;
    c.drawRect(area, ui.Paint()..shader = art.materials[base]);
    for (final wood in world.woods) {
      if (!wood.bounds.overlaps(area.inflate(80))) continue;
      c.drawPath(wood.path, ui.Paint()..shader = art.materials[1]);
      c.drawPath(
        wood.path,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 50
          ..color = const ui.Color(0x22335336),
      );
    }
    for (final clearing in world.clearings) {
      if (clearing.bounds.overlaps(area)) {
        c.drawPath(clearing.path, ui.Paint()..shader = art.materials[base]);
      }
    }
    for (final sand in world.sandFields) {
      if (sand.bounds.overlaps(area)) {
        c.drawPath(
          sand.path,
          ui.Paint()
            ..shader = art.materials[world.stage == WorldStage.sands ? 6 : 2],
        );
      }
    }
    final nearWater = [
      ...world.lakes,
      world.river,
    ].any((region) => region.bounds.overlaps(area.inflate(40)));
    if (nearWater) {
      c.drawPath(
        waterPath,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 42
          ..shader = art.materials[3],
      );
      c.drawPath(waterPath, ui.Paint()..shader = art.materials[4]);
      c.drawPath(
        waterPath,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const ui.Color(0x999ce0c4),
      );
    }
    c.save();
    if (nearWater) c.clipPath(dryGroundPath, doAntiAlias: false);
    for (final t in world.trails) {
      if (!t.bounds.inflate(t.width / 2 + 2).overlaps(area)) continue;
      c.drawPath(
        t.path,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round
          ..strokeWidth = t.width + 26
          ..color = const ui.Color(0x55917d50),
      );
    }
    for (final t in world.trails) {
      if (!t.bounds.inflate(t.width / 2 + 2).overlaps(area)) continue;
      c.drawPath(
        t.path,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round
          ..strokeWidth = t.width
          ..shader = art.materials[road],
      );
    }
    c.restore();
    for (final bridge in world.bridges) {
      if (!bridge.overlaps(area)) continue;
      c.drawImageRect(
        art.images['landscape-bridge']!,
        const ui.Rect.fromLTWH(50, 112, 1880, 540),
        bridge,
        ui.Paint(),
      );
    }
    if (world.stage == WorldStage.forest && town.inflate(30).overlaps(area)) {
      final village = art.images['village-blended']!;
      c.drawImageRect(
        village,
        ui.Rect.fromLTWH(
          0,
          0,
          village.width.toDouble(),
          village.height.toDouble(),
        ),
        town,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
    }
    final sanctuary = world.sanctuary;
    if (sanctuary.protects(area.inflate(4))) {
      final color = world.stage.sanctuaryColor;
      c.drawCircle(
        sanctuary.center,
        sanctuary.radius,
        ui.Paint()..color = color.withValues(alpha: .035),
      );
      c.drawCircle(
        sanctuary.center,
        sanctuary.radius,
        ui.Paint()
          ..color = color.withValues(alpha: .45)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    // Deterministic dappled light is presentation-only and never consumes gameplay RNG.
    final random = math.Random(col * 739 + row * 838 + world.seed);
    for (var i = 0; i < 5; i++) {
      final p = ui.Offset(
        area.left + random.nextDouble() * 512,
        area.top + random.nextDouble() * 512,
      );
      c.drawCircle(
        p,
        100,
        ui.Paint()
          ..shader = ui.Gradient.radial(p, 100, [
            const ui.Color(0x0ff1d393),
            const ui.Color(0x00f1d393),
          ]),
      );
    }
    final picture = recorder.endRecording();
    cache[key] = picture;
    if (cache.length > 24) {
      final old = cache.keys.first;
      cache.remove(old)?.dispose();
    }
    return picture;
  }

  void render(ui.Canvas canvas, ui.Rect view) {
    for (
      var y = (view.top / 512).floor();
      y <= (view.bottom / 512).floor();
      y++
    ) {
      for (
        var x = (view.left / 512).floor();
        x <= (view.right / 512).floor();
        x++
      ) {
        canvas.drawPicture(sector(x, y));
      }
    }
  }

  void dispose() {
    for (final picture in cache.values) {
      picture.dispose();
    }
    cache.clear();
  }
}

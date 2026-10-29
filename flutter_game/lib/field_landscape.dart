import 'dart:math' as math;
import 'dart:ui' as ui;

import 'world_model.dart';

/// The four shared full-resolution surface families, in loader shader order.
enum FieldGround { meadow, desert, stone, industrial }

enum FieldGrain { braided, windward, weathered, strata, scattered, tracked }

class FieldRegionPlan {
  FieldRegionPlan._(
    this.id,
    this.ground,
    this.accent,
    this.grain,
    this.center,
    this.outline,
    this.baseColor,
  ) : path = ui.Path()..addPolygon(outline, true),
      bounds = ui.Rect.fromPoints(
        ui.Offset(
          outline.map((p) => p.dx).reduce(math.min),
          outline.map((p) => p.dy).reduce(math.min),
        ),
        ui.Offset(
          outline.map((p) => p.dx).reduce(math.max),
          outline.map((p) => p.dy).reduce(math.max),
        ),
      );
  final String id;
  final FieldGround ground, accent;
  final FieldGrain grain;
  final ui.Offset center;
  final List<ui.Offset> outline;
  final ui.Path path;
  final ui.Rect bounds;
  final ui.Color baseColor;
}

typedef _District = ({
  String id,
  double x,
  double y,
  FieldGround ground,
  FieldGround accent,
  FieldGrain grain,
});

_District _district(
  String id,
  double x,
  double y,
  FieldGround ground,
  FieldGround accent,
  FieldGrain grain,
) => (id: id, x: x, y: y, ground: ground, accent: accent, grain: grain);

/// A continuous, world-aligned field surface. Large neighboring districts share
/// their curved boundaries; fine material is sampled at gameplay resolution.
/// No geometry, random stream, enemy state, road or water definition is changed.
class FieldLandscape {
  FieldLandscape(this.world) {
    final districts = _districts(world.stage);
    regions = List.unmodifiable([
      for (final district in districts) _region(district, districts),
    ]);
    _biomes = [
      for (final (index, shape) in world.woods.indexed)
        _biome(
          'wood-$index',
          shape,
          FieldGround.meadow,
          const ui.Color(0xffabbc94),
          190,
        ),
      for (final (index, shape) in world.clearings.indexed)
        _biome(
          'clearing-$index',
          shape,
          _base(world.stage),
          const ui.Color(0xffecf0cd),
          180,
        ),
      for (final (index, shape) in world.sandFields.indexed)
        _biome(
          'sand-$index',
          shape,
          FieldGround.desert,
          const ui.Color(0xffffffff),
          world.stage == WorldStage.forest ? 245 : 125,
        ),
    ];
    var protected = ui.Path()..addRect(world.settlement);
    for (final site in world.sites) {
      // Existing well/garden art is painted above this layer. Excluding a large
      // rectangle around transparent art would leave an old-ground square.
      protected.addRect(site.body.inflate(8));
    }
    var water = world.river.path;
    for (final lake in world.lakes) {
      water = ui.Path.combine(ui.PathOperation.union, water, lake.path);
    }
    protected = ui.Path.combine(ui.PathOperation.union, protected, water);
    _groundClip = ui.Path.combine(
      ui.PathOperation.difference,
      ui.Path()..addRect(ui.Offset.zero & worldSize),
      protected,
    );
    // Follow the actual visible material: macro -> woods -> clearings -> sand.
    var sandy = ui.Path();
    if (world.stage == WorldStage.sands) {
      sandy.addRect(ui.Offset.zero & worldSize);
    } else {
      for (final region in regions.where(
        (r) => r.ground == FieldGround.desert,
      )) {
        sandy = ui.Path.combine(ui.PathOperation.union, sandy, region.path);
      }
      for (final biome in _biomes) {
        sandy = ui.Path.combine(
          biome.region.ground == FieldGround.desert
              ? ui.PathOperation.union
              : ui.PathOperation.difference,
          sandy,
          biome.region.path,
        );
      }
    }
    _sandClip = ui.Path.combine(ui.PathOperation.intersect, sandy, _groundClip);
    _hardTrailClip = ui.Path.combine(
      ui.PathOperation.difference,
      ui.Path()..addRect(ui.Offset.zero & worldSize),
      _sandClip,
    );
  }
  final AdventureWorld world;
  late final List<FieldRegionPlan> regions;
  late final ui.Path _groundClip, _sandClip, _hardTrailClip;
  bool isSandyGround(ui.Offset point) => _sandClip.contains(point);
  void clipHardTrailGround(ui.Canvas canvas) =>
      canvas.clipPath(_hardTrailClip, doAntiAlias: false);
  late final List<({FieldRegionPlan region, ui.Color tint, int alpha})> _biomes;
  ({FieldRegionPlan region, ui.Color tint, int alpha}) _biome(
    String id,
    RegionShape shape,
    FieldGround ground,
    ui.Color tint,
    int alpha,
  ) => (
    region: FieldRegionPlan._(
      id,
      ground,
      ground,
      FieldGrain.scattered,
      shape.bounds.center,
      List.unmodifiable(shape.points),
      _color(ground),
    ),
    tint: tint,
    alpha: alpha,
  );
  static const paletteColumns = 16, paletteRows = 12;

  static FieldGround _base(WorldStage stage) => switch (stage) {
    WorldStage.forest || WorldStage.convergence => FieldGround.meadow,
    WorldStage.sands => FieldGround.desert,
    WorldStage.past || WorldStage.tombs => FieldGround.stone,
    WorldStage.future || WorldStage.foundry => FieldGround.industrial,
  };
  static ui.Color _color(FieldGround ground) => switch (ground) {
    FieldGround.meadow => const ui.Color(0xff788755),
    FieldGround.desert => const ui.Color(0xffbea16b),
    FieldGround.stone => const ui.Color(0xff96907b),
    FieldGround.industrial => const ui.Color(0xff637177),
  };

  FieldRegionPlan _region(_District district, List<_District> all) {
    var polygon = const [
      ui.Offset.zero,
      ui.Offset(1, 0),
      ui.Offset(1, 1),
      ui.Offset(0, 1),
    ];
    final center = ui.Offset(district.x, district.y);
    for (final other in all) {
      if (identical(district, other) || district.id == other.id) continue;
      final neighbor = ui.Offset(other.x, other.y), normal = neighbor - center;
      final limit = (neighbor.distanceSquared - center.distanceSquared) / 2;
      final clipped = <ui.Offset>[];
      for (var i = 0; i < polygon.length; i++) {
        final a = polygon[i], b = polygon[(i + 1) % polygon.length];
        final da = a.dx * normal.dx + a.dy * normal.dy - limit;
        final db = b.dx * normal.dx + b.dy * normal.dy - limit;
        if (da <= 1e-12) clipped.add(a);
        if ((da < 0) != (db < 0)) {
          clipped.add(ui.Offset.lerp(a, b, da / (da - db))!);
        }
      }
      polygon = clipped;
    }
    final outline = <ui.Offset>[];
    for (var edge = 0; edge < polygon.length; edge++) {
      final a = polygon[edge], b = polygon[(edge + 1) % polygon.length];
      final length = ui.Offset(
        (a.dx - b.dx) * worldSize.width,
        (a.dy - b.dy) * worldSize.height,
      ).distance;
      final steps = math.max(1, (length / 400).ceil());
      for (var step = 0; step < steps; step++) {
        outline.add(_warp(ui.Offset.lerp(a, b, step / steps)!));
      }
    }
    return FieldRegionPlan._(
      district.id,
      district.ground,
      district.accent,
      district.grain,
      _warp(center),
      List.unmodifiable(outline),
      _color(district.ground),
    );
  }

  ui.Offset _warp(ui.Offset p) {
    final phase = world.stage.index * .91;
    return ui.Offset(
      p.dx * worldSize.width +
          math.sin(math.pi * p.dx) * math.sin(p.dy * math.pi * 3 + phase) * 780,
      p.dy * worldSize.height +
          math.sin(math.pi * p.dy) * math.sin(p.dx * math.pi * 2 - phase) * 620,
    );
  }

  /// Call after base biomes, before actual water, roads, bridges and actors.
  /// Colors are a prefiltered 16x12 ground-only palette, never a map photograph.
  /// Details have the fixed meadow/desert/stone/industrial order.
  void paintGround(
    ui.Canvas canvas,
    ui.Rect sector, {
    List<ui.Color>? macroColors,
    List<ui.Shader>? details,
  }) {
    if (!sector.overlaps(ui.Offset.zero & worldSize)) return;
    canvas.save();
    canvas.clipRect(sector, doAntiAlias: false);
    canvas.clipPath(_groundClip, doAntiAlias: false);
    final shaders = details?.length == 4 ? details : null;
    if (shaders != null) {
      canvas.drawRect(
        sector,
        ui.Paint()
          ..isAntiAlias = false
          ..shader = shaders[_base(world.stage).index],
      );
    }
    for (final (index, region) in regions.indexed) {
      if (!region.bounds.overlaps(sector)) continue;
      if (shaders == null) {
        canvas.drawPath(
          region.path,
          ui.Paint()..color = region.baseColor.withAlpha(44),
        );
      } else {
        _surface(canvas, region, shaders[region.ground.index]);
        canvas.save();
        canvas.clipPath(region.path, doAntiAlias: false);
        _districtGrain(
          canvas,
          region,
          index,
          sector,
          shaders[region.accent.index],
        );
        canvas.restore();
      }
    }
    if (shaders != null) {
      for (final biome in _biomes) {
        if (biome.region.bounds.inflate(460).overlaps(sector)) {
          _surface(
            canvas,
            biome.region,
            shaders[biome.region.ground.index],
            featherOutside: true,
            tint: biome.tint,
            alpha: biome.alpha,
          );
        }
      }
      _smallGround(canvas, sector, shaders);
      _shoulders(canvas, sector, shaders);
    }
    _palette(canvas, sector, macroColors, overview: false);
    canvas.restore();
  }

  /// The expanded map uses the exact same district paths and palette positions.
  /// Its caller remains responsible for real water, roads, bridges and markers.
  void paintOverview(
    ui.Canvas canvas,
    ui.Rect view, {
    List<ui.Color>? macroColors,
  }) {
    canvas.save();
    canvas.clipRect(view, doAntiAlias: false);
    canvas.clipPath(_groundClip, doAntiAlias: false);
    canvas.drawRect(view, ui.Paint()..color = _color(_base(world.stage)));
    for (final region in regions) {
      if (region.bounds.overlaps(view)) {
        _surface(canvas, region, null);
      }
    }
    for (final biome in _biomes) {
      if (biome.region.bounds.inflate(460).overlaps(view)) {
        _surface(
          canvas,
          biome.region,
          null,
          featherOutside: true,
          tint: biome.tint,
          alpha: biome.alpha,
        );
      }
    }
    _palette(canvas, view, macroColors, overview: true);
    canvas.restore();
  }

  void _surface(
    ui.Canvas canvas,
    FieldRegionPlan region,
    ui.Shader? shader, {
    bool featherOutside = false,
    ui.Color? tint,
    int alpha = 221,
  }) {
    final positions = <ui.Offset>[region.center],
        colors = <ui.Color>[const ui.Color(0xffffffff)],
        indices = <int>[];
    for (final point in region.outline) {
      final d = region.center - point;
      positions.add(
        featherOutside
            ? point
            : point +
                  d *
                      (math.min(460, d.distance * .24) /
                          math.max(1, d.distance)),
      );

      colors.add(const ui.Color(0xffffffff));
    }
    positions.addAll(
      featherOutside
          ? region.outline.map((point) {
              final d = point - region.center;
              return point + d * (460 / math.max(1, d.distance));
            })
          : region.outline,
    );
    colors.addAll(
      List.filled(region.outline.length, const ui.Color(0x00ffffff)),
    );
    final count = region.outline.length;
    for (var i = 0; i < count; i++) {
      final a = 1 + i,
          b = 1 + (i + 1) % count,
          outerA = a + count,
          outerB = b + count;
      indices.addAll([0, a, b, a, outerA, b, outerA, outerB, b]);
    }
    final mesh = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: positions,
      colors: colors,
      indices: indices,
    );
    canvas.drawVertices(
      mesh,
      ui.BlendMode.modulate,
      ui.Paint()
        ..shader = shader
        ..color = shader == null
            ? region.baseColor.withAlpha(alpha)
            : ui.Color.fromARGB(alpha, 255, 255, 255)
        ..colorFilter = tint == null
            ? null
            : ui.ColorFilter.mode(tint, ui.BlendMode.modulate),
    );
    mesh.dispose();
  }

  void _ribbon(
    ui.Canvas canvas,
    List<ui.Offset> points,
    double width,
    ui.Shader shader, {
    int alpha = 120,
  }) {
    if (points.length < 2) return;
    final positions = <ui.Offset>[], colors = <ui.Color>[], indices = <int>[];
    const offsets = [-1.0, -.45, 0.0, .45, 1.0],
        weights = [0.0, .6, 1.0, .6, 0.0];
    for (var i = 0; i < points.length; i++) {
      final direction =
          points[math.min(i + 1, points.length - 1)] -
          points[math.max(0, i - 1)];
      final normal =
          ui.Offset(-direction.dy, direction.dx) /
          math.max(1, direction.distance);
      for (var side = 0; side < 5; side++) {
        positions.add(points[i] + normal * (offsets[side] * width / 2));
        colors.add(
          ui.Color.fromARGB((alpha * weights[side]).round(), 255, 255, 255),
        );
      }
      if (i == 0) continue;
      for (var side = 0; side < 4; side++) {
        final a = (i - 1) * 5 + side, b = i * 5 + side;
        indices.addAll([a, b, a + 1, a + 1, b, b + 1]);
      }
    }
    final mesh = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: positions,
      colors: colors,
      indices: indices,
    );
    canvas.drawVertices(
      mesh,
      ui.BlendMode.modulate,
      ui.Paint()
        ..shader = shader
        ..color = const ui.Color(0xffffffff),
    );
    mesh.dispose();
  }

  double _noise(int x, int y, int salt) =>
      (((x * 73856093) ^ (y * 19349663) ^ (world.seed + salt * 83492791)) &
          0x7fffffff) /
      0x7fffffff;

  void _districtGrain(
    ui.Canvas canvas,
    FieldRegionPlan region,
    int index,
    ui.Rect sector,
    ui.Shader shader,
  ) {
    final seed = world.stage.index * 31 + index * 7;
    final direction = switch (region.grain) {
      FieldGrain.braided => .35,
      FieldGrain.windward => -.6,
      FieldGrain.weathered => 1.15,
      FieldGrain.strata => -.2,
      FieldGrain.scattered => .85,
      FieldGrain.tracked => 1.55,
    };
    for (var strand = 0; strand < 5; strand++) {
      final offset = ui.Offset(
        (_noise(index, strand, seed) - .5) * region.bounds.width * .65,
        (_noise(strand, index, seed + 1) - .5) * region.bounds.height * .65,
      );
      final center = region.center + offset;
      final length = 1600 + _noise(index, strand, seed + 2) * 2800;
      final width = 140 + _noise(strand, index, seed + 3) * 460;
      final axis = ui.Offset(
        math.cos(direction + strand * .16),
        math.sin(direction + strand * .16),
      );
      final side = ui.Offset(-axis.dy, axis.dx);
      final points = [
        for (var i = 0; i <= 14; i++)
          center +
              axis * ((i / 14 - .5) * length) +
              side * (math.sin(i * .4 + seed) * width * .6),
      ];
      if (!ui.Rect.fromCenter(
        center: center,
        width: length + width * 3,
        height: length + width * 3,
      ).overlaps(sector)) {
        continue;
      }
      _ribbon(canvas, points, width, shader, alpha: 100);
    }
  }

  void _smallGround(ui.Canvas canvas, ui.Rect sector, List<ui.Shader> shaders) {
    const cell = 320.0;
    for (
      var row = (sector.top / cell).floor() - 1;
      row <= (sector.bottom / cell).floor() + 1;
      row++
    ) {
      for (
        var col = (sector.left / cell).floor() - 1;
        col <= (sector.right / cell).floor() + 1;
        col++
      ) {
        final at = ui.Offset(
          (col + _noise(col, row, 11)) * cell,
          (row + _noise(row, col, 13)) * cell,
        );
        if (!sector.inflate(170).contains(at)) continue;
        final region = regions.firstWhere(
          (region) => region.path.contains(at),
          orElse: () => regions.first,
        );
        final angle = _noise(col, row, 17) * math.pi * 2,
            axis = ui.Offset(math.cos(angle), math.sin(angle));
        final side = ui.Offset(-axis.dy, axis.dx),
            length = 60 + _noise(row, col, 19) * 150,
            width = 35 + _noise(col, row, 23) * 85;
        final points = [
          for (var i = 0; i < 5; i++)
            at +
                axis * ((i / 4 - .5) * length) +
                side * (math.sin(i * 1.7 + row) * width * .3),
        ];
        final accent = world.isSand(at) ? FieldGround.stone : region.accent;
        _ribbon(canvas, points, width, shaders[accent.index], alpha: 44);
      }
    }
  }

  void _shoulders(ui.Canvas canvas, ui.Rect sector, List<ui.Shader> shaders) {
    canvas.save();
    clipHardTrailGround(canvas);
    final material = world.stage.usesCityArt
        ? FieldGround.stone
        : FieldGround.desert;
    for (final road in world.trails) {
      if (!road.bounds.inflate(road.width / 2 + 150).overlaps(sector)) continue;
      _ribbon(
        canvas,
        road.points,
        road.width + 220,
        shaders[material.index],
        alpha: 148,
      );
    }
    canvas.restore();
  }

  /// Wind covers visible sandy terrain in every chapter. Forest and stone
  /// ground retain their ordinary paving outside the cached sand-material clip.
  void paintSandTrails(ui.Canvas canvas, ui.Rect sector, ui.Shader sand) {
    if (!_sandClip.getBounds().overlaps(sector)) return;
    canvas.save();
    canvas.clipRect(sector, doAntiAlias: false);
    canvas.clipPath(_sandClip, doAntiAlias: false);
    for (final road in world.trails) {
      if (!road.bounds.inflate(road.width / 2 + 150).overlaps(sector)) continue;
      _ribbon(canvas, road.points, road.width + 180, sand, alpha: 24);
      _ribbon(canvas, road.points, road.width * .9, sand, alpha: 38);
    }
    canvas.restore();
  }

  void _palette(
    ui.Canvas canvas,
    ui.Rect view,
    List<ui.Color>? colors, {
    required bool overview,
  }) {
    if (colors == null || colors.length != paletteColumns * paletteRows) return;
    final positions = <ui.Offset>[],
        vertexColors = <ui.Color>[],
        indices = <int>[];
    final stepX = worldSize.width / (paletteColumns - 1),
        stepY = worldSize.height / (paletteRows - 1);
    for (var row = 0; row < paletteRows; row++) {
      for (var col = 0; col < paletteColumns; col++) {
        positions.add(ui.Offset(col * stepX, row * stepY));
        vertexColors.add(
          colors[row * paletteColumns + col].withAlpha(overview ? 112 : 90),
        );
      }
    }
    for (
      var row = math.max(0, (view.top / stepY).floor());
      row < math.min(paletteRows - 1, (view.bottom / stepY).ceil() + 1);
      row++
    ) {
      for (
        var col = math.max(0, (view.left / stepX).floor());
        col < math.min(paletteColumns - 1, (view.right / stepX).ceil() + 1);
        col++
      ) {
        final a = row * paletteColumns + col,
            b = a + 1,
            c = a + paletteColumns,
            d = c + 1;
        indices.addAll([a, c, b, b, c, d]);
      }
    }
    if (indices.isEmpty) return;
    final mesh = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      colors: vertexColors,
      indices: indices,
    );
    canvas.drawVertices(
      mesh,
      ui.BlendMode.modulate,
      ui.Paint()
        ..color = const ui.Color(0xffffffff)
        ..blendMode = (overview
            ? ui.BlendMode.srcOver
            : ui.BlendMode.softLight),
    );
    mesh.dispose();
  }

  static List<_District> _districts(WorldStage stage) {
    const m = FieldGround.meadow,
        d = FieldGround.desert,
        s = FieldGround.stone,
        i = FieldGround.industrial;
    const b = FieldGrain.braided,
        w = FieldGrain.windward,
        e = FieldGrain.weathered,
        t = FieldGrain.strata,
        c = FieldGrain.scattered,
        r = FieldGrain.tracked;
    return switch (stage) {
      WorldStage.forest => [
        _district('western-canopy', .08, .20, m, d, b),
        _district('river-meadow', .23, .35, m, s, c),
        _district('northern-highlands', .50, .14, s, m, e),
        _district('eastern-grassland', .84, .20, m, d, w),
        _district('lake-basin', .58, .43, m, d, b),
        _district('southern-ridge', .30, .68, s, m, t),
        _district('ancient-gardens', .66, .74, m, s, e),
        _district('dry-bluff', .90, .63, d, s, w),
        _district('far-grove', .12, .90, m, d, c),
      ],
      WorldStage.sands => [
        _district('salt-wastes', .12, .12, d, s, t),
        _district('oasis-fringe', .34, .21, d, m, b),
        _district('broken-sun', .70, .10, s, d, e),
        _district('red-dunes', .90, .38, d, s, w),
        _district('glass-basin', .55, .50, d, s, t),
        _district('caravan-drift', .14, .58, d, m, r),
        _district('shale-country', .30, .86, s, d, e),
        _district('twilight-sands', .70, .82, d, s, w),
        _district('obsidian-threshold', .93, .91, s, d, t),
      ],
      WorldStage.past => [
        _district('kingdom-verge', .12, .22, m, s, b),
        _district('old-causeway', .40, .13, s, d, r),
        _district('sun-terraces', .78, .17, s, m, t),
        _district('fallen-forum', .33, .45, s, d, e),
        _district('sacred-grove', .65, .50, m, s, c),
        _district('chalk-ridge', .08, .77, d, s, w),
        _district('royal-road', .50, .82, s, m, r),
        _district('first-gate', .90, .82, s, d, e),
      ],
      WorldStage.future => [
        _district('abandoned-apron', .08, .18, i, s, e),
        _district('cable-ward', .45, .12, i, s, r),
        _district('upper-grid', .82, .26, s, i, t),
        _district('transit-exchange', .25, .47, i, s, r),
        _district('concrete-basin', .60, .52, s, i, c),
        _district('drainage-deck', .90, .60, i, s, w),
        _district('lower-depot', .20, .86, i, s, e),
        _district('core-approach', .68, .90, i, s, r),
      ],
      WorldStage.tombs => [
        _district('basalt-crown', .10, .10, s, d, t),
        _district('ash-country', .45, .13, d, s, w),
        _district('cracked-steps', .85, .12, s, d, e),
        _district('western-graves', .18, .40, s, d, c),
        _district('buried-corridor', .54, .40, d, s, r),
        _district('eastern-slate', .90, .50, s, d, t),
        _district('dust-fan', .10, .78, d, s, w),
        _district('fossil-beds', .40, .75, s, d, c),
        _district('lower-crypt', .70, .83, s, d, e),
        _district('last-threshold', .94, .93, s, d, r),
      ],
      WorldStage.foundry => [
        _district('rust-yard', .16, .10, i, d, e),
        _district('coolant-walk', .50, .18, i, s, r),
        _district('ore-loading', .84, .10, s, i, t),
        _district('slag-apron', .08, .50, d, i, w),
        _district('old-work-floor', .40, .44, i, s, c),
        _district('rolling-mill', .76, .48, i, d, r),
        _district('powder-south', .20, .86, d, s, w),
        _district('conveyor-wake', .55, .80, i, s, r),
        _district('dock-foundation', .94, .86, s, i, e),
      ],
      WorldStage.convergence => [
        _district('memory-flowers', .14, .17, m, s, b),
        _district('old-pavement', .48, .10, s, m, e),
        _district('copper-causeway', .86, .19, i, m, r),
        _district('fracture-garden', .33, .45, s, m, t),
        _district('moss-channels', .68, .50, m, s, b),
        _district('far-shore', .91, .66, s, m, w),
        _district('ancient-ridge', .11, .77, m, s, c),
        _district('anchor-court', .52, .85, s, i, e),
        _district('threshold-plain', .87, .93, m, i, b),
      ],
    };
  }
}

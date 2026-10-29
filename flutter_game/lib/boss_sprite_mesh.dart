import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

enum BossMeshProfile { golem, sandWarden, ancientKing, cyberCore }

/// Continuous simulation pose. [stride] is a normalized cycle (one turn = 1),
/// not radians. A zero-weight idle never advances by wall time.
class BossVisualPose {
  const BossVisualPose({
    this.profile = BossMeshProfile.golem,
    this.stride = 0,
    this.weight = 0,
    this.windup = 0,
    this.strike = 0,
    this.skill = 0,
    this.recoil = 0,
    this.walking = false,
  });

  final BossMeshProfile profile;
  final bool walking;
  final double stride, weight, windup, strike, skill, recoil;
}

/// Deforms one sprite, rather than blending two bodies or moving the whole cutout.
/// Bounded image/UV caches are configured by GameArt, which owns the images.
class BossSpriteMeshPainter {
  BossSpriteMeshPainter({this.imageLimit = 4, this.uvLimit = 32})
    : assert(imageLimit > 0),
      assert(uvLimit > 0);
  final int imageLimit, uvLimit;
  static const _columns = 9, _rows = 11;
  static const _verticesCount = _columns * _rows;
  static final _indices = _makeIndices();
  static final _walkSides = List<double>.generate(
    _columns,
    (column) => ((column / (_columns - 1) - .5) * 6).clamp(-1.0, 1.0),
    growable: false,
  );
  static final _identity = Float64List.fromList([
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
  ]);
  final _shaders = LinkedHashMap<ui.Image, ui.ImageShader>.identity();
  final _positions = Float32List(_verticesCount * 2);
  final _uvs = <(ui.Image, ui.Rect, double), Float32List>{};
  bool _disposed = false;

  int get cachedImageCount => _shaders.length;
  int get cachedUvCount => _uvs.length;

  static Uint16List _makeIndices() {
    final result = Uint16List((_columns - 1) * (_rows - 1) * 6);
    var at = 0;
    for (var y = 0; y < _rows - 1; y++) {
      for (var x = 0; x < _columns - 1; x++) {
        final a = y * _columns + x, b = a + 1, c = a + _columns;
        result[at++] = a;
        result[at++] = b;
        result[at++] = c;
        result[at++] = b;
        result[at++] = c + 1;
        result[at++] = c;
      }
    }
    return result;
  }

  static double _unit(double value) =>
      value.isFinite ? value.clamp(0.0, 1.0) : 0;

  ui.ImageShader _shader(ui.Image image) {
    final old = _shaders.remove(image);
    if (old != null) {
      _shaders[image] = old;
      return old;
    }
    if (_shaders.length == imageLimit) {
      final evicted = _shaders.keys.first;
      _shaders.remove(evicted)!.dispose();
      _uvs.removeWhere((key, _) => identical(key.$1, evicted));
    }
    final shader = ui.ImageShader(
      image,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      _identity,
    );
    _shaders[image] = shader;
    return shader;
  }

  Float32List _textureCoordinates(
    ui.Image image,
    ui.Rect source,
    double ground,
  ) {
    final key = (image, source, ground),
        old = _uvs.remove((image, source, ground));
    if (old != null) {
      _uvs[key] = old;
      return old;
    }
    if (_uvs.length == uvLimit) _uvs.remove(_uvs.keys.first);
    final result = Float32List(_verticesCount * 2);
    for (var row = 0; row < _rows; row++) {
      final y = row <= _rows - 2 ? row / (_rows - 2) * ground : 1.0;
      for (var column = 0; column < _columns; column++) {
        final x = column / (_columns - 1);
        final at = (row * _columns + column) * 2;
        // Half-pixel inset keeps filtering inside this atlas cell, even when
        // adjacent cells are opaque and a limb stretches beyond its old edge.
        result[at] = source.left + .5 + x * (source.width - 1);
        result[at + 1] = source.top + .5 + y * (source.height - 1);
      }
    }
    _uvs[key] = result;
    return result;
  }

  void paint(
    ui.Canvas canvas,
    ui.Image image,
    ui.Rect source,
    ui.Rect destination,
    ui.Paint paint,
    BossVisualPose pose, {
    ui.Offset? groundOrigin,
  }) {
    if (_disposed ||
        source.isEmpty ||
        destination.isEmpty ||
        !source.isFinite ||
        !destination.isFinite ||
        source.width < 1 ||
        source.height < 1 ||
        source.left < 0 ||
        source.top < 0 ||
        source.right > image.width ||
        source.bottom > image.height) {
      return;
    }
    final phase = pose.stride.isFinite ? pose.stride % 1 : 0.0,
        weight = _unit(pose.weight),
        windup = _unit(pose.windup),
        strike = _unit(pose.strike),
        skill = _unit(pose.skill),
        recoil = _unit(pose.recoil),
        wave = math.sin(phase * math.pi * 2),
        walkCycle = wave * weight,
        ground = groundOrigin != null && groundOrigin.dy.isFinite
            ? ((groundOrigin.dy - destination.top) / destination.height).clamp(
                .25,
                1.0,
              )
            : 1.0;
    for (var row = 0; row < _rows; row++) {
      // Boss poses pin the ground row. Walking alternates a planted foot with
      // a lifted foot; transparent padding below that row stays fixed.
      final y = row <= _rows - 2 ? row / (_rows - 2) * ground : 1.0;
      final lift = y < ground ? math.sin(y / ground * math.pi) : 0.0;
      final armHeight = 1 - ((y - .43).abs() / .38).clamp(0.0, 1.0);
      final leg = ((y - .55) / .3).clamp(0.0, 1.0) * lift;
      final foot = pose.walking ? ((y / ground - .5) * 2).clamp(0.0, 1.0) : 0.0;
      final pinned = (!pose.walking && y >= ground) || y > ground + .0001;
      for (var column = 0; column < _columns; column++) {
        final x = column / (_columns - 1), side = (x - .5) * 2;
        final arm = ((side.abs() - .22) / .55).clamp(0.0, 1.0) * armHeight;
        final torso = (1 - side.abs()) * lift;
        double dx, dy;
        if (pose.walking) {
          // A signed leg cycle gives each side a planted half-cycle. Using the
          // torso's sine envelope here would freeze both toes at ground level.
          final gait = walkCycle * _walkSides[column];
          dx = gait * (.065 * foot - .045 * arm);
          dy = -(gait > 0 ? gait : 0.0) * .055 * foot - gait * .018 * arm;
          dx += walkCycle * torso * .006;
        } else if (pose.profile == BossMeshProfile.cyberCore) {
          final panel = side.abs() * lift;
          dx = side * panel * (wave * weight * .018 + skill * .055);
          dx += side * arm * (strike * .055 - windup * .025);
          dy = panel * wave * weight * side * .018;
          dy += torso * (windup * .025 - strike * .025 + recoil * .025);
        } else {
          final mass = switch (pose.profile) {
            BossMeshProfile.golem => .7,
            BossMeshProfile.sandWarden => 1.0,
            _ => .85,
          };
          dx = wave * weight * mass * (.018 * side * leg - .008 * torso);
          dx += arm * side * (-windup * .035 + strike * .07 + skill * .035);
          dx -= recoil * torso * .025;
          dy = wave * weight * side * (.018 * leg - .012 * arm) * mass;
          dy += arm * (-windup * .04 + strike * .025 - skill * .035);
          dy += torso * (windup * .012 + recoil * .03);
        }
        if (pinned) {
          dx = dy = 0;
        }
        final index = (row * _columns + column) * 2;
        _positions[index] = destination.left + (x + dx) * destination.width;
        _positions[index + 1] = destination.top + (y + dy) * destination.height;
      }
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      _positions,
      textureCoordinates: _textureCoordinates(image, source, ground),
      indices: _indices,
    );
    final previousShader = paint.shader;
    try {
      paint.shader = _shader(image);
      canvas.drawVertices(vertices, ui.BlendMode.modulate, paint);
    } finally {
      paint.shader = previousShader;
      vertices.dispose();
    }
  }

  /// Call before the owning images are evicted or disposed.
  void trim(Iterable<ui.Image> retainedImages) {
    final retained = HashSet<ui.Image>.identity()..addAll(retainedImages);
    for (final image in _shaders.keys.toList(growable: false)) {
      if (!retained.contains(image)) _shaders.remove(image)!.dispose();
    }
    _uvs.removeWhere((key, _) => !retained.contains(key.$1));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final shader in _shaders.values) {
      shader.dispose();
    }
    _shaders.clear();
    _uvs.clear();
  }
}

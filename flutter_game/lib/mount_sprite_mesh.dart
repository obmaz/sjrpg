import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Distance-driven movement for the ridden vehicle, paused with the simulation.
class MountMotion {
  double cycle = 0, weight = 0;
  void advance(double distance, double dt, {bool waterOnly = false}) {
    if (dt <= 0 || !dt.isFinite) return;
    final travelled = distance.isFinite && distance > 0 ? distance : 0.0;
    cycle = (cycle + travelled / 125 + (waterOnly ? dt * .36 : 0)) % 1;
    final target = travelled > .000001
        ? 1.0
        : waterOnly
        ? .35
        : 0.0;
    weight += (target - weight) * (1 - math.exp(-14 * dt));
  }

  void reset() {
    cycle = 0;
    weight = 0;
  }

  MountVisualPose pose(String kind) =>
      MountVisualPose(kind: kind, stride: cycle, weight: weight);
}

class MountVisualPose {
  const MountVisualPose({required this.kind, this.stride = 0, this.weight = 0});
  final String kind;
  final double stride, weight;
}

/// Deforms one sprite, rather than blending two bodies or moving the whole cutout.
/// Owns at most four image shaders; their images remain owned by GameArt.
class MountSpriteMeshPainter {
  static const _columns = 9, _rows = 11;
  static const _verticesCount = _columns * _rows;
  static final _indices = _makeIndices();
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
    if (_shaders.length == 4) {
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
    if (_uvs.length == 32) _uvs.remove(_uvs.keys.first);
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
    MountVisualPose pose, {
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
    final phase = pose.stride.isFinite ? pose.stride % 1 : 0.0;
    final weight = _unit(pose.weight);
    final ground = groundOrigin != null && groundOrigin.dy.isFinite
        ? ((groundOrigin.dy - destination.top) / destination.height).clamp(
            .1,
            1.0,
          )
        : .94;
    final wave = phase * math.pi * 2;
    for (var row = 0; row < _rows; row++) {
      final y = row <= _rows - 2 ? row / (_rows - 2) * ground : 1.0;
      for (var column = 0; column < _columns; column++) {
        final x = column / (_columns - 1);
        final normalized = (y / ground).clamp(0.0, 1.0);
        final lift = math.sin(normalized * math.pi);
        double dx = 0, dy = 0;
        if (pose.kind == 'horse') {
          // Alternating fore/hind legs flex independently around the saddle.
          final leg =
              ((normalized - .5) / .4).clamp(0.0, 1.0) * (.45 + .55 * lift);
          final stride = math.sin(wave + x * math.pi * 3);
          dx = stride * .075 * leg * weight;
          dy = -math.max(0.0, stride) * .06 * leg * weight;
          dy += math.sin(wave * 2) * .005 * (1 - normalized) * weight;
        } else if (pose.kind == 'boat') {
          dx = math.sin(wave) * (x - .5) * .015 * lift * weight;
          dy = math.cos(wave) * (x - .5) * .025 * lift * weight;
        } else {
          // Suspension/fork compression and pedal cadence stay continuous;
          // neither wheel is cut off or swapped with a second static cutout.
          final axle = ((normalized - .55) / .4).clamp(0.0, 1.0) * lift;
          dx = math.sin(wave + x * math.pi * 2) * .012 * axle * weight;
          dy = math.sin(wave * 2) * .009 * (1 - normalized) * weight;
        }
        if (y > ground || y == ground && pose.kind != 'horse') dx = dy = 0;
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

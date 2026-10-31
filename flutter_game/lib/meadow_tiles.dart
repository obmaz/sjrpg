import 'dart:ui';

/// Four grounded surface variants; selection never consumes combat randomness.
enum MeadowTile { grass, weeds, flowers, stones }

abstract final class MeadowTiles {
  static const size = 144.0;
  static int hash(int seed, int column, int row) {
    var h = ((column * 73856093) ^ (row * 19349663) ^ seed) & 0x7fffffff;
    h = ((h ^ (h >> 13)) * 17881) & 0x7fffffff;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  static MeadowTile variant(int seed, int column, int row) =>
      MeadowTile.values[hash(seed, column, row) % MeadowTile.values.length];

  static const sourceSide = 256.0;
  static void paint(
    Canvas canvas,
    Offset origin,
    MeadowTile variant,
    Shader atlas,
  ) {
    const steps = [0.0, .18, .82, 1.0];
    final points = <Offset>[],
        uv = <Offset>[],
        colors = <Color>[],
        indices = <int>[];
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        points.add(origin + Offset(steps[x] * size, steps[y] * size));
        uv.add(
          Offset(
            variant.index * sourceSide + 1.5 + steps[x] * (sourceSide - 3),
            1.5 + steps[y] * (sourceSide - 3),
          ),
        );
        colors.add(
          x == 0 || x == 3 || y == 0 || y == 3
              ? const Color(0x00ffffff)
              : const Color(0xe6ffffff),
        );
      }
    }
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 3; x++) {
        final a = y * 4 + x;
        indices.addAll([a, a + 4, a + 1, a + 1, a + 4, a + 5]);
      }
    }
    final mesh = Vertices(
      VertexMode.triangles,
      points,
      textureCoordinates: uv,
      colors: colors,
      indices: indices,
    );
    canvas.drawVertices(mesh, BlendMode.modulate, Paint()..shader = atlas);
    mesh.dispose();
  }
}

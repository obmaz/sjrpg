import 'dart:math' as math;
import 'dart:ui';
import 'rpg_model.dart';
export 'rpg_model.dart';

const worldSize = Size(23040, 17280);
const town = Rect.fromLTWH(3520, 2624, 640, 960);
const arrival = Offset(3840, 3055);
const stageChests = [
  Offset(3840, 3415),
  Offset(3150, 3250),
  Offset(4000, 2240),
  Offset(4620, 4200),
  Offset(6200, 4200),
  Offset(3900, 4550),
  Offset(10000, 4200),
  Offset(13000, 6500),
  Offset(15500, 6800),
  Offset(18000, 4200),
  Offset(20000, 2300),
  Offset(22000, 9000),
  Offset(8000, 9000),
  Offset(13000, 12000),
  Offset(17000, 16000),
  Offset(22000, 14000),
  Offset(3800, 8500),
  Offset(3600, 16500),
];

Rect localMapBounds(Offset focus, {double span = 2100}) {
  final width = math.min(span, worldSize.width),
      height = math.min(span, worldSize.height);
  return Rect.fromLTWH(
    (focus.dx - width / 2).clamp(0.0, worldSize.width - width),
    (focus.dy - height / 2).clamp(0.0, worldSize.height - height),
    width,
    height,
  );
}

int facingFrame(double angle, int count) =>
    (((angle - math.pi / 2) * count / (math.pi * 2)).round() % count + count) %
    count;

class RegionShape {
  RegionShape(this.points) : bounds = _bounds(points) {
    path.addPolygon(points, true);
  }
  final List<Offset> points;
  final Rect bounds;
  final Path path = Path();
  static Rect _bounds(List<Offset> points) => Rect.fromLTRB(
    points.map((p) => p.dx).reduce(math.min),
    points.map((p) => p.dy).reduce(math.min),
    points.map((p) => p.dx).reduce(math.max),
    points.map((p) => p.dy).reduce(math.max),
  );
  bool contains(Offset p) => bounds.contains(p) && path.contains(p);
  bool overlaps(Rect rect) {
    if (!bounds.overlaps(rect)) return false;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];
    if (corners.any(contains) || points.any(rect.contains)) return true;
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length];
      for (var j = 0; j < 4; j++) {
        if (_crosses(a, b, corners[j], corners[(j + 1) % 4])) return true;
      }
    }
    return false;
  }

  static bool _crosses(Offset a, Offset b, Offset c, Offset d) {
    double side(Offset p, Offset q, Offset r) =>
        (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
    return side(a, b, c) * side(a, b, d) < 0 &&
        side(c, d, a) * side(c, d, b) < 0;
  }
}

class WorldProp {
  const WorldProp(this.body, this.kind, this.drawSize);
  final Rect body;
  final String kind;
  final Size drawSize;
}

class Trail {
  Trail(this.points, this.width) {
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
  }
  final List<Offset> points;
  final double width;
  final Path path = Path();
  double distance(Offset p) {
    var best = double.infinity;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], d = points[i] - a;
      final t =
          (((p.dx - a.dx) * d.dx + (p.dy - a.dy) * d.dy) /
                  (d.dx * d.dx + d.dy * d.dy))
              .clamp(0.0, 1.0);
      best = math.min(best, (p - a - d * t).distance);
    }
    return best;
  }
}

class AdventureWorld {
  AdventureWorld({this.seed = 7829}) {
    final random = math.Random(seed);
    RegionShape oval(Offset c, double rx, double ry) => RegionShape(
      List.generate(96, (i) {
        final a = i * math.pi * 2 / 96, r = 1 + .035 * math.sin(a * 5 + seed);
        return Offset(c.dx + math.cos(a) * rx * r, c.dy + math.sin(a) * ry * r);
      }),
    );
    woods = [
      oval(const Offset(1950, 2800), 1500, 1750),
      oval(const Offset(3900, 850), 1800, 1000),
      oval(const Offset(6650, 3500), 800, 1400),
      oval(const Offset(10800, 7000), 2200, 1800),
      oval(const Offset(18500, 12000), 2500, 2800),
      oval(const Offset(3000, 12000), 1600, 2800),
      oval(const Offset(14500, 2500), 3000, 1600),
    ];
    sandFields = [
      oval(const Offset(6600, 5200), 1500, 850),
      oval(const Offset(15500, 5000), 3400, 2300),
      oval(const Offset(21000, 14500), 1800, 1700),
    ];
    clearings = [
      oval(const Offset(10500, 7200), 1000, 750),
      oval(const Offset(18500, 12200), 1200, 1000),
      oval(const Offset(3300, 12000), 600, 1300),
    ];
    lakes = [
      oval(const Offset(5680, 1700), 820, 620),
      oval(const Offset(1750, 1100), 650, 430),
      oval(const Offset(17000, 9000), 1800, 1100),
      oval(const Offset(11500, 15500), 1400, 850),
    ];
    double rx(double y) => 5300 + math.sin(y / 620) * 230;
    final left = <Offset>[], right = <Offset>[];
    for (var y = -100.0; y < worldSize.height + 200; y += 64) {
      left.add(Offset(rx(y) - 148, y));
      right.add(Offset(rx(y) + 148, y));
    }
    river = RegionShape([...left, ...right.reversed]);
    bridge = Rect.fromCenter(
      center: Offset(rx(4200), 4200),
      width: 660,
      height: 176,
    );
    trails = [
      Trail(
        _curve([
          const Offset(3840, 3500),
          const Offset(4180, 3850),
          const Offset(4620, 4200),
          const Offset(4900, 4200),
          const Offset(5700, 4200),
          const Offset(6200, 4200),
          const Offset(7000, 4780),
        ]),
        176,
      ),
      Trail(
        _curve([
          const Offset(3570, 2992),
          const Offset(3410, 2992),
          const Offset(3100, 3270),
          const Offset(2500, 3850),
          const Offset(1500, 4050),
          const Offset(300, 4700),
        ]),
        152,
      ),
      Trail(
        _curve([
          const Offset(3840, 2670),
          const Offset(4000, 2230),
          const Offset(3700, 1700),
          const Offset(4250, 900),
          const Offset(4650, 300),
        ]),
        152,
      ),
      Trail(
        _curve([
          const Offset(4180, 3850),
          const Offset(3900, 4550),
          const Offset(3200, 4900),
          const Offset(3000, 5500),
        ]),
        140,
      ),
    ];
    trails.addAll([
      Trail(
        _curve([
          const Offset(13000, 6500),
          const Offset(15500, 6800),
          const Offset(16700, 5900),
          const Offset(15000, 4400),
          const Offset(13500, 5100),
          const Offset(13000, 6500),
        ]),
        160,
      ),
      Trail(
        _curve([
          const Offset(18000, 4200),
          const Offset(20000, 2300),
          const Offset(22200, 3200),
          const Offset(22000, 9000),
        ]),
        145,
      ),
      Trail(
        _curve([
          const Offset(7000, 4780),
          const Offset(10000, 4200),
          const Offset(13000, 6500),
          const Offset(18000, 4200),
          const Offset(22000, 9000),
        ]),
        210,
      ),
      Trail(
        _curve([
          const Offset(6200, 4200),
          const Offset(8000, 9000),
          const Offset(13000, 12000),
          const Offset(17000, 16000),
          const Offset(22000, 14000),
        ]),
        185,
      ),
      Trail(
        _curve([
          const Offset(3000, 5500),
          const Offset(3800, 8500),
          const Offset(2200, 12000),
          const Offset(3600, 16500),
        ]),
        190,
      ),
    ]);
    for (var y = 0; y < 30; y++) {
      for (var x = 0; x < 20; x++) {
        final u = (x + .5) / 20, v = (y + .5) / 30;
        final solid =
            ((u - .5) / .19) * ((u - .5) / .19) +
                    ((v - .245) / .115) * ((v - .245) / .115) <
                1 ||
            (u > .74 && v > .15 && v < .36) ||
            (u < .25 && v > .4 && v < .67) ||
            (u > .77 && v > .64) ||
            (u < .19 && !(v > .32 && v < .43)) ||
            (u > .88 && v < .64) ||
            (v > .91 && u < .46) ||
            (v < .08 && (u < .39 || u > .61));
        if (solid) {
          _indexSolid(
            Rect.fromLTWH(town.left + x * 32, town.top + y * 32, 32, 32),
          );
        }
      }
    }
    for (var y = 100.0; y < worldSize.height - 100; y += 150) {
      for (var x = 100.0; x < worldSize.width - 100; x += 150) {
        final p = Offset(
          x + random.nextDouble() * 70,
          y + random.nextDouble() * 70,
        );
        if (town.inflate(150).contains(p) ||
            stageExits.any((e) => (Offset(e.x, e.y) - p).distance < 160) ||
            stageChests.any((c) => (c - p).distance < 100)) {
          continue;
        }
        final wooded = isWooded(p);
        final roll = random.nextDouble();
        if (roll > (wooded ? .68 : .04) ||
            trails.any((t) => t.distance(p) < t.width / 2 + 125) ||
            isWater(p)) {
          continue;
        }
        if (lakes.any((l) => l.bounds.inflate(70).contains(p)) ||
            river.bounds.contains(p) && isWater(p + const Offset(75, 0))) {
          continue;
        }
        final kind = isSand(p)
            ? (roll < .015 ? 'cactus' : 'rock')
            : wooded || roll < .015 && !clearings.any((c) => c.contains(p))
            ? 'tree'
            : 'rock';
        final body = Rect.fromCenter(
          center: p,
          width: kind == 'tree' ? 28 : 40,
          height: kind == 'tree' ? 28 : 36,
        );
        final prop = WorldProp(
          body,
          kind,
          kind == 'tree'
              ? Size(
                  155 + random.nextDouble() * 25,
                  205 + random.nextDouble() * 30,
                )
              : const Size(84, 76),
        );
        props.add(prop);
        _indexSolid(body);
        for (
          var by = (body.top - prop.drawSize.height) ~/ 256;
          by <= (body.bottom + 50) ~/ 256;
          by++
        ) {
          for (
            var bx = (body.left - prop.drawSize.width / 2) ~/ 256;
            bx <= (body.right + prop.drawSize.width / 2) ~/ 256;
            bx++
          ) {
            propBuckets.putIfAbsent('$bx:$by', () => []).add(prop);
          }
        }
      }
    }
  }
  final int seed;
  late final List<RegionShape> woods, lakes, sandFields, clearings;
  late final RegionShape river;
  RegionShape get sand => sandFields.first;
  bool isSand(Offset p) => sandFields.any((field) => field.contains(p));
  bool isWooded(Offset p) =>
      !isSand(p) &&
      !clearings.any((clearing) => clearing.contains(p)) &&
      woods.any((wood) => wood.contains(p));
  late final Rect bridge;
  late final List<Trail> trails;
  final List<WorldProp> props = [];
  final Map<String, List<WorldProp>> propBuckets = {};
  final Map<String, List<Rect>> _solids = {};
  void _indexSolid(Rect rect) {
    for (var y = rect.top ~/ 128; y <= rect.bottom ~/ 128; y++) {
      for (var x = rect.left ~/ 128; x <= rect.right ~/ 128; x++) {
        _solids.putIfAbsent('$x:$y', () => []).add(rect);
      }
    }
  }

  bool isWater(Offset p) =>
      (river.contains(p) || lakes.any((s) => s.contains(p))) &&
      !bridge.contains(p);
  bool blocked(Rect body) {
    if (body.left < 0 ||
        body.top < 0 ||
        body.right > worldSize.width ||
        body.bottom > worldSize.height) {
      return true;
    }
    for (var y = body.top ~/ 128; y <= body.bottom ~/ 128; y++) {
      for (var x = body.left ~/ 128; x <= body.right ~/ 128; x++) {
        if ((_solids['$x:$y'] ?? const <Rect>[]).any((s) => s.overlaps(body))) {
          return true;
        }
      }
    }
    if (lakes.any((l) => l.overlaps(body))) return true;
    if (!bridge.deflate(3).contains(body.topLeft) ||
        !bridge.deflate(3).contains(body.bottomRight)) {
      if (river.overlaps(body)) return true;
    }
    return false;
  }

  bool clearLine(Offset from, Offset to, Size size) {
    final sweep = Rect.fromLTRB(
      math.min(from.dx, to.dx),
      math.min(from.dy, to.dy),
      math.max(from.dx, to.dx) + size.width,
      math.max(from.dy, to.dy) + size.height,
    );
    if (sweep.left < 0 ||
        sweep.top < 0 ||
        sweep.right > worldSize.width ||
        sweep.bottom > worldSize.height) {
      return false;
    }
    if (from.dx == to.dx || from.dy == to.dy) return !blocked(sweep);
    final obstacles = <Rect>{};
    for (
      var y = (sweep.top / 128).floor();
      y <= (sweep.bottom / 128).floor();
      y++
    ) {
      for (
        var x = (sweep.left / 128).floor();
        x <= (sweep.right / 128).floor();
        x++
      ) {
        obstacles.addAll(_solids['$x:$y'] ?? const <Rect>[]);
      }
    }
    // Exact swept-body clearance at rectangular corners prevents a coarse sample
    // from alternately accepting and rejecting the same diagonal as an actor moves.
    for (final obstacle in obstacles) {
      final expanded = Rect.fromLTRB(
        obstacle.left - size.width,
        obstacle.top - size.height,
        obstacle.right,
        obstacle.bottom,
      );
      if (_segmentHitsRect(from, to, expanded)) return false;
    }
    if (lakes.any((l) => l.bounds.overlaps(sweep)) ||
        river.bounds.overlaps(sweep)) {
      final n = math.max(1, ((to - from).distance / 6).ceil());
      for (var i = 0; i <= n; i++) {
        final at = Offset.lerp(from, to, i / n)!;
        final body = Rect.fromLTWH(at.dx, at.dy, size.width, size.height);
        if (lakes.any((l) => l.overlaps(body))) return false;
        if (!(bridge.deflate(3).contains(body.topLeft) &&
                bridge.deflate(3).contains(body.bottomRight)) &&
            river.overlaps(body)) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _segmentHitsRect(Offset from, Offset to, Rect rect) {
    var enter = 0.0, exit = 1.0;
    for (final axis in [
      (from.dx, to.dx - from.dx, rect.left, rect.right),
      (from.dy, to.dy - from.dy, rect.top, rect.bottom),
    ]) {
      if (axis.$2.abs() < 1e-12) {
        if (axis.$1 <= axis.$3 || axis.$1 >= axis.$4) return false;
      } else {
        final a = (axis.$3 - axis.$1) / axis.$2,
            b = (axis.$4 - axis.$1) / axis.$2;
        enter = math.max(enter, math.min(a, b));
        exit = math.min(exit, math.max(a, b));
        if (enter >= exit) return false;
      }
    }
    return exit > 0 && enter < 1 && enter < exit;
  }

  Offset move(Offset from, Offset delta, Size size) {
    var p = from;
    final n = math.max(
      1,
      (math.max(delta.dx.abs(), delta.dy.abs()) / 6).ceil(),
    );
    final step = delta / n.toDouble();
    for (var i = 0; i < n; i++) {
      if (!blocked(
        Rect.fromLTWH(p.dx + step.dx, p.dy + step.dy, size.width, size.height),
      )) {
        p += step;
        continue;
      }
      if (!blocked(
        Rect.fromLTWH(p.dx + step.dx, p.dy, size.width, size.height),
      )) {
        p += Offset(step.dx, 0);
      }
      if (!blocked(
        Rect.fromLTWH(p.dx, p.dy + step.dy, size.width, size.height),
      )) {
        p += Offset(0, step.dy);
      }
    }
    return p;
  }

  Offset? spawnNear(Offset desired, Size body) {
    if (!blocked(
      Rect.fromLTWH(desired.dx, desired.dy, body.width, body.height),
    )) {
      return desired;
    }
    for (var radius = 24.0; radius < 200; radius += 24) {
      for (var i = 0; i < 12; i++) {
        final p =
            desired +
            Offset(
              math.cos(i * math.pi / 6) * radius,
              math.sin(i * math.pi / 6) * radius,
            );
        if (!blocked(Rect.fromLTWH(p.dx, p.dy, body.width, body.height))) {
          return p;
        }
      }
    }
    return null;
  }

  String areaName(Offset p) {
    if (town.contains(p)) return '분수 마을';
    if (isSand(p)) return p.dx > 12000 ? '태양의 사구' : '황금 모래벌판';
    if (lakes.any((l) => l.bounds.inflate(220).contains(p))) return '푸른 호숫가';
    if ((p.dx - 5300).abs() < 550) return '달빛 강변';
    if (clearings.any((c) => c.contains(p))) return '바람꽃 초원';
    if (isWooded(p)) return '이끼 숲';
    return '햇살 초원';
  }

  List<Offset> route(Offset from, Offset to, Size size) {
    const grid = 32.0;
    final sx = (from.dx / grid).floor(), sy = (from.dy / grid).floor();
    Offset position(math.Point<int> p) => Offset(p.x * grid, p.y * grid);
    final anchors = <math.Point<int>>[];
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final point = math.Point(sx + dx, sy + dy);
        if (clearLine(from, position(point), size)) anchors.add(point);
      }
    }
    if (anchors.isEmpty) return [];
    anchors.sort(
      (a, b) => (position(a) - from).distance.compareTo(
        (position(b) - from).distance,
      ),
    );
    final start = anchors.first;
    final front = <_Node>[
      _Node(start, 0, (to - position(start)).distance / grid),
    ];
    final costs = <math.Point<int>, double>{start: 0};
    final parents = <math.Point<int>, math.Point<int>>{};
    var visited = 0;
    while (front.isNotEmpty && visited++ < 700) {
      front.sort((a, b) => b.score.compareTo(a.score));
      final current = front.removeLast();
      final p = current.point, at = position(p);
      if ((at - to).distance < 42) {
        final path = <Offset>[];
        var c = p;
        while (parents.containsKey(c)) {
          path.add(position(c));
          c = parents[c]!;
        }
        return [position(start), ...path.reversed];
      }
      for (final d in const [
        math.Point(1, 0),
        math.Point(-1, 0),
        math.Point(0, 1),
        math.Point(0, -1),
      ]) {
        final next = math.Point(p.x + d.x, p.y + d.y), g = current.cost + 1;
        if (g >= (costs[next] ?? double.infinity)) continue;
        final dest = position(next);
        if (!clearLine(at, dest, size)) continue;
        costs[next] = g;
        parents[next] = p;
        front.add(_Node(next, g, g + (dest - to).distance / grid));
      }
    }
    return [];
  }

  static List<Offset> _curve(List<Offset> anchors) {
    final points = <Offset>[];
    for (var i = 0; i < anchors.length - 1; i++) {
      final a = anchors[math.max(0, i - 1)],
          b = anchors[i],
          c = anchors[i + 1],
          d = anchors[math.min(anchors.length - 1, i + 2)];
      final n = math.max(2, ((c - b).distance / 50).ceil());
      for (var j = 0; j < n; j++) {
        final t = j / n, t2 = t * t, t3 = t2 * t;
        points.add(
          (b * 2 +
                  (c - a) * t +
                  (a * 2 - b * 5 + c * 4 - d) * t2 +
                  (-a + b * 3 - c * 3 + d) * t3) *
              .5,
        );
      }
    }
    return [...points, anchors.last];
  }
}

class _Node {
  const _Node(this.point, this.cost, this.score);
  final math.Point<int> point;
  final double cost, score;
}

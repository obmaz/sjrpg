import 'dart:math' as math;
import 'dart:ui';

import 'stage_content.dart';

export 'rpg_model.dart';
export 'stage_content.dart';

const authoredWorldSize = Size(46080, 34560);
const worldSize = Size(46080 * worldScale, 34560 * worldScale);
const authoredTown = Rect.fromLTWH(3520, 2624, 640, 960);
const town = Rect.fromLTWH(
  3520 * worldScale,
  2624 * worldScale,
  640 * worldScale,
  960 * worldScale,
);
const arrival = Offset(3840 * worldScale, 3055 * worldScale);
const authoredStageChests = [
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
  Offset(26000, 6000),
  Offset(32000, 7500),
  Offset(38500, 4000),
  Offset(44500, 6500),
  Offset(36000, 13000),
  Offset(36500, 18000),
  Offset(35000, 22000),
  Offset(34000, 30000),
  Offset(42000, 33000),
  Offset(23000, 23000),
  Offset(11200, 24000),
  Offset(8200, 28000),
  Offset(3300, 32500),
];

class TravelMountDef {
  const TravelMountDef(
    this.id,
    this.name,
    this.speed, {
    this.waterOnly = false,
  });
  final String id, name;
  final double speed;
  final bool waterOnly;
  String get artKey => waterOnly ? 'boat' : id;
  Size get bodySize => waterOnly ? const Size(46, 34) : const Size(40, 32);
}

const travelMountDefs = [
  TravelMountDef('horse', '말', 520),
  TravelMountDef('bicycle', '자전거', 460),
  TravelMountDef('motor', '오토바이', 620),
  TravelMountDef('boat', '배', 340, waterOnly: true),
  TravelMountDef('boat-west', '배', 340, waterOnly: true),
  TravelMountDef('boat-ruins', '배', 340, waterOnly: true),
  TravelMountDef('boat-marsh', '배', 340, waterOnly: true),
  TravelMountDef('boat-east', '배', 340, waterOnly: true),
  TravelMountDef('boat-south', '배', 340, waterOnly: true),
  TravelMountDef('boat-coast', '배', 340, waterOnly: true),
];
const authoredInitialMountPositions = [
  Offset(4000, 3440),
  Offset(3600, 3500),
  Offset(4160, 3800),
  Offset(5015, 1700),
  Offset(1200, 1100),
  Offset(15400, 9000),
  Offset(10300, 15500),
  Offset(25800, 13800),
  Offset(12600, 27800),
  Offset(37400, 30300),
];

class TravelMount {
  TravelMount(this.def, this.at);
  final TravelMountDef def;
  Offset at;
  double bearing = 1.5707963267948966;
  double durability = 100;
  int get condition => durability.ceil().clamp(0, 100);
  int get repairCost => ((100 - durability) * .6).ceil();
  double get speed => durability <= 0
      ? (def.waterOnly ? 100 : 140)
      : def.speed * (durability <= 20 ? .75 : 1);
  void wear(double amount) {
    if (amount.isFinite && amount > 0) {
      durability = (durability - amount).clamp(0, 100);
    }
  }
}

const authoredQuestSites = [
  QuestSite(
    'roots',
    '뿌리 우물',
    '서부 초원과 숲이 만나는 오래된 우물',
    Offset(10000, 11000),
    Color(0xff94db9c),
  ),
  QuestSite(
    'moon',
    '달빛 샘',
    '북동쪽 숲길 끝의 푸른 샘',
    Offset(34500, 8500),
    Color(0xff9cdbf2),
    artIndex: 1,
  ),
  QuestSite(
    'sun',
    '태양 제단',
    '남동쪽 고목 숲의 황금 제단',
    Offset(31000, 28000),
    Color(0xffffd581),
    artIndex: 2,
  ),
];

final stageChests = List<Offset>.unmodifiable(
  authoredStageChests.map((p) => p * worldScale),
);
final initialMountPositions = List<Offset>.unmodifiable(
  authoredInitialMountPositions.map((p) => p * worldScale),
);
final questSites = List<QuestSite>.unmodifiable(
  authoredQuestSites.map((s) => s.scaled()),
);
List<QuestSite> authoredSitesForStage(WorldStage stage) => switch (stage) {
  WorldStage.forest => authoredQuestSites,
  WorldStage.sands => authoredTimeCommissions.map((q) => q.site).toList(),
  WorldStage.past => authoredAncientSites,
  WorldStage.future => authoredNeonSites,
};

List<QuestSite> sitesForStage(WorldStage stage) => switch (stage) {
  WorldStage.forest => questSites,
  WorldStage.sands => timeCommissions.map((q) => q.site).toList(),
  WorldStage.past => ancientSites,
  WorldStage.future => neonSites,
};

Rect localMapBounds(Offset focus, {double span = 2100}) =>
    Rect.fromCenter(center: focus, width: span, height: span);

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
  Iterable<Rect> get collisionBodies => kind == 'ruin-4'
      ? [
          Rect.fromLTWH(body.left, body.top, 26, body.height),
          Rect.fromLTWH(body.right - 26, body.top, 26, body.height),
        ]
      : [body];
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
  late final Rect bounds = RegionShape._bounds(points);
  bool near(Offset p, double margin) =>
      bounds.inflate(width / 2 + margin).contains(p) &&
      distance(p) < width / 2 + margin;
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
  AdventureWorld({this.seed = 7829, this.stage = WorldStage.forest}) {
    const worldSize = authoredWorldSize, town = authoredTown;
    const questSites = authoredQuestSites, stageChests = authoredStageChests;
    if (stage != WorldStage.forest) {
      _buildThemed();
      _compact();
      return;
    }
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
    woods.addAll([
      oval(const Offset(28200, 6200), 3400, 2300),
      oval(const Offset(36500, 12500), 3000, 2500),
      oval(const Offset(9600, 23800), 4200, 3200),
      oval(const Offset(31500, 27800), 4400, 3000),
      oval(const Offset(42500, 31000), 2100, 1700),
    ]);
    sandFields.addAll([
      oval(const Offset(39200, 5800), 4400, 3200),
      oval(const Offset(24500, 21800), 5100, 3800),
      oval(const Offset(42900, 21800), 2300, 4800),
    ]);
    clearings.addAll([
      oval(const Offset(28100, 6400), 1300, 1100),
      oval(const Offset(9700, 23900), 1600, 1000),
      oval(const Offset(33200, 29300), 2200, 1400),
    ]);
    lakes.addAll([
      oval(const Offset(29700, 13800), 4200, 2600),
      oval(const Offset(15500, 27800), 3100, 2000),
      oval(const Offset(38800, 30300), 1600, 1300),
    ]);
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
    bridges = [
      bridge,
      Rect.fromCenter(
        center: Offset(rx(18000), 18000),
        width: 660,
        height: 176,
      ),
      Rect.fromCenter(
        center: Offset(rx(29000), 29000),
        width: 660,
        height: 176,
      ),
    ];
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
          const Offset(3570, 2984),
          const Offset(3410, 2984),
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
    trails.addAll([
      Trail(
        _curve([
          const Offset(3100, 3270),
          const Offset(2700, 3800),
          const Offset(2700, 4500),
          const Offset(3000, 5500),
        ]),
        150,
      ),
      Trail(
        _curve([
          const Offset(22000, 9000),
          const Offset(26000, 6000),
          const Offset(32000, 7500),
          const Offset(38500, 4000),
          const Offset(45000, 6500),
        ]),
        195,
      ),
      Trail(
        _curve([
          const Offset(22000, 14000),
          const Offset(24500, 17500),
          const Offset(23000, 23000),
          const Offset(29000, 26000),
          const Offset(34000, 30000),
          const Offset(36000, 32500),
          const Offset(42000, 33000),
          const Offset(44500, 32500),
        ]),
        205,
      ),
      Trail(
        _curve([
          const Offset(3600, 16500),
          const Offset(4000, 17300),
          const Offset(4700, 18000),
        ]),
        185,
      ),
      Trail([const Offset(4700, 18000), const Offset(5700, 18000)], 160),
      Trail(
        _curve([
          const Offset(5700, 18000),
          const Offset(9300, 21200),
          const Offset(11200, 24000),
          const Offset(8200, 28000),
          const Offset(5700, 29000),
        ]),
        185,
      ),
      Trail([const Offset(5700, 29000), const Offset(4700, 29000)], 160),
      Trail(
        _curve([const Offset(4700, 29000), const Offset(3300, 32500)]),
        185,
      ),
      Trail(
        _curve([
          const Offset(11200, 24000),
          const Offset(18000, 21500),
          const Offset(23000, 23000),
        ]),
        180,
      ),
      Trail(
        _curve([
          const Offset(34000, 30000),
          const Offset(35000, 22000),
          const Offset(36500, 18000),
          const Offset(36000, 13000),
          const Offset(32000, 7500),
        ]),
        180,
      ),
    ]);
    trails.addAll([
      Trail(
        _curve([
          const Offset(8000, 9000),
          questSites[0].at + const Offset(0, 200),
        ]),
        190,
      ),
      Trail(
        _curve([
          const Offset(32000, 7500),
          questSites[1].at + const Offset(0, 200),
        ]),
        190,
      ),
      Trail(
        _curve([
          const Offset(29000, 26000),
          questSites[2].at + const Offset(0, 200),
        ]),
        190,
      ),
    ]);
    for (final site in questSites) {
      clearings.add(oval(site.at, 360, 300));
      _indexSolid(site.body);
    }
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
            questSites.any((q) => (q.at - p).distance < 180) ||
            stageChests.any((c) => (c - p).distance < 100)) {
          continue;
        }
        final wooded = isWooded(p);
        final roll = random.nextDouble();
        if (roll > (wooded ? .68 : .04) ||
            trails.any((t) => t.near(p, 125)) ||
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
    _compact();
  }
  // A visibility graph keeps roads clear of water, quest structures and the fountain.
  List<Offset> _dryRoad(List<Offset> authored, double width) {
    final obstacles = [
      ...lakes.map((l) => l.bounds.inflate(width / 2 + 32)),
      if (!_authoring)
        ...campProps.expand((p) => p.collisionBodies).map((r) => r.inflate(32)),
      ...sites.map((s) => s.body.inflate(width / 2 + 32)),
      Rect.fromCenter(
        center: healAt,
        width: 80,
        height: 90,
      ).inflate(width / 2 + 32),
    ];
    bool open(Offset a, Offset b) =>
        !obstacles.any((r) => _segmentHitsRect(a, b, r));
    final route = <Offset>[authored.first];
    for (final goal in authored.skip(1)) {
      final from = route.last;
      if (open(from, goal)) {
        route.add(goal);
        continue;
      }
      final nodes = [
        from,
        goal,
        for (final r in obstacles) ...[
          r.topLeft - const Offset(2, 2),
          r.topRight + const Offset(2, -2),
          r.bottomLeft + const Offset(-2, 2),
          r.bottomRight + const Offset(2, 2),
        ],
      ];
      final distance = List<double>.filled(nodes.length, double.infinity)
        ..[0] = 0;
      final parent = List<int>.filled(nodes.length, -1), visited = <int>{};
      while (!visited.contains(1)) {
        var current = -1;
        for (var i = 0; i < nodes.length; i++) {
          if (!visited.contains(i) &&
              distance[i].isFinite &&
              (current < 0 || distance[i] < distance[current])) {
            current = i;
          }
        }
        if (current < 0) {
          throw StateError(
            'Authored road endpoint lies inside an obstacle: $goal',
          );
        }
        visited.add(current);
        for (var i = 0; i < nodes.length; i++) {
          if (visited.contains(i) || !open(nodes[current], nodes[i])) continue;
          final cost = distance[current] + (nodes[current] - nodes[i]).distance;
          if (cost < distance[i]) {
            distance[i] = cost;
            parent[i] = current;
          }
        }
      }
      final section = <Offset>[];
      for (var i = 1; i != 0; i = parent[i]) {
        section.add(nodes[i]);
      }
      route.addAll(section.reversed);
    }
    if (stage == WorldStage.future) return route;
    final curved = _curve(route);
    return List.generate(
          curved.length - 1,
          (i) => i,
        ).every((i) => open(curved[i], curved[i + 1]))
        ? curved
        : route;
  }

  void _buildThemed() {
    const worldSize = authoredWorldSize;
    final random = math.Random(seed + stage.index * 7381);
    RegionShape oval(Offset c, double rx, double ry) => RegionShape(
      List.generate(64, (i) {
        final a = i * math.pi * 2 / 64,
            r = 1 + .06 * math.sin(a * 5 + stage.index);
        return Offset(c.dx + math.cos(a) * rx * r, c.dy + math.sin(a) * ry * r);
      }),
    );
    river = RegionShape([
      const Offset(-200, -200),
      const Offset(-100, -200),
      const Offset(-100, -100),
    ]);
    bridge = const Rect.fromLTWH(-200, -200, 10, 10);
    bridges = [];
    woods = stage == WorldStage.past
        ? [
            oval(const Offset(11000, 8000), 4500, 3500),
            oval(const Offset(32000, 24000), 5500, 4500),
            oval(const Offset(15000, 26000), 3500, 2000),
          ]
        : [];
    clearings = [oval(spawn, 650, 550)];
    sandFields = stage == WorldStage.sands
        ? [oval(const Offset(23000, 17000), 32000, 25000)]
        : [];
    lakes = switch (stage) {
      WorldStage.sands => [
        oval(const Offset(17000, 6500), 1800, 1200),
        oval(const Offset(28000, 22000), 3200, 2000),
        oval(const Offset(4000, 25000), 1800, 2800),
      ],
      WorldStage.past => [
        oval(const Offset(7000, 19000), 2200, 5200),
        oval(const Offset(35000, 11000), 4800, 2200),
        oval(const Offset(24000, 29000), 3000, 1800),
      ],
      _ => [
        oval(const Offset(24000, 8000), 1400, 5000),
        oval(const Offset(34000, 26000), 4500, 1600),
        oval(const Offset(6000, 29000), 1900, 1800),
      ],
    };
    final spines = switch (stage) {
      WorldStage.sands => <List<Offset>>[
        [
          const Offset(2000, 15000),
          const Offset(3200, 12000),
          spawn,
          const Offset(10600, 8200),
          const Offset(14500, 3600),
          const Offset(24000, 4300),
          const Offset(31000, 7000),
          const Offset(43000, 5000),
        ],
        [
          spawn,
          const Offset(11000, 16000),
          const Offset(18500, 19000),
          const Offset(21000, 26500),
          const Offset(34000, 31000),
          const Offset(44000, 24000),
        ],
        [
          const Offset(3000, 32000),
          const Offset(12000, 29000),
          const Offset(18500, 19000),
          const Offset(30000, 13000),
          const Offset(42000, 15000),
        ],
      ],
      WorldStage.past => <List<Offset>>[
        [
          const Offset(2000, 7000),
          const Offset(12000, 4000),
          const Offset(19000, 10000),
          spawn,
          const Offset(30000, 18000),
          const Offset(43000, 21000),
        ],
        [
          const Offset(4000, 30000),
          const Offset(12000, 32000),
          const Offset(19000, 25000),
          spawn,
          const Offset(28000, 6500),
          const Offset(40000, 4000),
        ],
        [
          const Offset(15000, 18000),
          spawn,
          const Offset(32000, 32000),
          const Offset(43000, 30000),
        ],
      ],
      _ => <List<Offset>>[
        [
          const Offset(3000, 24000),
          spawn,
          const Offset(20000, 24000),
          const Offset(20000, 15000),
          const Offset(31000, 15000),
          const Offset(41000, 12000),
        ],
        [
          const Offset(4500, 4000),
          const Offset(12000, 7500),
          const Offset(12000, 15000),
          spawn,
          const Offset(18000, 31000),
          const Offset(29000, 32000),
          const Offset(42000, 32000),
        ],
        [
          const Offset(32000, 4000),
          const Offset(37000, 9000),
          const Offset(31000, 15000),
          const Offset(27000, 20000),
          const Offset(43000, 21000),
        ],
      ],
    };
    _themedSpines = spines;
    trails = [
      for (final points in spines)
        Trail(
          _dryRoad(points, stage == WorldStage.future ? 260 : 220),
          stage == WorldStage.future ? 260 : 220,
        ),
    ];
    // Every quest gets an open approach below its visible solid structure.
    for (final site in sites) {
      final approach = site.at + const Offset(0, 200);
      trails.add(
        Trail([
          ..._dryRoad([spawn, approach], 190),
          site.at,
        ], 190),
      );
      clearings.add(oval(site.at, 360, 300));
      _indexSolid(site.body);
    }
    if (stage == WorldStage.future) {
      campProps.add(
        WorldProp(
          Rect.fromCenter(
            center: merchantAt + const Offset(0, -70),
            width: 90,
            height: 46,
          ),
          'city-4',
          const Size(172, 172),
        ),
      );
      campProps.add(
        WorldProp(
          Rect.fromCenter(center: healAt, width: 44, height: 30),
          'city-5',
          const Size(100, 100),
        ),
      );
    } else {
      campProps.add(
        WorldProp(
          Rect.fromCenter(
            center: merchantAt + const Offset(0, -36),
            width: 110,
            height: 48,
          ),
          stage == WorldStage.sands ? 'ruin-0' : 'ruin-2',
          const Size(200, 200),
        ),
      );
      campProps.add(
        WorldProp(
          Rect.fromCenter(
            center: healAt - const Offset(0, 18),
            width: 64,
            height: 36,
          ),
          stage == WorldStage.sands ? 'ruin-1' : 'ruin-3',
          const Size(120, 120),
        ),
      );
    }
    for (final prop in campProps) {
      _indexSolid(prop.body);
      for (
        var by = (prop.body.top - prop.drawSize.height) ~/ 256;
        by <= (prop.body.bottom + 50) ~/ 256;
        by++
      ) {
        for (
          var bx = (prop.body.left - prop.drawSize.width) ~/ 256;
          bx <= (prop.body.right + prop.drawSize.width) ~/ 256;
          bx++
        ) {
          propBuckets.putIfAbsent('$bx:$by', () => []).add(prop);
        }
      }
    }
    // Roadside silhouettes stay visible, while the entire road admits a mounted body.
    final spacing = stage == WorldStage.future
        ? 200.0
        : stage == WorldStage.past
        ? 230.0
        : 280.0;
    for (var y = 180.0; y < worldSize.height - 180; y += spacing) {
      for (var x = 180.0; x < worldSize.width - 180; x += spacing) {
        final p = Offset(
          x + random.nextDouble() * 100,
          y + random.nextDouble() * 100,
        );
        if (settlement.inflate(240).contains(p) ||
            sites.any((s) => (s.at - p).distance < 240) ||
            chests.any((c) => (c - p).distance < 130) ||
            trails.any((t) => t.near(p, 85)) ||
            isWater(p)) {
          continue;
        }
        if (random.nextDouble() >
            (isWooded(p)
                ? .55
                : stage == WorldStage.future
                ? .34
                : stage == WorldStage.past
                ? .22
                : .11)) {
          continue;
        }
        final oasis = lakes.any((lake) => lake.bounds.inflate(550).contains(p));
        final kind = stage == WorldStage.future
            ? 'city-${[0, 1, 2, 6][random.nextInt(4)]}'
            : isWooded(p)
            ? 'tree'
            : stage == WorldStage.sands
            ? (oasis && random.nextBool()
                  ? 'ruin-7'
                  : random.nextBool()
                  ? 'cactus'
                  : 'ruin-5')
            : 'ruin-${4 + random.nextInt(3)}';
        final body = Rect.fromCenter(
          center: p,
          width: kind == 'tree'
              ? 28
              : kind == 'ruin-4'
              ? 96
              : 74,
          height: kind == 'tree' ? 38 : 44,
        );
        final side = kind == 'ruin-4'
            ? 180.0
            : stage == WorldStage.future
            ? 144.0 + random.nextInt(29)
            : 128.0 + random.nextInt(25);
        final prop = WorldProp(
          body,
          kind,
          kind == 'tree' ? const Size(165, 220) : Size(side, side),
        );
        props.add(prop);
        for (final body in prop.collisionBodies) {
          _indexSolid(body);
        }
        for (
          var by = (body.top - prop.drawSize.height) ~/ 256;
          by <= (body.bottom + 50) ~/ 256;
          by++
        ) {
          for (
            var bx = (body.left - prop.drawSize.width) ~/ 256;
            bx <= (body.right + prop.drawSize.width) ~/ 256;
            bx++
          ) {
            propBuckets.putIfAbsent('$bx:$by', () => []).add(prop);
          }
        }
      }
    }
  }

  List<List<Offset>> _themedSpines = [];
  void _compact() {
    // Freeze lazy authored anchors before replacing the geometry.
    final _ = (_authoredMerchant, _authoredChests);
    Rect scaledRect(Rect r) => Rect.fromLTRB(
      r.left * worldScale,
      r.top * worldScale,
      r.right * worldScale,
      r.bottom * worldScale,
    );
    RegionShape shape(RegionShape s) =>
        RegionShape(s.points.map((p) => p * worldScale).toList());
    final propSolids = {
      for (final p in [...props, ...campProps]) ...p.collisionBodies,
    };
    final siteSolids = _authoredSites.map((s) => s.body).toSet();
    final staticSolids = _solids.values
        .expand((s) => s)
        .toSet()
        .where((r) => !propSolids.contains(r) && !siteSolids.contains(r))
        .toList();
    woods = woods.map(shape).toList();
    lakes = lakes.map(shape).toList();
    sandFields = sandFields.map(shape).toList();
    clearings = clearings.map(shape).toList();
    river = shape(river);
    bridge = scaledRect(bridge);
    bridges = bridges.map(scaledRect).toList();
    trails = trails
        .map(
          (t) => Trail(t.points.map((p) => p * worldScale).toList(), t.width),
        )
        .toList();
    for (final list in [props, campProps]) {
      final next = list
          .map(
            (p) => WorldProp(
              Rect.fromCenter(
                center: p.body.center * worldScale,
                width: p.body.width,
                height: p.body.height,
              ),
              p.kind,
              p.drawSize,
            ),
          )
          .toList();
      list
        ..clear()
        ..addAll(next);
    }
    _authoring = false;
    if (stage != WorldStage.forest) {
      final width = stage == WorldStage.future ? 260.0 : 220.0;
      trails = [
        for (final points in _themedSpines)
          Trail(
            _dryRoad(points.map((p) => p * worldScale).toList(), width),
            width,
          ),
        for (final site in sites)
          Trail([
            ..._dryRoad([spawn, site.at + const Offset(0, 150)], 190),
            site.at,
          ], 190),
      ];
    }
    props.removeWhere(
      (p) => trails.any(
        (t) => t.near(
          p.body.center,
          math.max(p.body.width, p.body.height) / 2 + 20,
        ),
      ),
    );
    _solids.clear();
    propBuckets.clear();
    for (final r in staticSolids) {
      _indexSolid(scaledRect(r));
    }
    for (final s in sites) {
      _indexSolid(s.body);
    }
    for (final p in [...props, ...campProps]) {
      for (final r in p.collisionBodies) {
        _indexSolid(r);
      }
      for (
        var by = (p.body.top - p.drawSize.height) ~/ 256;
        by <= (p.body.bottom + 50) ~/ 256;
        by++
      ) {
        for (
          var bx = (p.body.left - p.drawSize.width) ~/ 256;
          bx <= (p.body.right + p.drawSize.width) ~/ 256;
          bx++
        ) {
          propBuckets.putIfAbsent('$bx:$by', () => []).add(p);
        }
      }
    }
  }

  final int seed;
  final WorldStage stage;
  bool _authoring = true;
  Offset get spawn => _authoring ? stage.authoredSpawn : stage.spawn;
  Offset _at(Offset raw) => _authoring ? raw : raw * worldScale;
  Rect get settlement => stage == WorldStage.forest
      ? (_authoring ? authoredTown : town)
      : Rect.fromCenter(
          center: spawn,
          width: 900 * (_authoring ? 1 : worldScale),
          height: 900 * (_authoring ? 1 : worldScale),
        );
  Offset get healAt => _at(
    stage == WorldStage.forest
        ? stage.authoredSpawn - const Offset(0, 55)
        : stage.authoredSpawn + const Offset(-280, -100),
  );
  Offset get merchantAt => _at(_authoredMerchant);
  late final Offset _authoredMerchant = stage == WorldStage.forest
      ? const Offset(3952, 2984)
      : stage == WorldStage.future
      ? stage.authoredSpawn + const Offset(120, -70)
      : _merchantAnchor();
  Offset _merchantAnchor() {
    final preferred = spawn + const Offset(250, 280);
    for (var radius = 0.0; radius <= 900; radius += 40) {
      for (var i = 0; i < (radius == 0 ? 1 : 32); i++) {
        final angle = i * math.pi / 16;
        final candidate =
            preferred + Offset(math.cos(angle), math.sin(angle)) * radius;
        final body = Rect.fromCenter(
          center: candidate - const Offset(0, 36),
          width: 110,
          height: 48,
        );
        if (!blocked(body) &&
            trails.every(
              (trail) => trail.distance(body.center) > trail.width / 2 + 75,
            )) {
          return candidate;
        }
      }
    }
    throw StateError('The authored camp has no accessible merchant site');
  }

  Offset get elderAt => _at(
    stage == WorldStage.forest
        ? const Offset(3660, 2952)
        : stage.authoredSpawn + const Offset(-160, -70),
  );
  late final _authoredSites = authoredSitesForStage(stage);
  List<QuestSite> get sites =>
      _authoring ? _authoredSites : sitesForStage(stage);
  late final List<Offset> _authoredChests = stage == WorldStage.forest
      ? authoredStageChests
      : [
          spawn + const Offset(0, 180),
          ...sites.map((s) => s.at + const Offset(130, 60)),
          for (final t in trails.skip(2)) t.points.last + const Offset(60, 70),
          for (final trail in trails.take(3)) ..._roadTreasures(trail),
        ];
  late final List<Offset> chests = _authoredChests
      .map((p) => p * worldScale)
      .toList();

  List<Offset> _roadTreasures(Trail trail) {
    final lengths = [
      for (var i = 1; i < trail.points.length; i++)
        (trail.points[i] - trail.points[i - 1]).distance,
    ];
    final total = lengths.fold(0.0, (sum, length) => sum + length);
    return List.generate(8, (i) {
      var distance = total * (i + 1) / 9;
      for (var segment = 0; segment < lengths.length; segment++) {
        if (distance <= lengths[segment]) {
          return Offset.lerp(
            trail.points[segment],
            trail.points[segment + 1],
            distance / lengths[segment],
          )!;
        }
        distance -= lengths[segment];
      }
      return trail.points.last;
    });
  }

  late List<RegionShape> woods, lakes, sandFields, clearings;
  late RegionShape river;
  RegionShape get sand => sandFields.first;
  bool isSand(Offset p) => sandFields.any((field) => field.contains(p));
  bool isWooded(Offset p) =>
      !isSand(p) &&
      !clearings.any((clearing) => clearing.contains(p)) &&
      woods.any((wood) => wood.contains(p));
  late Rect bridge;
  late List<Rect> bridges;
  bool onBridge(Rect body) => bridges.any(
    (b) =>
        b.deflate(3).contains(body.topLeft) &&
        b.deflate(3).contains(body.bottomRight),
  );
  late List<Trail> trails;
  final List<WorldProp> props = [];
  final List<WorldProp> campProps = [];
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
      !bridges.any((b) => b.contains(p));
  bool blocked(Rect body, {bool waterOnly = false, bool ignoreWater = false}) {
    if (body.left < 0 ||
        body.top < 0 ||
        body.right > (_authoring ? authoredWorldSize : worldSize).width ||
        body.bottom > (_authoring ? authoredWorldSize : worldSize).height) {
      return true;
    }
    for (var y = body.top ~/ 128; y <= body.bottom ~/ 128; y++) {
      for (var x = body.left ~/ 128; x <= body.right ~/ 128; x++) {
        if ((_solids['$x:$y'] ?? const <Rect>[]).any((s) => s.overlaps(body))) {
          return true;
        }
      }
    }
    if (ignoreWater) return false;
    if (waterOnly) {
      for (var iy = 0; iy <= 2; iy++) {
        for (var ix = 0; ix <= 2; ix++) {
          if (!isWater(
            Offset(
              body.left + body.width * ix / 2,
              body.top + body.height * iy / 2,
            ),
          )) {
            return true;
          }
        }
      }
      return false;
    }
    if (lakes.any((l) => l.overlaps(body))) return true;
    if (!onBridge(body)) {
      if (river.overlaps(body)) return true;
    }
    return false;
  }

  bool largeWater(Offset at) {
    for (var y = -1; y <= 1; y++) {
      for (var x = -1; x <= 1; x++) {
        if (!isWater(at + Offset(x * 65, y * 65))) return false;
      }
    }
    return true;
  }

  bool clearBoardingLine(Offset from, Offset to) {
    final steps = math.max(1, ((to - from).distance / 5).ceil());
    for (var i = 0; i <= steps; i++) {
      if (blocked(
        Rect.fromCenter(
          center: Offset.lerp(from, to, i / steps)!,
          width: 4,
          height: 4,
        ),
        ignoreWater: true,
      )) {
        return false;
      }
    }
    return true;
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
        sweep.right > (_authoring ? authoredWorldSize : worldSize).width ||
        sweep.bottom > (_authoring ? authoredWorldSize : worldSize).height) {
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
        if (!onBridge(body) && river.overlaps(body)) {
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

  Offset move(Offset from, Offset delta, Size size, {bool waterOnly = false}) {
    var p = from;
    final n = math.max(
      1,
      (math.max(delta.dx.abs(), delta.dy.abs()) / 6).ceil(),
    );
    final step = delta / n.toDouble();
    for (var i = 0; i < n; i++) {
      if (!blocked(
        Rect.fromLTWH(p.dx + step.dx, p.dy + step.dy, size.width, size.height),
        waterOnly: waterOnly,
      )) {
        p += step;
        continue;
      }
      if (!blocked(
        Rect.fromLTWH(p.dx + step.dx, p.dy, size.width, size.height),
        waterOnly: waterOnly,
      )) {
        p += Offset(step.dx, 0);
      }
      if (!blocked(
        Rect.fromLTWH(p.dx, p.dy + step.dy, size.width, size.height),
        waterOnly: waterOnly,
      )) {
        p += Offset(0, step.dy);
      }
    }
    return p;
  }

  Offset? spawnNear(Offset desired, Size body, {bool waterOnly = false}) {
    if (!blocked(
      Rect.fromLTWH(desired.dx, desired.dy, body.width, body.height),
      waterOnly: waterOnly,
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
        if (!blocked(
          Rect.fromLTWH(p.dx, p.dy, body.width, body.height),
          waterOnly: waterOnly,
        )) {
          return p;
        }
      }
    }
    return null;
  }

  String areaName(Offset p) {
    if (stage != WorldStage.forest) {
      if (settlement.contains(p)) {
        return switch (stage) {
          WorldStage.past => '왕국 야영지',
          WorldStage.future => '저항군 거점',
          _ => '시간 연구단 야영지',
        };
      }
      if (isWater(p)) {
        return switch (stage) {
          WorldStage.past => '고대 수로',
          WorldStage.future => '냉각 수로',
          _ => '잊힌 오아시스',
        };
      }
      return stage.theme;
    }
    if (town.contains(p)) return '분수 마을';
    if (isSand(p)) return p.dx > 12000 * worldScale ? '태양의 사구' : '황금 모래벌판';
    if (lakes.any((l) => l.bounds.inflate(220).contains(p))) return '푸른 호숫가';
    if ((p.dx - 5300 * worldScale).abs() < 550 * worldScale) return '달빛 강변';
    if (clearings.any((c) => c.contains(p))) return '바람꽃 초원';
    if (isWooded(p)) return '이끼 숲';
    return '햇살 초원';
  }

  List<Offset> route(Offset from, Offset to, Size size) {
    const grid = 32.0 * worldScale;
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

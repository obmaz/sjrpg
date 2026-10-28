import 'dart:math' as math;
import 'dart:ui';

import 'stage_content.dart';

/// Coordinates are measured against each complete settlement illustration.
/// Keeping service markers and collision in the same coordinate system prevents
/// independently placed buildings and NPCs from drifting apart.
class AuthoredSettlement {
  AuthoredSettlement(this.stage, Offset spawn) {
    final data = _layouts[stage]!;
    bounds = Rect.fromLTWH(
      spawn.dx - data.spawn.dx * extent,
      spawn.dy - data.spawn.dy * extent,
      extent,
      extent,
    );
  }
  static const extent = 1560.0;
  final WorldStage stage;
  late final Rect bounds;
  _SettlementLayout get _layout => _layouts[stage]!;
  String get imageKey => 'settlement-${stage.name}';
  Offset point(Offset uv) => bounds.topLeft + uv * extent;
  Offset get well => point(_layout.well);

  /// Clear standing center below the painted basin, outside its solid rim.
  Offset get wellApproach =>
      well + Offset(0, _layout.wellRadius.dy * extent + 35);
  Offset get merchant => point(_layout.merchant);
  Offset get blacksmith => point(_layout.blacksmith);
  Offset get stable => point(_layout.stable);
  Offset get elder => point(_layout.elder);
  Offset questGiver(TimePath path) => point(
    path == TimePath.past ? const Offset(.44, .57) : const Offset(.62, .57),
  );
  List<Offset> get chestSpots => [
    for (final uv in const [
      Offset(.44, .62),
      Offset(.57, .62),
      Offset(.36, .43),
      Offset(.65, .43),
      Offset(.47, .72),
      Offset(.57, .25),
    ])
      point(uv),
  ];
  List<List<Offset>> get gatePaths => [
    for (final line in const [
      [Offset(.50, .23), Offset(.50, -.15)],
      [Offset(.50, .74), Offset(.50, 1.15)],
      [Offset(.17, .425), Offset(-.15, .425)],
      [Offset(.83, .425), Offset(1.15, .425)],
    ])
      line.map(point).toList(),
  ];

  /// Closed line through the same wall vertices, spanning the four open gates.
  /// It excludes the outside ground visible at the corners of the square art.
  late final safeBoundary = const [
    Offset(.43, .12),
    Offset(.57, .12),
    Offset(.80, .135),
    Offset(.91, .21),
    Offset(.925, .355),
    Offset(.93, .49),
    Offset(.95, .70),
    Offset(.94, .83),
    Offset(.81, .88),
    Offset(.58, .85),
    Offset(.43, .85),
    Offset(.28, .86),
    Offset(.08, .84),
    Offset(.045, .72),
    Offset(.075, .49),
    Offset(.08, .35),
    Offset(.09, .19),
    Offset(.14, .115),
    Offset(.39, .11),
  ].map(point).toList(growable: false);

  List<List<Offset>> get collisionPolygons {
    final shapes = <List<Offset>>[
      ..._layout.buildings,
      List.generate(24, (i) {
        final a = i * math.pi / 12;
        return _layout.well +
            Offset(
              math.cos(a) * _layout.wellRadius.dx,
              math.sin(a) * _layout.wellRadius.dy,
            );
      }),
    ];
    // Four perimeter runs leave the painted cardinal gates open. Narrow
    // segments follow the visible fence instead of an unrelated circular ward.
    for (final run in const [
      [
        Offset(.08, .35),
        Offset(.09, .19),
        Offset(.14, .115),
        Offset(.39, .11),
        Offset(.43, .12),
      ],
      [
        Offset(.57, .12),
        Offset(.80, .135),
        Offset(.91, .21),
        Offset(.925, .355),
      ],
      [
        Offset(.075, .49),
        Offset(.045, .72),
        Offset(.08, .84),
        Offset(.28, .86),
        Offset(.43, .85),
      ],
      [
        Offset(.93, .49),
        Offset(.95, .70),
        Offset(.94, .83),
        Offset(.81, .88),
        Offset(.58, .85),
      ],
    ]) {
      for (var i = 1; i < run.length; i++) {
        final a = run[i - 1], b = run[i], d = b - a;
        final n = Offset(-d.dy, d.dx) / d.distance * .007;
        shapes.add([a + n, b + n, b - n, a - n]);
      }
    }
    return shapes.map((s) => s.map(point).toList()).toList();
  }
}

class _SettlementLayout {
  const _SettlementLayout({
    this.spawn = const Offset(.50, .525),
    this.well = const Offset(.50, .44),
    this.wellRadius = const Offset(.105, .064),
    required this.merchant,
    required this.blacksmith,
    required this.stable,
    required this.elder,
    required this.buildings,
  });
  final Offset spawn, well, wellRadius, merchant, blacksmith, stable, elder;
  final List<List<Offset>> buildings;
}

const _forestBuildings = [
  [
    Offset(.145, .18),
    Offset(.29, .135),
    Offset(.375, .185),
    Offset(.375, .275),
    Offset(.30, .305),
    Offset(.18, .29),
    Offset(.15, .25),
  ],
  [
    Offset(.70, .15),
    Offset(.80, .08),
    Offset(.90, .13),
    Offset(.915, .26),
    Offset(.875, .30),
    Offset(.77, .285),
    Offset(.70, .25),
  ],
  [
    Offset(.065, .565),
    Offset(.21, .515),
    Offset(.34, .575),
    Offset(.35, .695),
    Offset(.31, .735),
    Offset(.15, .73),
    Offset(.065, .67),
  ],
  [
    Offset(.67, .58),
    Offset(.80, .55),
    Offset(.91, .61),
    Offset(.915, .74),
    Offset(.855, .795),
    Offset(.715, .77),
    Offset(.665, .70),
  ],
  [Offset(.48, .34), Offset(.52, .34), Offset(.535, .44), Offset(.47, .44)],
];
const _layouts = <WorldStage, _SettlementLayout>{
  WorldStage.forest: _SettlementLayout(
    merchant: Offset(.31, .335),
    blacksmith: Offset(.76, .32),
    stable: Offset(.385, .67),
    elder: Offset(.63, .71),
    buildings: _forestBuildings,
  ),
  WorldStage.sands: _SettlementLayout(
    merchant: Offset(.72, .33),
    blacksmith: Offset(.32, .32),
    stable: Offset(.58, .69),
    elder: Offset(.39, .68),
    buildings: [
      [
        Offset(.10, .15),
        Offset(.24, .07),
        Offset(.39, .14),
        Offset(.39, .28),
        Offset(.22, .30),
        Offset(.10, .26),
      ],
      [
        Offset(.63, .17),
        Offset(.78, .12),
        Offset(.91, .18),
        Offset(.91, .29),
        Offset(.72, .30),
        Offset(.63, .26),
      ],
      [
        Offset(.06, .57),
        Offset(.21, .52),
        Offset(.36, .58),
        Offset(.36, .70),
        Offset(.19, .73),
        Offset(.06, .68),
      ],
      [
        Offset(.60, .59),
        Offset(.78, .52),
        Offset(.93, .58),
        Offset(.93, .73),
        Offset(.78, .77),
        Offset(.60, .72),
      ],
    ],
  ),
  WorldStage.past: _SettlementLayout(
    merchant: Offset(.31, .33),
    blacksmith: Offset(.61, .72),
    stable: Offset(.65, .355),
    elder: Offset(.37, .69),
    buildings: [
      [
        Offset(.10, .18),
        Offset(.23, .15),
        Offset(.35, .20),
        Offset(.35, .29),
        Offset(.20, .31),
        Offset(.10, .27),
      ],
      [
        Offset(.65, .16),
        Offset(.80, .10),
        Offset(.92, .17),
        Offset(.92, .30),
        Offset(.78, .33),
        Offset(.65, .29),
      ],
      [
        Offset(.055, .57),
        Offset(.20, .52),
        Offset(.35, .59),
        Offset(.35, .72),
        Offset(.20, .75),
        Offset(.055, .69),
      ],
      [
        Offset(.63, .59),
        Offset(.79, .52),
        Offset(.93, .59),
        Offset(.93, .74),
        Offset(.79, .78),
        Offset(.63, .73),
      ],
    ],
  ),
  WorldStage.future: _SettlementLayout(
    spawn: Offset(.51, .505),
    well: Offset(.51, .42),
    wellRadius: Offset(.10, .055),
    merchant: Offset(.62, .73),
    blacksmith: Offset(.33, .33),
    stable: Offset(.44, .69),
    elder: Offset(.74, .345),
    buildings: [
      [
        Offset(.075, .15),
        Offset(.24, .075),
        Offset(.40, .14),
        Offset(.405, .27),
        Offset(.30, .31),
        Offset(.10, .28),
      ],
      [
        Offset(.67, .16),
        Offset(.79, .10),
        Offset(.91, .15),
        Offset(.925, .28),
        Offset(.82, .32),
        Offset(.68, .28),
      ],
      [
        Offset(.06, .56),
        Offset(.20, .49),
        Offset(.40, .55),
        Offset(.41, .685),
        Offset(.31, .75),
        Offset(.10, .70),
      ],
      [
        Offset(.65, .58),
        Offset(.80, .51),
        Offset(.94, .57),
        Offset(.94, .71),
        Offset(.80, .765),
        Offset(.66, .70),
      ],
    ],
  ),
  WorldStage.tombs: _SettlementLayout(
    spawn: Offset(.45, .525),
    well: Offset(.443, .44),
    wellRadius: Offset(.04, .045),
    merchant: Offset(.38, .70),
    blacksmith: Offset(.73, .33),
    stable: Offset(.34, .32),
    elder: Offset(.62, .70),
    buildings: [
      [
        Offset(.08, .16),
        Offset(.23, .10),
        Offset(.38, .17),
        Offset(.38, .29),
        Offset(.22, .32),
        Offset(.08, .28),
      ],
      [
        Offset(.65, .16),
        Offset(.80, .10),
        Offset(.92, .17),
        Offset(.92, .30),
        Offset(.78, .32),
        Offset(.65, .28),
      ],
      [
        Offset(.06, .61),
        Offset(.21, .55),
        Offset(.36, .61),
        Offset(.36, .73),
        Offset(.20, .77),
        Offset(.06, .71),
      ],
      [
        Offset(.67, .62),
        Offset(.80, .56),
        Offset(.93, .62),
        Offset(.93, .77),
        Offset(.80, .80),
        Offset(.67, .74),
      ],
    ],
  ),
  WorldStage.foundry: _SettlementLayout(
    spawn: Offset(.56, .535),
    well: Offset(.56, .43),
    wellRadius: Offset(.11, .065),
    merchant: Offset(.72, .32),
    blacksmith: Offset(.44, .70),
    stable: Offset(.40, .285),
    elder: Offset(.61, .72),
    buildings: [
      [
        Offset(.065, .16),
        Offset(.26, .08),
        Offset(.41, .15),
        Offset(.42, .25),
        Offset(.25, .29),
        Offset(.08, .26),
      ],
      [
        Offset(.65, .15),
        Offset(.77, .10),
        Offset(.91, .17),
        Offset(.92, .29),
        Offset(.76, .30),
        Offset(.65, .25),
      ],
      [
        Offset(.055, .55),
        Offset(.23, .49),
        Offset(.40, .57),
        Offset(.41, .70),
        Offset(.25, .76),
        Offset(.06, .69),
      ],
      [
        Offset(.62, .60),
        Offset(.80, .53),
        Offset(.95, .61),
        Offset(.95, .75),
        Offset(.81, .79),
        Offset(.62, .72),
      ],
    ],
  ),
  WorldStage.convergence: _SettlementLayout(
    spawn: Offset(.48, .535),
    well: Offset(.48, .42),
    wellRadius: Offset(.10, .065),
    merchant: Offset(.38, .69),
    blacksmith: Offset(.70, .32),
    stable: Offset(.60, .70),
    elder: Offset(.33, .30),
    buildings: [
      [
        Offset(.15, .15),
        Offset(.27, .10),
        Offset(.35, .16),
        Offset(.35, .25),
        Offset(.25, .28),
        Offset(.15, .24),
      ],
      [
        Offset(.64, .17),
        Offset(.80, .11),
        Offset(.92, .18),
        Offset(.92, .29),
        Offset(.79, .32),
        Offset(.64, .27),
      ],
      [
        Offset(.07, .52),
        Offset(.24, .47),
        Offset(.37, .55),
        Offset(.37, .67),
        Offset(.22, .70),
        Offset(.07, .64),
      ],
      [
        Offset(.64, .54),
        Offset(.78, .49),
        Offset(.93, .57),
        Offset(.93, .70),
        Offset(.79, .74),
        Offset(.64, .68),
      ],
    ],
  ),
};

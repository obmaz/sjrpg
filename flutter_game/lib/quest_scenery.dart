import 'dart:math' as math;
import 'dart:ui' as ui;

import 'world_model.dart';

/// Flat scenery, authored per objective rather than copied atlas cells.
/// None of these drawings adds water, walls, trees or collision geometry.
class QuestGroundPatch {
  const QuestGroundPatch({
    required this.siteId,
    required this.center,
    required this.design,
    required this.size,
  });
  final String siteId;
  final ui.Offset center;
  final QuestGroundDesign design;
  final ui.Size size;
  String get composition => design.name;
  ui.Rect get bounds => ui.Rect.fromCenter(
    center: center,
    width: size.width,
    height: size.height,
  );
}

enum QuestGroundDesign {
  rootGarden,
  moonCrescent,
  sunSpokes,
  buriedCourtyard,
  archiveRows,
  sundial,
  canyonThreshold,
  signalFragments,
  impactFan,
  crystalStrata,
  observatory,
  crownMosaic,
  solarKiln,
  originSpiral,
  uplinkPlaza,
  relayLanes,
  coreCircuit,
  funeraryCauseway,
  lanternTerraces,
  vaultChambers,
  pumpChannels,
  switchyard,
  freightDock,
  memoryGarden,
  resonanceRipples,
  anchorCrossing,
}

const _designs = {
  'roots': QuestGroundDesign.rootGarden,
  'moon': QuestGroundDesign.moonCrescent,
  'sun': QuestGroundDesign.sunSpokes,
  'past-1': QuestGroundDesign.buriedCourtyard,
  'past-2': QuestGroundDesign.archiveRows,
  'past-3': QuestGroundDesign.sundial,
  'past-4': QuestGroundDesign.canyonThreshold,
  'future-1': QuestGroundDesign.signalFragments,
  'future-2': QuestGroundDesign.impactFan,
  'future-3': QuestGroundDesign.crystalStrata,
  'future-4': QuestGroundDesign.observatory,
  'crown': QuestGroundDesign.crownMosaic,
  'sunfire': QuestGroundDesign.solarKiln,
  'origin': QuestGroundDesign.originSpiral,
  'uplink': QuestGroundDesign.uplinkPlaza,
  'relay': QuestGroundDesign.relayLanes,
  'gate': QuestGroundDesign.coreCircuit,
  'tomb-seal': QuestGroundDesign.funeraryCauseway,
  'tomb-lantern': QuestGroundDesign.lanternTerraces,
  'tomb-vault': QuestGroundDesign.vaultChambers,
  'foundry-pump': QuestGroundDesign.pumpChannels,
  'foundry-grid': QuestGroundDesign.switchyard,
  'foundry-dock': QuestGroundDesign.freightDock,
  'garden-memory': QuestGroundDesign.memoryGarden,
  'garden-resonance': QuestGroundDesign.resonanceRipples,
  'garden-anchor': QuestGroundDesign.anchorCrossing,
};

class QuestScenery {
  QuestScenery(this.world)
    : patches = List.unmodifiable([
        for (final site in world.sites)
          QuestGroundPatch(
            siteId: site.id,
            center: site.at,
            design: _designs[site.id]!,
            size: site.id == 'roots'
                ? const ui.Size(1500, 1500)
                : const ui.Size(1120, 1000),
          ),
      ]);
  final AdventureWorld world;
  final List<QuestGroundPatch> patches;

  /// Painted underneath the actual roads; every approach remains legible.
  void paintGround(ui.Canvas canvas, ui.Rect view, {ui.Shader? stoneTexture}) {
    if (world.stage == WorldStage.forest) {
      for (final patch in patches) {
        if (!patch.bounds.overlaps(view)) continue;
        final ground = ui.Rect.fromCenter(
          center: patch.center + const ui.Offset(0, 20),
          width: 310,
          height: 170,
        );
        canvas.drawOval(
          ground,
          ui.Paint()
            ..shader = ui.Gradient.radial(ground.center, 155, const [
              ui.Color(0x88a09574),
              ui.Color(0x00958259),
            ]),
        );
      }
      return;
    }
    for (final patch in patches) {
      if (!patch.bounds.overlaps(view)) continue;
      canvas.save();
      canvas.translate(patch.center.dx, patch.center.dy);
      _SitePainter(
        canvas,
        patch.design,
        stoneTexture,
        buriedInSand: world.stage == WorldStage.sands,
      ).paint();
      canvas.restore();
    }
  }

  /// One independent full scene, never tiled, mirrored or reused elsewhere.
}

/// Ground-only strokes are baked once into TerrainArt's bounded picture cache.
/// Coordinates and details are authored, not taken from simulation randomness.
class _SitePainter {
  _SitePainter(
    this.c,
    this.design,
    this.stoneTexture, {
    this.buriedInSand = false,
  });
  final ui.Canvas c;
  final QuestGroundDesign design;
  final ui.Shader? stoneTexture;
  final bool buriedInSand;
  final ui.Paint brush = ui.Paint();
  static const stone = ui.Color(0xffafa58a);
  static const sand = ui.Color(0xffd7b677);
  static const moss = ui.Color(0xff718454);
  static const slate = ui.Color(0xff465c64);
  static const cyan = ui.Color(0xff71b6b4);

  ui.Path curve(List<ui.Offset> points) {
    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      path.quadraticBezierTo(a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  void line(List<ui.Offset> points, ui.Color color, double width) {
    c.drawPath(
      curve(points),
      brush
        ..shader = null
        ..style = ui.PaintingStyle.stroke
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round
        ..strokeWidth = width
        ..color = buriedInSand ? color.withValues(alpha: color.a * .30) : color,
    );
  }

  void stain(ui.Offset at, double x, double y, ui.Color color) {
    final rect = ui.Rect.fromCenter(center: at, width: x * 2, height: y * 2);
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(1, y / x);
    c.drawCircle(
      ui.Offset.zero,
      x,
      brush
        ..style = ui.PaintingStyle.fill
        ..shader = ui.Gradient.radial(ui.Offset.zero, x, [
          buriedInSand ? color.withValues(alpha: color.a * .28) : color,
          color.withAlpha(0),
        ]),
    );
    c.restore();
    // Keep every following stroke independent of this local gradient.
    brush.shader = null;
    assert(rect.width <= 1120 && rect.height <= 1000);
  }

  void paving(
    List<ui.Offset> points, {
    ui.Color color = stone,
    double width = 96,
  }) {
    if (buriedInSand) {
      _buriedFragments(points, color, width);
      return;
    }
    line(points, const ui.Color(0x332a3029), width + 9);
    line(points, color.withAlpha(155), width);
    if (stoneTexture != null) {
      c.drawPath(
        curve(points),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round
          ..strokeWidth = width - 3
          ..shader = stoneTexture
          ..colorFilter = ui.ColorFilter.mode(
            color.withAlpha(170),
            ui.BlendMode.modulate,
          ),
      );
    }

    // Irregular flat slabs follow the composition, never a rectangular tile grid.
    for (var edge = 1; edge < points.length; edge++) {
      final a = points[edge - 1], b = points[edge], delta = b - a;
      final length = delta.distance;
      if (length < 1) continue;
      final side = ui.Offset(-delta.dy, delta.dx) / length;
      for (var d = 17.0; d < length; d += 37) {
        final middle = a + delta * (d / length);
        line(
          [middle - side * (width * .37), middle + side * (width * .39)],
          const ui.Color(0x68585444),
          2,
        );
      }
    }
  }

  void _buriedFragments(List<ui.Offset> points, ui.Color color, double width) {
    // Sand interrupts the former paving: no continuous strip, border or slab grid.
    for (var edge = 1; edge < points.length; edge++) {
      final a = points[edge - 1], delta = points[edge] - a;
      if (delta.distance < 1) continue;
      final axis = delta / delta.distance, side = ui.Offset(-axis.dy, axis.dx);
      for (
        var d = 20.0 + edge % 3 * 13;
        d < delta.distance;
        d += 83 + edge % 4 * 11
      ) {
        final t = d / delta.distance;
        final center =
            a + axis * d + side * (math.sin(d * .027 + edge) * width * .28);
        final half = math.min(15.0, width * .22), along = 8.0 + edge % 3 * 3;
        final fragment = ui.Path()
          ..addPolygon([
            center - axis * along - side * half,
            center + axis * (along * .8) - side * (half * .6),
            center + axis * along + side * half,
            center - axis * (along * .75) + side * (half * .7),
          ], true);
        c.drawPath(
          fragment,
          brush
            ..shader = null
            ..style = ui.PaintingStyle.fill
            ..color = ui.Color.lerp(
              color,
              sand,
              .7,
            )!.withAlpha(30 + (t * 17).round()),
        );
      }
    }
  }

  void arc(
    ui.Offset center,
    double radius,
    double start,
    double sweep, {
    ui.Color color = stone,
    double width = 28,
  }) {
    final points = [
      for (var i = 0; i <= 24; i++)
        center +
            ui.Offset(
                  math.cos(start + sweep * i / 24),
                  math.sin(start + sweep * i / 24),
                ) *
                radius,
    ];
    paving(points, color: color, width: width);
  }

  void scatter(
    ui.Offset center,
    int count, {
    ui.Color color = moss,
    double spread = 100,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = i * 2.399963,
          distance = math.sqrt((i + .5) / count) * spread;
      final at =
          center +
          ui.Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance * .65,
          );
      final size = 2.5 + i % 4;
      c.drawOval(
        ui.Rect.fromCenter(center: at, width: size * 2.6, height: size),
        brush
          ..shader = null
          ..style = ui.PaintingStyle.fill
          ..color = ui.Color.lerp(
            color,
            const ui.Color(0xffe0d3a4),
            i % 5 / 8,
          )!.withAlpha(buriedInSand ? 62 : 155),
      );
    }
  }

  void paint() {
    // These distinct footprints are deliberately not rotated copies of one plan.
    switch (design) {
      case QuestGroundDesign.rootGarden:
        break;
      case QuestGroundDesign.moonCrescent:
        stain(const ui.Offset(-110, -70), 420, 330, const ui.Color(0x88808d79));
        arc(
          const ui.Offset(-60, -20),
          205,
          .45,
          4.4,
          color: const ui.Color(0xffb9c5be),
          width: 90,
        );
        paving(const [
          ui.Offset(65, 140),
          ui.Offset(195, 230),
          ui.Offset(385, 160),
        ], width: 65);
        scatter(
          const ui.Offset(-250, 65),
          95,
          color: const ui.Color(0xff9cabd6),
          spread: 135,
        );
        scatter(
          const ui.Offset(135, -245),
          70,
          color: const ui.Color(0xffd8d5b9),
        );
      case QuestGroundDesign.sunSpokes:
        stain(const ui.Offset(70, 20), 450, 360, const ui.Color(0x99978a54));
        for (var i = 0; i < 7; i++) {
          final a = i * math.pi * 2 / 7 + .2;
          paving(
            [
              ui.Offset(math.cos(a), math.sin(a)) * 110,
              ui.Offset(math.cos(a), math.sin(a)) * (i.isEven ? 320 : 255),
            ],
            color: sand,
            width: 43,
          );
        }
        arc(ui.Offset.zero, 230, .1, 4.7, color: sand, width: 22);
        scatter(
          const ui.Offset(-270, 180),
          90,
          color: const ui.Color(0xffcfad5d),
        );
      case QuestGroundDesign.buriedCourtyard:
        stain(const ui.Offset(-80, 25), 440, 320, const ui.Color(0xbbc9a16a));
        paving(
          const [
            ui.Offset(-330, 150),
            ui.Offset(-250, -170),
            ui.Offset(80, -200),
            ui.Offset(220, 30),
          ],
          color: sand,
          width: 110,
        );
        arc(const ui.Offset(15, 60), 130, -.4, 3.1, color: stone, width: 55);
        scatter(const ui.Offset(260, -190), 120, color: sand, spread: 170);
      case QuestGroundDesign.archiveRows:
        stain(const ui.Offset(90, -40), 430, 350, const ui.Color(0xaa9c7955));
        for (var i = 0; i < 5; i++) {
          final y = -220 + i * 100.0;
          paving(
            [ui.Offset(-300 + i * 30, y), ui.Offset(110 + i * 36, y - 30)],
            width: 47,
            color: const ui.Color(0xffbba07b),
          );
        }
        paving(const [ui.Offset(-225, -250), ui.Offset(-160, 260)], width: 55);
        scatter(const ui.Offset(270, 160), 90, color: sand, spread: 150);
      case QuestGroundDesign.sundial:
        stain(ui.Offset.zero, 400, 340, const ui.Color(0xaac0a775));
        arc(ui.Offset.zero, 245, .2, 5.7, color: sand, width: 60);
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          line(
            [
              ui.Offset(math.cos(a), math.sin(a)) * 150,
              ui.Offset(math.cos(a), math.sin(a)) * 215,
            ],
            const ui.Color(0x99896b44),
            6,
          );
        }
        paving(const [
          ui.Offset(-310, 210),
          ui.Offset(-160, 80),
          ui.Offset(0, 0),
        ], width: 75);
      case QuestGroundDesign.canyonThreshold:
        stain(const ui.Offset(30, -70), 440, 365, const ui.Color(0xaaaf7955));
        for (var i = 0; i < 4; i++) {
          paving(
            [
              ui.Offset(-330 + i * 85, -240),
              ui.Offset(-240 + i * 120, -70),
              ui.Offset(-320 + i * 150, 185),
            ],
            color: ui.Color.lerp(sand, stone, i / 4)!,
            width: 32,
          );
        }
        paving(
          const [
            ui.Offset(-220, 260),
            ui.Offset(20, 90),
            ui.Offset(250, 100),
            ui.Offset(360, -140),
          ],
          color: sand,
          width: 110,
        );
      case QuestGroundDesign.signalFragments:
        stain(const ui.Offset(-90, 15), 440, 340, const ui.Color(0xaab3a684));
        for (var i = 0; i < 6; i++) {
          final x = -300 + i * 105.0;
          paving(
            [
              ui.Offset(x, -190 + i % 2 * 45),
              ui.Offset(x + 35, 130 - i % 3 * 60),
            ],
            color: slate,
            width: 36 + i * 3,
          );
        }
        arc(const ui.Offset(120, -70), 145, 1, 3.5, color: cyan, width: 11);
        scatter(const ui.Offset(-240, 230), 80, color: sand);
      case QuestGroundDesign.impactFan:
        stain(const ui.Offset(-80, -70), 390, 300, const ui.Color(0xaa82776e));
        for (var i = 0; i < 9; i++) {
          final a = -.3 + i * .32;
          line(
            [
              const ui.Offset(-120, -120),
              ui.Offset(
                -120 + math.cos(a) * (210 + i * 15),
                -120 + math.sin(a) * 270,
              ),
            ],
            const ui.Color(0x66776657),
            9 + i % 3 * 5,
          );
        }
        paving(
          const [
            ui.Offset(-340, 250),
            ui.Offset(-40, 190),
            ui.Offset(300, 290),
          ],
          width: 68,
          color: slate,
        );
        scatter(const ui.Offset(100, 80), 170, color: slate, spread: 220);
      case QuestGroundDesign.crystalStrata:
        stain(ui.Offset.zero, 450, 330, const ui.Color(0xaa9691aa));
        for (var i = 0; i < 6; i++) {
          line(
            [
              ui.Offset(-380, -190 + i * 75),
              ui.Offset(-170, -135 + i * 62),
              ui.Offset(80, -190 + i * 75),
              ui.Offset(350, -110 + i * 70),
            ],
            ui.Color.lerp(
              const ui.Color(0x889b8cb0),
              const ui.Color(0x88d1c6ae),
              i / 6,
            )!,
            19,
          );
        }
        arc(const ui.Offset(-80, 20), 145, -.3, 3.6, color: cyan, width: 33);
        scatter(
          const ui.Offset(255, -130),
          85,
          color: const ui.Color(0xffa7b6c1),
        );
      case QuestGroundDesign.observatory:
        stain(ui.Offset.zero, 420, 350, const ui.Color(0x888b8b80));
        arc(ui.Offset.zero, 250, -.5, 4.8, color: slate, width: 73);
        arc(ui.Offset.zero, 165, .6, 3.2, color: sand, width: 23);
        paving(
          const [ui.Offset(-360, -60), ui.Offset(0, -60), ui.Offset(0, 300)],
          color: stone,
          width: 50,
        );
        scatter(const ui.Offset(270, 190), 95, color: sand, spread: 125);
      case QuestGroundDesign.crownMosaic:
        stain(const ui.Offset(-15, 0), 430, 350, const ui.Color(0x99818b65));
        paving(
          const [
            ui.Offset(-300, 160),
            ui.Offset(-230, -190),
            ui.Offset(-90, -40),
            ui.Offset(50, -230),
            ui.Offset(190, -40),
            ui.Offset(310, -160),
            ui.Offset(260, 170),
            ui.Offset(-300, 160),
          ],
          color: stone,
          width: 50,
        );
        arc(const ui.Offset(0, 30), 115, 0, 6, color: sand, width: 28);
        scatter(const ui.Offset(-250, -180), 90, color: moss, spread: 130);
      case QuestGroundDesign.solarKiln:
        stain(const ui.Offset(0, -80), 435, 335, const ui.Color(0xaa85634d));
        arc(
          const ui.Offset(-55, -70),
          190,
          -.7,
          4.9,
          color: const ui.Color(0xffab7e58),
          width: 115,
        );
        paving(
          const [ui.Offset(95, -140), ui.Offset(300, -260)],
          width: 90,
          color: sand,
        );
        paving(
          const [ui.Offset(-100, 115), ui.Offset(-230, 285)],
          width: 80,
          color: stone,
        );
        scatter(
          const ui.Offset(225, 150),
          130,
          color: const ui.Color(0xff695d52),
          spread: 155,
        );
      case QuestGroundDesign.originSpiral:
        stain(ui.Offset.zero, 435, 340, const ui.Color(0x9975805b));
        final points = [
          for (var i = 0; i <= 70; i++)
            ui.Offset(
              math.cos(i * .115) * (35 + i * 3.8),
              math.sin(i * .115) * (35 + i * 3.8),
            ),
        ];
        paving(points, color: stone, width: 29);
        scatter(const ui.Offset(-260, 165), 130, color: moss, spread: 130);
        scatter(
          const ui.Offset(190, -225),
          90,
          color: const ui.Color(0xffbfaa76),
        );
      case QuestGroundDesign.uplinkPlaza:
        stain(ui.Offset.zero, 450, 360, const ui.Color(0xbb40575a));
        paving(
          const [
            ui.Offset(-320, -210),
            ui.Offset(160, -210),
            ui.Offset(300, -80),
            ui.Offset(300, 230),
            ui.Offset(-200, 230),
            ui.Offset(-320, 100),
            ui.Offset(-320, -210),
          ],
          color: slate,
          width: 93,
        );
        line(
          const [
            ui.Offset(-270, -170),
            ui.Offset(130, -170),
            ui.Offset(250, -50),
          ],
          cyan.withAlpha(140),
          4,
        );
        line(
          const [ui.Offset(-240, 185), ui.Offset(250, 185), ui.Offset(250, 40)],
          cyan.withAlpha(110),
          3,
        );
      case QuestGroundDesign.relayLanes:
        stain(const ui.Offset(45, -40), 440, 350, const ui.Color(0xbb555261));
        for (var i = 0; i < 3; i++) {
          paving(
            [
              ui.Offset(-320, -220 + i * 180),
              ui.Offset(-110, -110 + i * 130),
              ui.Offset(140, -170 + i * 150),
              ui.Offset(340, -70 + i * 150),
            ],
            color: slate,
            width: 72,
          );
        }
        arc(
          const ui.Offset(55, 0),
          115,
          .3,
          4.7,
          color: const ui.Color(0xff9989b2),
          width: 14,
        );
      case QuestGroundDesign.coreCircuit:
        stain(ui.Offset.zero, 450, 355, const ui.Color(0xbb3c5556));
        for (var i = 0; i < 4; i++) {
          final side = i.isEven ? 1.0 : -1.0;
          final y = i < 2 ? -200.0 : 200.0;
          paving(
            [
              ui.Offset(side * 350, y),
              ui.Offset(side * 150, y),
              ui.Offset(side * 150, y * .25),
              ui.Offset(0, y * .25),
            ],
            color: slate,
            width: 60,
          );
          line(
            [ui.Offset(side * 345, y), ui.Offset(side * 165, y)],
            cyan.withAlpha(145),
            3,
          );
        }
        arc(ui.Offset.zero, 100, 0, 6.28, color: stone, width: 38);
      case QuestGroundDesign.funeraryCauseway:
        stain(const ui.Offset(-90, 0), 440, 365, const ui.Color(0xaa8d806d));
        paving(
          const [
            ui.Offset(-340, 240),
            ui.Offset(-170, 170),
            ui.Offset(-80, -70),
            ui.Offset(140, -250),
          ],
          color: stone,
          width: 150,
        );
        for (var i = 0; i < 5; i++) {
          paving(
            [ui.Offset(-340 + i * 120, -200), ui.Offset(-290 + i * 105, -110)],
            color: const ui.Color(0xff978b79),
            width: 50,
          );
        }
        scatter(
          const ui.Offset(260, 180),
          100,
          color: const ui.Color(0xff8d8c66),
          spread: 150,
        );
      case QuestGroundDesign.lanternTerraces:
        stain(const ui.Offset(20, -50), 450, 360, const ui.Color(0xaaac9174));
        for (var i = 0; i < 4; i++) {
          arc(
            const ui.Offset(130, -90),
            105 + i * 70,
            1.15,
            2.8,
            color: stone,
            width: 35,
          );
        }
        paving(
          const [
            ui.Offset(160, -280),
            ui.Offset(200, -70),
            ui.Offset(315, 100),
          ],
          color: sand,
          width: 85,
        );
        scatter(
          const ui.Offset(-210, -230),
          90,
          color: const ui.Color(0xffc09a6e),
        );
      case QuestGroundDesign.vaultChambers:
        stain(ui.Offset.zero, 450, 340, const ui.Color(0xaa89808d));
        for (final center in [
          const ui.Offset(-210, -150),
          const ui.Offset(150, -170),
          const ui.Offset(190, 175),
        ]) {
          paving(
            [
              center + const ui.Offset(-85, 75),
              center + const ui.Offset(-85, -75),
              center + const ui.Offset(85, -75),
              center + const ui.Offset(85, 75),
            ],
            color: stone,
            width: 43,
          );
        }
        paving(const [
          ui.Offset(-340, 180),
          ui.Offset(-150, 110),
          ui.Offset(30, 0),
          ui.Offset(190, 175),
        ], width: 60);
      case QuestGroundDesign.pumpChannels:
        stain(ui.Offset.zero, 450, 350, const ui.Color(0xaa526361));
        for (var i = 0; i < 3; i++) {
          paving(
            [
              ui.Offset(-350, -210 + i * 150),
              ui.Offset(-80, -210 + i * 150),
              ui.Offset(80, -100 + i * 150),
              ui.Offset(320, -100 + i * 150),
            ],
            color: slate,
            width: 68,
          );
        }
        arc(const ui.Offset(-130, -70), 115, 0, 6, color: stone, width: 22);
        scatter(
          const ui.Offset(240, -235),
          90,
          color: const ui.Color(0xff829b8b),
        );
      case QuestGroundDesign.switchyard:
        stain(const ui.Offset(25, 0), 440, 350, const ui.Color(0xaa565566));
        for (var i = 0; i < 5; i++) {
          final y = -230 + i * 110.0;
          paving(
            [
              ui.Offset(-350, y),
              ui.Offset(-120, y),
              ui.Offset(90, y * .45),
              ui.Offset(340, y * .8),
            ],
            color: slate,
            width: 36,
          );
        }
        line(
          const [ui.Offset(-140, -260), ui.Offset(-140, 260)],
          const ui.Color(0xaaa99a67),
          7,
        );
        line(
          const [ui.Offset(110, -200), ui.Offset(110, 200)],
          cyan.withAlpha(110),
          5,
        );
      case QuestGroundDesign.freightDock:
        stain(const ui.Offset(20, -25), 450, 350, const ui.Color(0xaa66695c));
        paving(
          const [
            ui.Offset(-320, 210),
            ui.Offset(-320, -190),
            ui.Offset(280, -190),
            ui.Offset(280, 180),
          ],
          color: slate,
          width: 100,
        );
        for (var i = 0; i < 5; i++) {
          paving(
            [
              ui.Offset(-210 + i * 105, -160),
              ui.Offset(-210 + i * 105, 230 - i % 2 * 85),
            ],
            color: stone,
            width: 17,
          );
        }
        scatter(
          const ui.Offset(315, 200),
          90,
          color: const ui.Color(0xffa49b7c),
        );
      case QuestGroundDesign.memoryGarden:
        stain(const ui.Offset(-30, 0), 450, 350, const ui.Color(0x997f956b));
        paving(const [
          ui.Offset(-350, 190),
          ui.Offset(-230, -90),
          ui.Offset(-40, -200),
          ui.Offset(200, -120),
          ui.Offset(330, 150),
        ], width: 70);
        scatter(
          const ui.Offset(-260, -170),
          150,
          color: const ui.Color(0xffc7bd9b),
          spread: 140,
        );
        scatter(
          const ui.Offset(200, 200),
          130,
          color: const ui.Color(0xffb2b99b),
          spread: 140,
        );
        arc(const ui.Offset(30, 60), 140, .2, 3.4, color: moss, width: 30);
      case QuestGroundDesign.resonanceRipples:
        stain(ui.Offset.zero, 450, 350, const ui.Color(0x99818c8c));
        for (var i = 0; i < 4; i++) {
          arc(
            const ui.Offset(-80, 40),
            100 + i * 65,
            -.7 + i * .2,
            3.5 + i * .4,
            color: i.isEven ? stone : cyan,
            width: i.isEven ? 35 : 13,
          );
        }
        scatter(
          const ui.Offset(285, -145),
          130,
          color: const ui.Color(0xffa4b3bc),
          spread: 140,
        );
      case QuestGroundDesign.anchorCrossing:
        stain(ui.Offset.zero, 450, 350, const ui.Color(0x999b8d6d));
        paving(
          const [
            ui.Offset(-340, -220),
            ui.Offset(-130, -75),
            ui.Offset(100, 30),
            ui.Offset(320, 230),
          ],
          color: stone,
          width: 105,
        );
        paving(
          const [
            ui.Offset(-300, 260),
            ui.Offset(-150, 180),
            ui.Offset(30, -20),
            ui.Offset(220, -260),
          ],
          color: slate,
          width: 70,
        );
        arc(const ui.Offset(-20, 30), 155, .6, 4.5, color: sand, width: 21);
        scatter(const ui.Offset(-250, -5), 105, color: moss, spread: 120);
    }
  }
}

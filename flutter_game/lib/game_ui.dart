import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adventure.dart';
import 'affliction_widgets.dart';
import 'game_art.dart';
import 'health_widgets.dart';
import 'resource_meter.dart';
import 'world_model.dart';

const gold = Color(0xffd5b772),
    ink = Color(0xff102f2d),
    cream = Color(0xfff0e5c8);
String gameTime(double seconds) =>
    '${seconds ~/ 60}:${(seconds.toInt() % 60).toString().padLeft(2, '0')}';

class GameHud extends StatelessWidget {
  const GameHud(this.session, {this.onMap, super.key});
  final Adventure session;
  final VoidCallback? onMap;
  @override
  Widget build(BuildContext context) {
    final p = session.progress;
    final width = MediaQuery.sizeOf(context).width;
    final short = MediaQuery.sizeOf(context).height < 520;
    final statusRight = math.max(104.0, width - 360);
    final resourceHeight = math.max(
      22.0,
      ResourceMeter.minimumHeight(MediaQuery.textScalerOf(context)),
    );
    final statTop = 52 + resourceHeight + 10;
    return SizedBox(
      height: 130,
      child: Stack(
        children: [
          Positioned(
            top: 17,
            left: 57,
            right: statusRight,
            child: HealthMeter(session),
          ),
          Positioned(
            left: 77,
            right: statusRight + 6,
            top: 52,
            child: ResourceMeter(session, height: resourceHeight),
          ),
          Positioned(
            left: 77,
            right: statusRight + 6,
            top: 52 + resourceHeight + 3,
            child: LinearProgressIndicator(
              value: p.xp / p.nextLevelXp,
              minHeight: 3,
              color: gold,
              backgroundColor: const Color(0x99102425),
            ),
          ),
          Positioned(
            left: 10,
            top: 7,
            child: Container(
              width: 63,
              height: 72,
              decoration: BoxDecoration(
                color: ink,
                border: Border.all(color: gold, width: 2),
                borderRadius: BorderRadius.circular(35),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: CustomPaint(
                  painter: _PortraitPainter(session.art, p.heroClass),
                ),
              ),
            ),
          ),
          Positioned(
            left: 3,
            top: 91,
            child: AfflictionIcons(session.afflictions),
          ),
          Positioned(
            top: 60,
            left: 10,
            child: Container(
              width: 27,
              height: 27,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ink,
                shape: BoxShape.circle,
                border: Border.all(color: gold, width: 1.5),
              ),
              child: Text(
                '${p.level}',
                style: const TextStyle(color: cream, fontSize: 14),
              ),
            ),
          ),
          Positioned(
            left: 104,
            top: statTop,
            right: statusRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: _stat(
                    Icons.monetization_on_outlined,
                    _compactGold(p.gold),
                    gold,
                    semanticValue: '${p.gold}',
                  ),
                ),
                if (width >= 360) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: _stat(
                      Icons.wb_sunny_outlined,
                      gameTime(session.elapsed),
                      const Color(0xffdfce94),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 7,
            child: SizedBox(
              width: 85,
              height: 85,
              child: Semantics(
                button: true,
                label: '지도 확대',
                hint: session.trackedSite == null
                    ? '목표를 선택하면 미니맵에 방향을 표시합니다'
                    : '추적 목표 ${session.trackedSite!.name}. 금색 화살표는 직선 방향 안내입니다',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onMap,
                  child: CustomPaint(painter: MapPainter(session)),
                ),
              ),
            ),
          ),
          if (!short)
            Positioned(
              right: 10,
              top: 98,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: .8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  session.sheltered ? '안전 구역' : session.region,
                  style: const TextStyle(color: cream, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(
    IconData icon,
    String value,
    Color color, {
    String? semanticValue,
  }) => Semantics(
    label:
        '${icon == Icons.monetization_on_outlined ? '골드' : '모험 시간'} ${semanticValue ?? value}',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _compactGold(int value) => value >= 100000000
    ? '${value ~/ 100000000}억'
    : value >= 10000
    ? '${value ~/ 10000}만'
    : '$value';

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.art, this.heroClass);
  final GameArt art;
  final HeroClass heroClass;
  @override
  void paint(Canvas c, Size s) {
    if (!art.face(c, heroClass, Offset.zero & s)) {
      c.drawOval(Offset.zero & s, Paint()..color = ink);
    }
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter oldDelegate) =>
      oldDelegate.heroClass != heroClass || oldDelegate.art != art;
}

class ControlPainter extends CustomPainter {
  ControlPainter(this.art, this.sprite);
  final GameArt art;
  final String sprite;
  @override
  void paint(Canvas canvas, Size size) =>
      art.control(canvas, sprite, Offset.zero & size);
  @override
  bool shouldRepaint(covariant ControlPainter oldDelegate) =>
      oldDelegate.sprite != sprite;
}

class AbilityPicturePainter extends CustomPainter {
  AbilityPicturePainter(this.art, this.name);
  final GameArt art;
  final String name;
  @override
  void paint(Canvas canvas, Size size) {
    final picture = art.images[name];
    if (picture == null) return;
    canvas.drawImageRect(
      picture,
      Rect.fromLTWH(0, 0, picture.width.toDouble(), picture.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant AbilityPicturePainter old) =>
      old.art != art || old.name != name;
}

class MapPainter extends CustomPainter {
  MapPainter(this.session, {this.round = true, this.markerScale = 1});
  final Adventure session;
  final bool round;
  final double markerScale;
  static const _textureScale = 16.0;
  static final _textureTransform = Matrix4.diagonal3Values(
    1 / _textureScale,
    1 / _textureScale,
    1,
  ).storage;
  void _terrain(
    Canvas canvas,
    Path path,
    int material,
    Color color, {
    double? width,
  }) {
    final solid = Paint()..color = color;
    if (width != null) {
      solid
        ..style = PaintingStyle.stroke
        ..strokeWidth = width;
    }
    canvas.drawPath(path, solid);
    if (round || session.art.materials.length <= material) return;
    canvas.save();
    canvas.scale(_textureScale);
    final texture = Paint()
      ..shader = session.art.materials[material]
      ..color = const Color(0xaaffffff)
      ..filterQuality = FilterQuality.medium;
    if (width != null) {
      texture
        ..style = PaintingStyle.stroke
        ..strokeWidth = width / _textureScale;
    }
    canvas.drawPath(path.transform(_textureTransform), texture);
    canvas.restore();
  }

  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.save();
    if (round) c.clipPath(Path()..addOval(rect.deflate(3)));
    c.drawRect(rect, Paint()..color = const Color(0xff102a29));
    c.save();
    c.clipRect(rect);
    final view = round
        ? localMapBounds(session.hero.body.center)
        : Offset.zero & worldSize;
    c.scale(s.width / view.width, s.height / view.height);
    c.translate(-view.left, -view.top);
    c.clipRect(Offset.zero & worldSize);
    final base = session.world.stage.baseMaterial;
    final road = session.world.stage.roadMaterial;
    _terrain(
      c,
      Path()..addRect(Offset.zero & worldSize),
      base,
      session.world.stage.mapColor,
    );
    for (final wood in session.world.woods) {
      if (!round) {
        c.drawPath(
          wood.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 100
            ..color = const Color(0xff506d48),
        );
      }
      _terrain(c, wood.path, 1, const Color(0xff315947));
    }
    for (final clearing in session.world.clearings) {
      _terrain(c, clearing.path, base, session.world.stage.clearingColor);
    }
    for (final sand in session.world.sandFields) {
      _terrain(
        c,
        sand.path,
        session.world.stage == WorldStage.tombs ? 3 : 2,
        session.world.stage == WorldStage.tombs
            ? const Color(0xff9e967f)
            : const Color(0xffc7b579),
      );
    }
    final water = session.terrain.waterPath;
    if (!round) {
      c.drawPath(
        water,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 140
          ..color = const Color(0xffd5c99a),
      );
      c.drawPath(
        water,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 55
          ..color = const Color(0xff29636d),
      );
    }
    _terrain(c, water, 4, const Color(0xff3b91a0));
    c.save();
    c.clipPath(session.terrain.dryGroundPath, doAntiAlias: false);
    for (final trail in session.world.trails) {
      if (!round) {
        c.drawPath(
          trail.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = trail.width + 90
            ..color = const Color(0xff4a5540),
        );
      }
      _terrain(
        c,
        trail.path,
        road,
        const Color(0xffdac489),
        width: trail.width,
      );
    }
    _terrain(
      c,
      Path()..addRect(session.world.settlement),
      road,
      const Color(0xffe3d29a),
    );
    c.restore();
    for (final bridge in session.world.bridges) {
      _terrain(c, Path()..addRect(bridge), road, const Color(0xffdac489));
    }

    final sanctuary = session.world.sanctuary;
    c.drawCircle(
      sanctuary.center,
      sanctuary.radius,
      Paint()
        ..color = session.world.stage.sanctuaryColor.withValues(alpha: .08),
    );
    c.drawCircle(
      sanctuary.center,
      sanctuary.radius,
      Paint()
        ..color = session.world.stage.sanctuaryColor.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (round ? 10 : 30 * markerScale),
    );
    if (round) {
      for (final mob in session.mobs) {
        if (!mob.combatReady || mob.isDead || mob.isRemoving || mob.boss) {
          continue;
        }
        c.drawCircle(
          mob.body.center,
          mob.isElite ? 42 : 30,
          Paint()
            ..color = mob.isElite ? mob.tierColor : const Color(0xffef785e),
        );
      }
      for (var i = 0; i < session.stageChestLocations.length; i++) {
        if (session.openedChests.contains(i)) continue;
        c.drawCircle(session.stageChestLocations[i], 42, Paint()..color = gold);
      }
    }
    c.restore();
    Offset project(Offset at) => Offset(
      (at.dx - view.left) / view.width * s.width,
      (at.dy - view.top) / view.height * s.height,
    );
    if (!round) {
      // Decorations stay fixed in screen pixels while the actual map scales.
      final unit = markerScale;
      c.drawRect(
        rect.deflate(3 * unit),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * unit
          ..color = gold.withValues(alpha: .6),
      );
      final north = Offset(s.width - 35 * unit, 35 * unit);
      c.drawCircle(north, 18 * unit, Paint()..color = const Color(0xdd102a29));
      c.drawPath(
        Path()
          ..moveTo(north.dx, north.dy - 13 * unit)
          ..lineTo(north.dx - 5 * unit, north.dy + 8 * unit)
          ..lineTo(north.dx, north.dy + 4 * unit)
          ..lineTo(north.dx + 5 * unit, north.dy + 8 * unit)
          ..close(),
        Paint()..color = gold,
      );
      final scaleStart = Offset(25 * unit, s.height - 25 * unit);
      final scaleEnd = scaleStart + Offset(s.width * 1000 / worldSize.width, 0);
      c.drawLine(
        scaleStart,
        scaleEnd,
        Paint()
          ..color = cream
          ..strokeWidth = 2 * unit,
      );
      for (final point in [scaleStart, scaleEnd]) {
        c.drawLine(
          point - Offset(0, 4 * unit),
          point + Offset(0, 4 * unit),
          Paint()
            ..color = cream
            ..strokeWidth = unit,
        );
      }
    }
    final heroPoint = project(session.hero.body.center);
    final shopPoint = project(session.world.merchantAt),
        healPoint = project(session.world.healAt);
    final groupServices = (shopPoint - healPoint).distance < 40 * markerScale;
    final services = [
      ...(groupServices
          ? [(project(session.world.spawn), '거점', Icons.cottage_rounded, gold)]
          : [
              (shopPoint, '상점', Icons.storefront_rounded, gold),
              (
                healPoint,
                '회복',
                Icons.water_drop_rounded,
                const Color(0xff8ce6bd),
              ),
            ]),
      if (session.world.stage == WorldStage.forest)
        (
          project(session.world.blacksmithAt),
          '대장간',
          Icons.hardware_rounded,
          gold,
        ),
      if (session.world.stage == WorldStage.sands)
        for (final giver in timeQuestGivers)
          (
            project(giver.atOrigin(session.world.spawn)),
            giver.name,
            giver.path == TimePath.past
                ? Icons.auto_stories_rounded
                : Icons.cell_tower_rounded,
            session.timePath != null && session.timePath != giver.path
                ? const Color(0xff8faaa3)
                : giver.path == TimePath.past
                ? gold
                : const Color(0xff92e7f2),
          ),
    ];
    final occupied = <Offset>[heroPoint];
    for (final (anchor, label, icon, color) in services) {
      final radius = (round ? 7.0 : 10.0) * markerScale;
      if (round &&
          (anchor - rect.center).distance > s.shortestSide / 2 - radius - 3) {
        continue;
      }
      var point = anchor;
      if ((point - heroPoint).distance < 23 * markerScale) {
        final delta = point - heroPoint;
        point =
            heroPoint +
            (delta.distance < markerScale
                    ? const Offset(0, -1)
                    : delta / delta.distance) *
                (23 * markerScale);
      }
      if (!round) {
        for (
          var shift = 0;
          shift < 3 &&
              occupied.any(
                (other) => (point - other).distance < 21 * markerScale,
              );
          shift++
        ) {
          point += Offset(0, -24 * markerScale);
        }
      }
      occupied.add(point);
      if ((point - anchor).distance > markerScale) {
        c.drawLine(
          anchor,
          point,
          Paint()
            ..color = color.withValues(alpha: .5)
            ..strokeWidth = markerScale,
        );
      }
      c.drawCircle(point, radius, Paint()..color = ink);
      c.drawCircle(
        point,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = markerScale
          ..color = color,
      );
      final glyph = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            fontSize: (round ? 11 : 15) * markerScale,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      glyph.paint(c, point - Offset(glyph.width / 2, glyph.height / 2));
      glyph.dispose();
      if (!round &&
          markerScale <= 2.5 &&
          (point - heroPoint).distance > 45 * markerScale) {
        session.art.text(
          c,
          label,
          point - Offset(0, 22 * markerScale),
          size: 13 * markerScale,
          color: color,
        );
      }
    }
    final trackedSite = session.trackedSite;
    final orderedSites = [
      ...session.visibleSites.where((s) => s.id != trackedSite?.id),
      ?trackedSite,
    ];
    for (final site in orderedSites) {
      final tracked = site.id == trackedSite?.id;
      final done = session.cleansedSites.contains(site.id);
      var point = Offset(
        (site.at.dx - view.left) / view.width * s.width,
        (site.at.dy - view.top) / view.height * s.height,
      );
      var outside = false;
      final direction = point - rect.center;
      if (round) {
        final d = direction;
        final edge = s.shortestSide / 2 - (tracked ? 12 : 9);
        if (d.distance > edge) {
          outside = true;
          if (done) continue;
          point = rect.center + d / d.distance * edge;
        }
      }
      final r = (round ? 4.0 : 8.0) * markerScale;
      if (tracked) {
        c.drawCircle(point, r + 4 * markerScale, Paint()..color = ink);
        c.drawCircle(
          point,
          r + 3 * markerScale,
          Paint()
            ..color = gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * markerScale,
        );
      }
      if (tracked && round && outside) {
        c.save();
        c.translate(point.dx, point.dy);
        c.rotate(math.atan2(direction.dy, direction.dx));
        c.drawPath(
          Path()
            ..moveTo(5, 0)
            ..lineTo(-3, -4)
            ..lineTo(-1, 0)
            ..lineTo(-3, 4)
            ..close(),
          Paint()..color = gold,
        );
        c.restore();
        continue;
      }
      c.drawCircle(point, r + 1.5 * markerScale, Paint()..color = ink);
      c.drawCircle(
        point,
        r,
        Paint()..color = done ? const Color(0xff85d6aa) : gold,
      );
      c.drawCircle(point, r * .45, Paint()..color = const Color(0xff164d55));
      if (!round && markerScale <= 2.5) {
        session.art.text(
          c,
          '${site.name}${done ? ' ✓' : ''}',
          point - Offset(0, 23 * markerScale),
          size: 14 * markerScale,
          color: done ? const Color(0xff85d6aa) : gold,
        );
      }
    }
    for (final area in session.exhaustedAreas) {
      final point = project(area.stone);
      if (round && (point - rect.center).distance > s.shortestSide / 2 - 10) {
        continue;
      }
      final r = (round ? 3.0 : 5.0) * markerScale;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: point, width: r * 1.5, height: r * 2),
          Radius.circular(r * .4),
        ),
        Paint()..color = const Color(0xffa9d6d0),
      );
    }
    for (final boss in session.mobs.where(
      (m) => m.boss && m.combatReady && !m.isDead && !m.isRemoving,
    )) {
      var point = project(boss.body.center);
      if (round) {
        final delta = point - rect.center;
        final edge = s.shortestSide / 2 - 10;
        if (delta.distance > edge) {
          point = rect.center + delta / delta.distance * edge;
        }
      }
      final radius = (round ? 5.0 : 9.0) * markerScale;
      final diamond = Path()
        ..moveTo(point.dx, point.dy - radius)
        ..lineTo(point.dx + radius, point.dy)
        ..lineTo(point.dx, point.dy + radius)
        ..lineTo(point.dx - radius, point.dy)
        ..close();
      c.drawCircle(point, radius + 2 * markerScale, Paint()..color = ink);
      c.drawPath(diamond, Paint()..color = const Color(0xffef6455));
      c.drawCircle(point, radius * .3, Paint()..color = cream);
      if (!round &&
          markerScale <= 2.5 &&
          (point - heroPoint).distance > 35 * markerScale) {
        session.art.text(
          c,
          session.world.stage.bossName,
          point - Offset(0, 23 * markerScale),
          size: 14 * markerScale,
          color: const Color(0xffffa195),
        );
      }
    }
    final hero = Offset(
      (session.hero.body.center.dx - view.left) / view.width * s.width,
      (session.hero.body.center.dy - view.top) / view.height * s.height,
    );
    c.drawCircle(
      hero,
      round ? 3 : 5 * markerScale,
      Paint()..color = const Color(0xff9df3ee),
    );
    c.drawCircle(
      hero,
      round ? 3 : 5 * markerScale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white,
    );
    c.restore();
    if (round) {
      c.drawOval(
        rect.deflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = gold,
      );
      c.drawOval(
        rect.deflate(6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) => true;
}

class EffectIconPainter extends CustomPainter {
  EffectIconPainter(this.art, this.index);
  final GameArt art;
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final passive = index >= 8;
    final image =
        art.images[index >= 34
            ? 'physical-icons'
            : index >= 14
            ? 'skill-perks'
            : passive
            ? 'passive-icons'
            : 'combat-fx'];
    if (image == null) return;
    final columns = index >= 34
        ? 2
        : index >= 14
        ? 4
        : passive
        ? 3
        : 4;
    final localIndex = index >= 34
        ? index - 34
        : index >= 14
        ? index - 14
        : passive
        ? index - 8
        : index;
    final cell = image.width / columns;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
        (localIndex % columns) * cell,
        (localIndex ~/ columns) * cell,
        cell,
        cell,
      ).deflate(1),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant EffectIconPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.art != art;
}

class ActionButton extends StatefulWidget {
  const ActionButton({
    required this.art,
    required this.sprite,
    required this.label,
    required this.semanticLabel,
    this.semanticHint,
    required this.size,
    required this.onTap,
    this.onHold,
    this.onAimStart,
    this.onAimMove,
    this.onAimEnd,
    this.icon,
    this.effect,
    this.artwork,
    this.showLabel = true,
    this.insufficientResource = false,
    this.remaining = 0,
    this.total = 1,
    super.key,
  });
  final GameArt art;
  final String sprite, label, semanticLabel;
  final String? semanticHint;
  final double size, remaining, total;
  final VoidCallback onTap;
  final ValueChanged<bool>? onHold;
  final VoidCallback? onAimStart;
  final ValueChanged<Offset>? onAimMove;
  final ValueChanged<bool>? onAimEnd;
  final IconData? icon;
  final int? effect;
  final Widget? artwork;
  final bool showLabel, insufficientResource;
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  int? pointer;
  bool pressed = false;
  Offset origin = Offset.zero, aimDelta = Offset.zero;
  void release({bool cancelled = false}) {
    if (pointer != null) widget.onAimEnd?.call(cancelled);
    pointer = null;
    if (pressed) {
      widget.onHold?.call(false);
      if (mounted) setState(() => pressed = false);
    }
  }

  @override
  void dispose() {
    if (pointer != null) widget.onAimEnd?.call(true);
    widget.onHold?.call(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.semanticLabel,
    hint: widget.semanticHint,
    onTap: widget.onTap,
    excludeSemantics: true,
    child: Listener(
      onPointerDown: (event) {
        if (pointer != null) return;
        pointer = event.pointer;
        origin = event.position;
        aimDelta = Offset.zero;
        setState(() => pressed = true);
        if (widget.onAimStart != null) {
          widget.onAimStart!();
        } else {
          widget.onHold?.call(true);
          widget.onTap();
        }
      },
      onPointerMove: (event) {
        if (pointer != event.pointer || widget.onAimMove == null) return;
        setState(() => aimDelta = event.position - origin);
        widget.onAimMove!(aimDelta);
      },
      onPointerUp: (event) {
        if (pointer == event.pointer) release();
      },
      onPointerCancel: (event) {
        if (pointer == event.pointer) release(cancelled: true);
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size + (widget.showLabel ? 22 : 0),
        child: Column(
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedScale(
                      scale: pressed ? .94 : 1,
                      duration: const Duration(milliseconds: 70),
                      child: CustomPaint(
                        size: Size.square(widget.size),
                        painter: ControlPainter(widget.art, widget.sprite),
                      ),
                    ),
                    if (widget.artwork != null)
                      widget.artwork!
                    else if (widget.effect != null)
                      CustomPaint(
                        size: Size.square(widget.size * .74),
                        painter: EffectIconPainter(widget.art, widget.effect!),
                      )
                    else if (widget.icon != null)
                      Icon(widget.icon, size: widget.size * .43, color: cream),
                    if (widget.insufficientResource)
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0x66000000)),
                      ),
                    if (pressed && widget.onAimStart != null)
                      Positioned.fill(
                        child: ColoredBox(
                          color: aimDelta.distance > 156
                              ? const Color(0x99a12929)
                              : const Color(0x334bd8c2),
                          child: aimDelta.distance > 156
                              ? const Icon(Icons.close, color: Colors.white)
                              : Center(
                                  child: Transform.translate(
                                    offset:
                                        aimDelta.distance > widget.size * .28
                                        ? aimDelta /
                                              aimDelta.distance *
                                              widget.size *
                                              .28
                                        : aimDelta,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xaa9deee4),
                                        border: Border.all(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    if (widget.remaining > 0)
                      CustomPaint(
                        size: Size.square(widget.size),
                        painter: _CooldownPainter(
                          widget.remaining / widget.total,
                        ),
                      ),
                    if (!widget.showLabel && widget.remaining > 0)
                      Text(
                        '${widget.remaining.ceil()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.showLabel)
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: cream,
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _CooldownPainter extends CustomPainter {
  _CooldownPainter(this.ratio);
  final double ratio;
  @override
  void paint(Canvas c, Size s) => c.drawArc(
    (Offset.zero & s).deflate(5),
    -math.pi / 2,
    math.pi * 2 * ratio.clamp(0, 1),
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xaaebd293),
  );
  @override
  bool shouldRepaint(covariant _CooldownPainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}

class GameStick extends StatefulWidget {
  const GameStick({
    required this.art,
    required this.size,
    required this.onChange,
    super.key,
  });
  final GameArt art;
  final double size;
  final void Function(double, double) onChange;
  @override
  State<GameStick> createState() => _GameStickState();
}

class _GameStickState extends State<GameStick> {
  int? pointer;
  Offset knob = Offset.zero;
  void move(PointerEvent event) {
    if (pointer != event.pointer) return;
    final raw = event.localPosition - Offset(widget.size / 2, widget.size / 2),
        maximum = widget.size * .27,
        d = raw.distance;
    final delta = d > maximum ? raw / d * maximum : raw;
    setState(() => knob = delta);
    final intensity = (d / maximum).clamp(0.0, 1.0);
    widget.onChange(
      math.atan2(delta.dy, delta.dx),
      intensity < .18 ? 0 : (intensity - .18) / .82,
    );
  }

  void release() {
    pointer = null;
    if (mounted) setState(() => knob = Offset.zero);
    widget.onChange(0, 0);
  }

  @override
  void dispose() {
    widget.onChange(0, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '이동 조이스틱',
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (pointer != null) return;
        pointer = event.pointer;
        move(event);
      },
      onPointerMove: move,
      onPointerUp: (event) {
        if (pointer == event.pointer) release();
      },
      onPointerCancel: (event) {
        if (pointer == event.pointer) release();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: .7,
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: ControlPainter(widget.art, 'touchJoystick'),
              ),
            ),
            Transform.translate(
              offset: knob,
              child: CustomPaint(
                size: Size.square(widget.size * .36),
                painter: ControlPainter(widget.art, 'touchThumb'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class MenuButton extends StatelessWidget {
  const MenuButton({
    required this.art,
    required this.sprite,
    required this.label,
    required this.onTap,
    this.badge = 0,
    super.key,
  });
  final int badge;
  final GameArt art;
  final String sprite, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    child: Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: ControlPainter(art, sprite)),
              ),
              if (badge > 0)
                Positioned(
                  right: -4,
                  top: -5,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 23,
                      minHeight: 23,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xffc74c35),
                      shape: BoxShape.circle,
                      border: Border.all(color: gold, width: 1.5),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'action_glyph_art.dart';
import 'adventure.dart';
import 'affliction_widgets.dart';
import 'barbarian_icon_art.dart';
import 'combat_balance.dart';
import 'field_palettes.dart';
import 'game_art.dart';
import 'health_widgets.dart';
import 'resource_meter.dart';
import 'sorceress_icon_art.dart';
import 'world_model.dart';

const gold = Color(0xffd5b772),
    ink = Color(0xff102f2d),
    cream = Color(0xfff0e5c8);
const mobileSurface = Color(0xd915232c),
    mobileRaisedSurface = Color(0xee263943),
    mobileBorder = Color(0x557a949b),
    mobileAccent = Color(0xff8fd4d1),
    mobileText = Color(0xffe8f0f2);
const gameMetal = Color(0xffb3a079),
    gameMetalDark = Color(0xff5b5645),
    gameTeal = Color(0xff173b3e);
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
    final height = MediaQuery.sizeOf(context).height;
    final landscape = width > height && width >= 500;
    final short = height < 520 || landscape;
    final statusRight = math.max(104.0, width - (landscape ? 280 : 360));
    final resourceHeight = math.max(
      17.0,
      ResourceMeter.minimumHeight(MediaQuery.textScalerOf(context)),
    );
    return SizedBox(
      height: 130,
      child: Stack(
        children: [
          Positioned(
            top: 17,
            left: 57,
            right: statusRight,
            child: HealthMeter(session, height: 20),
          ),
          Positioned(
            left: 77,
            right: statusRight + 6,
            top: 42,
            child: ResourceMeter(session, height: resourceHeight),
          ),
          Positioned(
            left: 10,
            top: 7,
            child: Container(
              width: 63,
              height: 72,
              decoration: BoxDecoration(
                color: ink,
                border: Border.all(color: mobileBorder, width: 1.2),
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
                border: Border.all(color: mobileBorder, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${p.level}',
                    style: const TextStyle(color: cream, fontSize: 14),
                  ),
                ),
              ),
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
}

/// Shared generated medallions use the same circular face as learned skills.
class ActionIllustrationPainter extends CustomPainter {
  ActionIllustrationPainter(this.art, {this.fist = false});
  static const imageKey = 'combat-actions';
  final GameArt art;
  final bool fist;
  static bool draw(GameArt art, Canvas canvas, Size size, {bool fist = false}) {
    final image = art.images[imageKey];
    if (image == null) return false;
    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & size));
    final drawn = art.effects.draw(
      canvas,
      imageKey,
      fist ? 1 : 0,
      Offset.zero & size,
      columns: 2,
      rows: 1,
      inset: image.height * .12,
    );
    canvas.restore();
    return drawn;
  }

  @override
  void paint(Canvas canvas, Size size) {
    draw(art, canvas, size, fist: fist);
  }

  @override
  bool shouldRepaint(covariant ActionIllustrationPainter old) =>
      old.art != art || old.fist != fist;
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.art, this.heroClass);
  final GameArt art;
  final HeroClass heroClass;
  @override
  void paint(Canvas c, Size s) {
    if (heroClass == HeroClass.warrior &&
        art.images.containsKey('hero-helmeted-portrait')) {
      art.helmetedWarriorPortrait(c, Offset.zero & s);
    } else if (!art.face(c, heroClass, Offset.zero & s)) {
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
  void paint(Canvas canvas, Size size) {
    if (sprite != 'touchJoystick' && sprite != 'touchThumb') {
      art.control(canvas, sprite, Offset.zero & size);
      return;
    }
    final center = size.center(Offset.zero), radius = size.shortestSide / 2 - 2;
    final thumb = sprite == 'touchThumb';
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = thumb ? const Color(0xdd3b5755) : const Color(0x77263d37),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thumb ? 1.8 : 2.2
        ..color = gameMetal.withValues(alpha: thumb ? .9 : .72),
    );
    canvas.drawCircle(
      center,
      radius - 2.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = const Color(0x775e9186),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - .8),
      -math.pi + .25,
      2.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = const Color(0x99e2d3a9),
    );
    if (!thumb) {
      final mark = Paint()..color = const Color(0xbcc2c39f);
      final tip = radius * .76, half = math.max(4.0, radius * .085);
      for (var i = 0; i < 4; i++) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(i * math.pi / 2);
        canvas.drawPath(
          Path()
            ..moveTo(0, -tip - half * .6)
            ..lineTo(-half, -tip + half * .6)
            ..lineTo(half, -tip + half * .6)
            ..close(),
          mark,
        );
        canvas.restore();
      }
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * .58),
        -2.7,
        1.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x669fbaa8),
      );
    }
  }

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
    if (!round) {
      c.drawRect(
        Offset.zero & worldSize,
        Paint()..color = session.world.stage.mapColor,
      );
      session.terrain.fieldLandscape.paintOverview(
        c,
        view,
        macroColors: fieldPalettes[session.world.stage.name],
      );
    } else {
      _terrain(
        c,
        Path()..addRect(Offset.zero & worldSize),
        base,
        session.world.stage.mapColor,
      );
      for (final wood in session.world.woods) {
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
      round
          ? session.world.sanctuary.boundaryPath
          : (Path()..addRect(session.world.settlement)),
      road,
      const Color(0xffa89a77),
    );
    c.restore();
    final settlement = session.world.authoredSettlement;
    final settlementImage = session.art.images[settlement.imageKey];
    if (!round && settlementImage != null && view.overlaps(settlement.bounds)) {
      c.drawImageRect(
        settlementImage,
        Rect.fromLTWH(
          0,
          0,
          settlementImage.width.toDouble(),
          settlementImage.height.toDouble(),
        ),
        settlement.bounds,
        Paint()..filterQuality = FilterQuality.low,
      );
    }
    for (final bridge in session.world.bridges) {
      _terrain(c, Path()..addRect(bridge), road, const Color(0xffdac489));
    }

    final sanctuary = session.world.sanctuary;
    if (round) {
      // A single top-down plan stays legible at 85px. The full map can retain
      // the scene illustration without layering perspective art on this plan.
      c.save();
      c.clipPath(sanctuary.boundaryPath);
      for (final gate in settlement.gatePaths) {
        c.drawLine(
          gate.first,
          session.world.healAt,
          Paint()
            ..color = const Color(0xffc9b58a)
            ..strokeWidth = 100
            ..strokeCap = StrokeCap.round,
        );
      }
      for (final building in session.world.settlementCollision.take(4)) {
        c.drawPath(building.path, Paint()..color = const Color(0xff5d5c50));
        c.drawPath(
          building.path,
          Paint()
            ..color = const Color(0xffd2c5a2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14,
        );
      }
      c.drawOval(
        Rect.fromCenter(center: session.world.healAt, width: 180, height: 140),
        Paint()..color = const Color(0xff5396a3),
      );
      c.restore();
    }
    c.drawPath(
      sanctuary.boundaryPath,
      Paint()
        ..color = const Color(0xffc2b18a).withValues(alpha: round ? .8 : .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (round ? 18 : 30 * markerScale),
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
      if (!round)
        (project(session.mountMerchantAt), '탈것', Icons.pets_rounded, gold),
      ...(groupServices
          ? [(project(session.world.healAt), '거점', Icons.cottage_rounded, gold)]
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
            project(session.world.questGiverAt(giver.path)),
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
    final occupied = <Offset>[];
    for (final (anchor, label, icon, color) in services) {
      final radius = (round ? 5.0 : 10.0) * markerScale;
      if (round &&
          ((anchor - heroPoint).distance < 11 ||
              occupied.any((point) => (point - anchor).distance < 12))) {
        continue;
      }
      if (round &&
          (anchor - rect.center).distance > s.shortestSide / 2 - radius - 3) {
        continue;
      }
      var point = anchor;
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
            fontSize: (round ? 8 : 15) * markerScale,
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
          ..strokeWidth = 1.5
          ..color = const Color(0xffa58e67),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) => true;
}

class EffectIconPainter extends CustomPainter {
  EffectIconPainter(this.art, this.index, {this.framed = true});
  final GameArt art;
  final int index;
  final bool framed;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (!framed) canvas.clipPath(Path()..addOval(Offset.zero & size));
    _paint(canvas, size);
    canvas.restore();
  }

  void _paint(Canvas canvas, Size size) {
    if (index == 34 && ActionIllustrationPainter.draw(art, canvas, size)) {
      return;
    }
    if (SorceressIconArt.containsEffect(index)) {
      SorceressIconArt.draw(
        canvas,
        art.images[SorceressIconArt.imageKey],
        index - SorceressIconArt.firstEffect,
        Offset.zero & size,
        framed: framed,
      );
      return;
    }
    if (BarbarianIconArt.containsEffect(index)) {
      BarbarianIconArt.draw(
        canvas,
        art.images[BarbarianIconArt.imageKey],
        index - BarbarianIconArt.firstEffect,
        Offset.zero & size,
        framed: framed,
      );
      return;
    }
    if (index == 36) {
      MobileActionGlyphPainter(
        art,
        MobileGlyph.shadow,
        color: const Color(0xffbdcbdc),
      ).paint(canvas, size);
      return;
    }
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
      ).deflate(framed ? 1 : cell * .09),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant EffectIconPainter oldDelegate) =>
      oldDelegate.index != index ||
      oldDelegate.art != art ||
      oldDelegate.framed != framed;
}

abstract final class MobileGlyph {
  static const attack = 0,
      dodge = 1,
      bag = 2,
      skills = 3,
      map = 4,
      settings = 5,
      slash = 6,
      warcry = 7,
      fire = 8,
      ice = 9,
      lightning = 10,
      whirl = 11,
      shield = 12,
      sprint = 13,
      heavy = 14,
      fist = 15,
      motor = 16,
      blink = 17,
      shadow = 18;
}

class MobileActionGlyphPainter extends CustomPainter {
  const MobileActionGlyphPainter(
    this.art,
    this.index, {
    this.color = mobileText,
  });
  final GameArt art;
  final int index;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (ActionGlyphArt.draw(
      canvas,
      art.images['action-glyphs'],
      index,
      Offset.zero & size,
      tint: color == mobileText ? null : color,
    )) {
      return;
    }
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(math.min(size.width, size.height) / 36);
    canvas.translate(-16, -16);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final solid = Paint()..color = color;
    void path(List<Offset> points, {bool fill = false, bool closed = false}) {
      final p = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        p.lineTo(point.dx, point.dy);
      }
      if (closed) p.close();
      canvas.drawPath(p, fill ? solid : line);
    }

    void sword() {
      path(
        const [
          Offset(27, 3),
          Offset(29, 3),
          Offset(29, 8),
          Offset(14, 23),
          Offset(10, 19),
        ],
        fill: true,
        closed: true,
      );
      canvas.drawLine(const Offset(8, 18), const Offset(18, 28), line);
      canvas.drawLine(const Offset(11, 23), const Offset(5, 29), line);
    }

    switch (index) {
      case 0:
        sword();
      case 1:
        path(
          const [
            Offset(11, 3),
            Offset(21, 3),
            Offset(20, 17),
            Offset(28, 22),
            Offset(28, 29),
            Offset(7, 29),
            Offset(6, 23),
            Offset(10, 17),
          ],
          fill: true,
          closed: true,
        );
      case 2:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(6, 8, 20, 22),
            const Radius.circular(4),
          ),
          line,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(10, 18, 12, 8),
            const Radius.circular(2),
          ),
          line,
        );
        path(const [
          Offset(11, 8),
          Offset(11, 3),
          Offset(21, 3),
          Offset(21, 8),
        ]);
      case 3:
        path(const [
          Offset(7, 23),
          Offset(7, 16),
          Offset(25, 16),
          Offset(25, 23),
        ]);
        canvas.drawLine(const Offset(16, 16), const Offset(16, 7), line);
        for (final p in const [Offset(7, 26), Offset(16, 4), Offset(25, 26)]) {
          canvas.drawCircle(p, 3, solid);
        }
      case 4:
        path(const [
          Offset(3, 7),
          Offset(12, 3),
          Offset(21, 7),
          Offset(29, 3),
          Offset(29, 26),
          Offset(21, 30),
          Offset(12, 26),
          Offset(3, 30),
        ], closed: true);
        canvas.drawLine(const Offset(12, 3), const Offset(12, 26), line);
        canvas.drawLine(const Offset(21, 7), const Offset(21, 30), line);
      case 5:
        canvas.drawCircle(const Offset(16, 16), 9, line);
        canvas.drawCircle(const Offset(16, 16), 3.5, line);
        for (var i = 0; i < 8; i++) {
          final d = Offset(
            math.cos(i * math.pi / 4),
            math.sin(i * math.pi / 4),
          );
          canvas.drawLine(
            const Offset(16, 16) + d * 10,
            const Offset(16, 16) + d * 14,
            line,
          );
        }
      case 6:
        sword();
        canvas.save();
        canvas.translate(32, 0);
        canvas.scale(-1, 1);
        sword();
        canvas.restore();
      case 7:
        for (final r in [7.0, 12.0, 17.0]) {
          canvas.drawArc(
            Rect.fromCircle(center: const Offset(6, 16), radius: r),
            -.8,
            1.6,
            false,
            line,
          );
        }
        canvas.drawCircle(const Offset(6, 16), 2, solid);
      case 8:
        canvas.drawPath(
          Path()
            ..moveTo(16, 2)
            ..cubicTo(29, 15, 29, 26, 18, 30)
            ..cubicTo(4, 31, 2, 20, 8, 13)
            ..cubicTo(8, 20, 13, 21, 13, 17)
            ..cubicTo(18, 12, 18, 8, 16, 2)
            ..close(),
          solid,
        );
      case 9:
        for (var i = 0; i < 3; i++) {
          canvas.save();
          canvas.translate(16, 16);
          canvas.rotate(i * math.pi / 3);
          canvas.drawLine(const Offset(0, -13), const Offset(0, 13), line);
          for (final sign in [-1.0, 1.0]) {
            path([
              Offset(-4, sign * 7),
              Offset(0, sign * 10),
              Offset(4, sign * 7),
            ]);
          }
          canvas.restore();
        }
      case 10:
        path(
          const [
            Offset(18, 2),
            Offset(6, 18),
            Offset(15, 18),
            Offset(12, 30),
            Offset(28, 12),
            Offset(19, 12),
          ],
          fill: true,
          closed: true,
        );
      case 11:
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: const Offset(16, 16), radius: 11),
            i * math.pi * 2 / 3,
            1.65,
            false,
            line,
          );
          final a = i * math.pi * 2 / 3;
          canvas.drawLine(
            Offset(16 + 11 * math.cos(a), 16 + 11 * math.sin(a)),
            Offset(16 + 6 * math.cos(a - .4), 16 + 6 * math.sin(a - .4)),
            line,
          );
        }
      case 12:
        path(const [
          Offset(16, 3),
          Offset(28, 8),
          Offset(26, 21),
          Offset(16, 30),
          Offset(6, 21),
          Offset(4, 8),
        ], closed: true);
      case 13:
        path(const [Offset(4, 7), Offset(13, 16), Offset(4, 25)]);
        path(const [Offset(18, 7), Offset(27, 16), Offset(18, 25)]);
      case 14:
        canvas.save();
        canvas.translate(16, 16);
        canvas.rotate(-.55);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-11, -13, 22, 10),
            const Radius.circular(2),
          ),
          solid,
        );
        canvas.drawLine(
          const Offset(0, -3),
          const Offset(0, 14),
          line..strokeWidth = 4,
        );
        canvas.restore();
      case MobileGlyph.fist:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(8, 12, 17, 17),
            const Radius.circular(5),
          ),
          solid,
        );
        for (var i = 0; i < 4; i++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(7 + i * 4.8, 5, 4.3, 14),
              const Radius.circular(2),
            ),
            solid,
          );
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 15, 8, 10),
            const Radius.circular(3),
          ),
          solid,
        );
      case MobileGlyph.motor:
        path(
          const [
            Offset(3, 9),
            Offset(29, 9),
            Offset(29, 15),
            Offset(18, 15),
            Offset(14, 27),
            Offset(7, 27),
            Offset(11, 15),
            Offset(3, 15),
          ],
          fill: true,
          closed: true,
        );
        canvas.drawLine(const Offset(25, 8), const Offset(25, 5), line);
      case MobileGlyph.blink:
        path(const [
          Offset(22, 3),
          Offset(30, 16),
          Offset(22, 29),
          Offset(14, 16),
        ], closed: true);
        path(const [Offset(11, 7), Offset(5, 16), Offset(11, 25)]);
        canvas.drawLine(const Offset(1, 16), const Offset(10, 16), line);
      case MobileGlyph.shadow:
        for (final x in [10.0, 22.0]) {
          canvas.drawCircle(Offset(x, 8), 3, solid);
          path([
            Offset(x - 5, 25),
            Offset(x - 4, 15),
            Offset(x, 12),
            Offset(x + 4, 15),
            Offset(x + 5, 25),
          ], closed: true);
        }
        canvas.drawLine(const Offset(5, 29), const Offset(18, 17), line);
        canvas.drawLine(const Offset(20, 29), const Offset(29, 18), line);
      default:
        sword();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MobileActionGlyphPainter oldDelegate) =>
      oldDelegate.art != art ||
      oldDelegate.index != index ||
      oldDelegate.color != color;
}

class _BattleSurfacePainter extends CustomPainter {
  const _BattleSurfacePainter(
    this.accent, {
    this.pressed = false,
    this.primary = false,
  });
  final Color accent;
  final bool pressed, primary;
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero), radius = s.shortestSide / 2 - 2;
    final rim = primary ? 3.6 : 2.8;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    c.drawCircle(
      center + const Offset(0, 2),
      radius,
      Paint()..color = const Color(0x99000000),
    );
    c.drawCircle(center, radius, Paint()..color = const Color(0xff221b15));
    final metal = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xffc4a779),
        Color(0xff776048),
        Color(0xff352a20),
        Color(0xffa08760),
      ],
      stops: [0, .35, .70, 1],
    ).createShader(bounds);
    c.drawCircle(center, radius - 1, Paint()..shader = metal);
    metal.dispose();
    final face = RadialGradient(
      center: const Alignment(-.3, -.4),
      radius: 1.1,
      colors: pressed
          ? const [Color(0xff4a3930), Color(0xff161719)]
          : const [Color(0xff303032), Color(0xff101416)],
    ).createShader(bounds);
    c.drawCircle(center, radius - rim, Paint()..shader = face);
    face.dispose();
    c.drawCircle(
      center,
      radius - rim - .6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = const Color(0xff554b3a),
    );
    c.drawArc(
      bounds.deflate(1.6),
      -math.pi + .2,
      2.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = const Color(0xffd0b68c),
    );
    if (pressed) {
      c.drawCircle(
        center,
        radius - rim - 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent.withValues(alpha: .35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BattleSurfacePainter old) =>
      old.accent != accent || old.pressed != pressed || old.primary != primary;
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
    this.glyphIndex,
    this.primary = false,
    this.artwork,
    this.showLabel = true,
    this.enabled = true,
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
  final int? effect, glyphIndex;
  final bool primary;
  final Widget? artwork;
  final bool showLabel, insufficientResource, enabled;
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

  int get _glyph =>
      widget.glyphIndex ??
      switch (widget.effect) {
        0 => MobileGlyph.warcry,
        1 => MobileGlyph.whirl,
        2 => MobileGlyph.ice,
        3 => MobileGlyph.lightning,
        4 => MobileGlyph.fire,
        5 || 7 => MobileGlyph.slash,
        6 => MobileGlyph.shield,
        34 => MobileGlyph.sprint,
        35 => MobileGlyph.heavy,
        36 => MobileGlyph.shadow,
        _ => MobileGlyph.attack,
      };
  int? get _illustratedEffect =>
      widget.effect ??
      switch (widget.glyphIndex) {
        MobileGlyph.warcry => 0,
        MobileGlyph.whirl => 1,
        MobileGlyph.ice => 2,
        MobileGlyph.lightning => 3,
        MobileGlyph.fire => 4,
        MobileGlyph.slash => 7,
        MobileGlyph.shield => 6,
        MobileGlyph.sprint => 34,
        MobileGlyph.heavy => 35,
        MobileGlyph.shadow => 36,
        _ => null,
      };

  Widget get _symbol {
    final effect = _illustratedEffect;
    if (effect != null &&
        (effect == 36 ||
            (effect == 34 &&
                widget.art.images.containsKey(
                  ActionIllustrationPainter.imageKey,
                )) ||
            BarbarianIconArt.containsEffect(effect) ||
            SorceressIconArt.containsEffect(effect) ||
            widget.art.images.containsKey(
              SorceressIconArt.containsEffect(effect)
                  ? SorceressIconArt.imageKey
                  : BarbarianIconArt.containsEffect(effect)
                  ? BarbarianIconArt.imageKey
                  : effect >= 34
                  ? 'physical-icons'
                  : effect >= 14
                  ? 'skill-perks'
                  : effect >= 8
                  ? 'passive-icons'
                  : 'combat-fx',
            ))) {
      return CustomPaint(
        size: Size.square(widget.size * .86),
        painter: EffectIconPainter(widget.art, effect, framed: false),
      );
    }
    if (widget.glyphIndex == MobileGlyph.dodge) {
      return CustomPaint(
        size: Size.square(widget.size * .86),
        painter: DodgeActionPainter(widget.art),
      );
    }
    if (widget.glyphIndex == null &&
        widget.effect == null &&
        widget.icon != null) {
      return Icon(widget.icon, size: widget.size * .5, color: _accent);
    }
    return CustomPaint(
      size: Size.square(widget.size * .5),
      painter: MobileActionGlyphPainter(widget.art, _glyph, color: _accent),
    );
  }

  Color get _accent => switch (_glyph) {
    8 => const Color(0xffe6ad80),
    9 => const Color(0xffa3d9ed),
    10 => const Color(0xffc0b7e8),
    6 => const Color(0xffe1ad9e),
    _ => mobileText,
  };

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.enabled,
    label: widget.semanticLabel,
    hint: widget.semanticHint,
    onTap: widget.enabled ? widget.onTap : null,
    excludeSemantics: true,
    child: Listener(
      onPointerDown: (event) {
        if (pointer != null || !widget.enabled) return;
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
                      scale: pressed ? .96 : 1,
                      duration: const Duration(milliseconds: 70),
                      child: CustomPaint(
                        size: Size.square(widget.size),
                        painter: _BattleSurfacePainter(
                          _accent,
                          pressed: pressed,
                          primary: widget.primary,
                        ),
                      ),
                    ),
                    if (widget.artwork != null)
                      widget.artwork!
                    else
                      Opacity(
                        opacity: widget.remaining > 0
                            ? .38
                            : widget.enabled
                            ? 1
                            : .35,
                        child: _symbol,
                      ),
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
                    if (!widget.enabled && widget.remaining <= 0)
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0x66000204)),
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
                        '${CombatBalance.realSeconds(widget.remaining).ceil()}',
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
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = mobileAccent,
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

/// A moving figure keeps evasion distinct from a boot or a skill plaque.
class DodgeActionPainter extends CustomPainter {
  DodgeActionPainter(this.art);
  final GameArt art;
  static final _paint = Paint()..filterQuality = FilterQuality.medium;
  @override
  void paint(Canvas canvas, Size size) {
    final image = art.images['dodge-icon'];
    if (image == null) return;
    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & size));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      _paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DodgeActionPainter old) => old.art != art;
}

class IllustratedMenuPainter extends CustomPainter {
  const IllustratedMenuPainter(this.art, this.sprite);
  final GameArt art;
  final String sprite;
  @override
  void paint(Canvas canvas, Size size) {
    const _BattleSurfacePainter(Color(0xffcbb591)).paint(canvas, size);
    final destination = (Offset.zero & size).deflate(size.shortestSide * .19);
    if (art.images['controls'] case final image?) {
      final cell = art.controls[sprite] as List;
      final source = Rect.fromLTWH(
        (cell[0] as num).toDouble(),
        (cell[1] as num).toDouble(),
        (cell[2] as num).toDouble(),
        (cell[3] as num).toDouble(),
      );
      // Retain the painted equipment/map icon, with its old square frame
      // cropped away so the new round bronze bezel remains the only border.
      canvas.save();
      canvas.clipPath(Path()..addOval(destination));
      canvas.drawImageRect(
        image,
        source.deflate(source.shortestSide * .19),
        destination,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
      return;
    }
    canvas.save();
    canvas.translate(destination.left, destination.top);
    MobileActionGlyphPainter(art, switch (sprite) {
      'touchInventory' => MobileGlyph.bag,
      'touchQuests' => MobileGlyph.skills,
      'touchCompendium' => MobileGlyph.map,
      'touchSettings' => MobileGlyph.settings,
      _ => MobileGlyph.map,
    }, color: const Color(0xffcbb591)).paint(canvas, destination.size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant IllustratedMenuPainter oldDelegate) =>
      oldDelegate.art != art || oldDelegate.sprite != sprite;
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
        borderRadius: BorderRadius.circular(29),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: IllustratedMenuPainter(art, sprite),
                ),
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
                      color: const Color(0xffc85d57),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xff20323a)),
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

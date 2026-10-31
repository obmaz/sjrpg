import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'action_glyph_art.dart';
import 'adventure.dart';
import 'affliction_widgets.dart';
import 'barbarian_icon_art.dart';
import 'cinematic_icon_art.dart';
import 'combat_balance.dart';
import 'd1_icon_art.dart';
import 'dungeon.dart';
import 'game_art.dart';
import 'health_widgets.dart';
import 'map_marker_layout.dart';
import 'player_health_feedback.dart';
import 'resource_meter.dart';
import 'sorceress_icon_art.dart';
import 'world_model.dart';

const gold = Color(0xffd5b772),
    ink = Color(0xff1d1713),
    cream = Color(0xfff0e5c8);
const mobileSurface = Color(0xd91b1715),
    mobileRaisedSurface = Color(0xee33271f),
    mobileBorder = Color(0x558e7859),
    mobileAccent = Color(0xffe5bd70),
    mobileText = Color(0xffe8f0f2);
const gameMetal = Color(0xffb3a079),
    gameMetalDark = Color(0xff5b5645),
    gameTeal = Color(0xff292019);
String gameTime(double seconds) =>
    '${seconds ~/ 60}:${(seconds.toInt() % 60).toString().padLeft(2, '0')}';

double battlePortraitDiameter(Size viewport) =>
    viewport.width > viewport.height && viewport.width >= 500
    ? 92 * (viewport.height / 720).clamp(.65, 1.0)
    : 60;

double battleMapDiameter(Size viewport) => viewport.width < 360
    ? 76
    : viewport.width > viewport.height && viewport.width >= 500
    ? 150 * (viewport.height / 720).clamp(.65, 1.0)
    : 86;

class GameHud extends StatelessWidget {
  const GameHud(this.session, {this.onMap, super.key});
  final Adventure session;
  final VoidCallback? onMap;
  @override
  Widget build(BuildContext context) {
    if (PlayerHealthFeedbackScope.maybeOf(context) == null) {
      return PlayerHealthFeedbackScope(
        session: session,
        child: GameHud(session, onMap: onMap),
      );
    }
    final p = session.progress;
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final landscape = width > media.size.height && width >= 500;
    final short = media.size.height < 520 || landscape;
    final portraitSide = battlePortraitDiameter(media.size);
    final meterLeft = 10 + portraitSide * .55;
    // Labels start beyond the portrait's complete metal rim. Only the fluid
    // and its frame continue underneath the circular join.
    final labelInset = 10 + portraitSide + 8 - meterLeft;
    final mapSide = battleMapDiameter(media.size);
    final statusWidth = math.min(
      landscape ? 360 * (media.size.height / 720).clamp(.65, 1.0) : 306.0,
      width - mapSide - (landscape ? 61 + 112 + 8 : 22),
    );
    final resourceHeight = math.max(
      18.0,
      ResourceMeter.minimumHeight(media.textScaler),
    );
    const portraitTop = 10.0,
        healthTop = 10.0,
        healthHeight = 18.0,
        slant = 16.0;
    final resourceTop = healthTop + healthHeight + 1;
    final ribbonTop = healthTop - 3;
    final ribbonBottom = resourceTop + resourceHeight + 15;
    Widget joinPortrait(Widget child, double top) => ClipPath(
      clipper: PortraitGaugeClipper(
        Offset(
          10 + portraitSide / 2 - meterLeft,
          portraitTop + portraitSide / 2 - top,
        ),
        portraitSide / 2 + 5,
        ribbonOffset: top - ribbonTop,
        ribbonHeight: ribbonBottom - ribbonTop,
        slant: slant,
      ),
      child: child,
    );
    return SizedBox(
      height: math.max(130, mapSide + 14),
      child: Stack(
        children: [
          Positioned(
            key: const ValueKey('hud-status-chrome'),
            left: 5,
            top: 4,
            width: statusWidth,
            height: math.max(
              math.max(84, portraitSide + 24),
              resourceTop + resourceHeight + 19,
            ),
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HeroStatusChrome(
                  portraitSide + 8,
                  plateTop: ribbonTop - 4,
                  plateBottom: ribbonBottom - 4,
                  portraitTop: portraitTop,
                  slant: slant,
                ),
              ),
            ),
          ),
          Positioned(
            top: healthTop,
            left: meterLeft,
            width: math.max(50, statusWidth - meterLeft - 7),
            child: joinPortrait(
              HealthMeter(
                session,
                height: healthHeight,
                leadingInset: labelInset,
                flatEnd: true,
              ),
              healthTop,
            ),
          ),
          Positioned(
            left: meterLeft,
            top: resourceTop,
            width: math.max(48, statusWidth - meterLeft - 7),
            child: joinPortrait(
              ResourceMeter(
                session,
                height: resourceHeight,
                leadingInset: labelInset,
              ),
              resourceTop,
            ),
          ),
          Positioned(
            left: meterLeft,
            top: resourceTop + resourceHeight + 4,
            width: math.max(48, statusWidth - meterLeft - 7),
            height: 8,
            child: joinPortrait(
              Semantics(
                label: '경험치',
                value: '${p.xp} / ${p.nextLevelXp}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LinearProgressIndicator(
                      key: const ValueKey('hud-experience'),
                      value: (p.xp / p.nextLevelXp).clamp(0.0, 1.0),
                      minHeight: 8,
                      color: gold,
                      backgroundColor: const Color(0xff514537),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: labelInset, right: 8),
                      child: Center(
                        child: Text(
                          'EXP ${(p.xp / p.nextLevelXp * 100).floor()}%',
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontSize: 7,
                            height: 1,
                            color: cream,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              resourceTop + resourceHeight + 4,
            ),
          ),
          Positioned(
            left: 10,
            top: portraitTop,
            child: SizedBox(
              key: const ValueKey('hud-portrait'),
              width: portraitSide,
              height: portraitSide,
              child: ClipOval(
                child: CustomPaint(
                  painter: _PortraitPainter(
                    session.art,
                    p.heroClass,
                    PlayerHealthFeedbackScope.maybeOf(context),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: landscape ? 10 : 116,
            top: landscape
                ? math.max(
                    portraitTop + portraitSide + 8,
                    resourceTop + resourceHeight + 16,
                  )
                : math.max(73, resourceTop + resourceHeight + 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.max(60, statusWidth - 76),
              ),
              child: AfflictionIcons(session.afflictions, session: session),
            ),
          ),
          Positioned(
            right: landscape ? 61 : 9,
            top: 7,
            child: SizedBox(
              width: mapSide,
              height: mapSide,
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
                  color: const Color(0xbf191b1a),
                  border: Border.all(color: const Color(0x665b5645)),
                  borderRadius: BorderRadius.circular(5),
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

/// One circular cutout joins each live bar to the same portrait rim.
class PortraitGaugeClipper extends CustomClipper<Path> {
  const PortraitGaugeClipper(
    this.center,
    this.radius, {
    this.ribbonOffset = 0,
    this.ribbonHeight,
    this.slant = 0,
  });
  final Offset center;
  final double radius;
  final double ribbonOffset, slant;
  final double? ribbonHeight;
  double rightAt(Size size, double y) => ribbonHeight == null
      ? size.width
      : size.width - slant * (ribbonOffset + y) / ribbonHeight!;
  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()
      ..moveTo(0, 0)
      ..lineTo(rightAt(size, 0), 0)
      ..lineTo(rightAt(size, size.height), size.height)
      ..lineTo(0, size.height)
      ..close(),
    Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
  );
  @override
  bool shouldReclip(covariant PortraitGaugeClipper old) =>
      old.center != center ||
      old.radius != radius ||
      old.ribbonOffset != ribbonOffset ||
      old.ribbonHeight != ribbonHeight ||
      old.slant != slant;
}

/// The portrait and two vessels share one fitted dark-metal silhouette.
/// The live meters retain their own damage trail, danger pulse and fluid clock.
class _HeroStatusChrome extends CustomPainter {
  const _HeroStatusChrome(
    this.portraitSide, {
    required this.plateBottom,
    required this.plateTop,
    required this.portraitTop,
    required this.slant,
  });
  final double portraitSide;
  final double plateBottom;
  final double plateTop, portraitTop, slant;
  @override
  void paint(Canvas canvas, Size size) {
    final plate = Path()
      ..moveTo(portraitSide * .70, plateTop)
      ..lineTo(size.width - 9, plateTop)
      ..lineTo(size.width - 9 - slant, plateBottom)
      ..lineTo(portraitSide * .70, plateBottom)
      ..close();
    final ringTop = portraitTop - 8;
    final portrait = Rect.fromLTWH(1, ringTop, portraitSide, portraitSide);
    final joinedPlate = Path.combine(
      PathOperation.difference,
      plate,
      Path()..addOval(portrait.inflate(1)),
    );
    canvas.drawPath(
      joinedPlate.shift(const Offset(0, 2)),
      Paint()..color = const Color(0xaa000000),
    );
    canvas.drawPath(joinedPlate, Paint()..color = const Color(0xe51c1b1c));
    canvas.drawPath(
      joinedPlate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xff6e6355),
    );
    canvas.drawOval(
      portrait.shift(const Offset(0, 2)),
      Paint()..color = const Color(0xaa000000),
    );
    canvas.drawOval(portrait, Paint()..color = const Color(0xff171d20));
    canvas.drawOval(
      portrait,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xff4a4337),
    );
    canvas.drawArc(
      portrait,
      -math.pi + .2,
      2.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xffc3ac82),
    );
    canvas.drawOval(
      portrait.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = const Color(0xff9c8761),
    );
    // Small crest and rivets distinguish the portrait from an ordinary button.
    for (final y in [ringTop - 1, ringTop + portraitSide]) {
      final crest = Path()
        ..moveTo(portraitSide / 2 - 1, y - 3)
        ..lineTo(portraitSide / 2 + 4, y + 1)
        ..lineTo(portraitSide / 2 - 1, y + 6)
        ..lineTo(portraitSide / 2 - 6, y + 1)
        ..close();
      canvas.drawPath(crest, Paint()..color = const Color(0xff292b2b));
      canvas.drawPath(
        crest,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xffa38e68),
      );
    }
    for (final x in [5.0, portraitSide - 7]) {
      canvas.drawCircle(
        Offset(x, ringTop + portraitSide / 2 - 1),
        1.4,
        Paint()..color = const Color(0xffad9770),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeroStatusChrome old) =>
      old.portraitSide != portraitSide ||
      old.plateBottom != plateBottom ||
      old.plateTop != plateTop ||
      old.portraitTop != portraitTop ||
      old.slant != slant;
}

/// Shared generated medallions use the same circular face as learned skills.
class ActionIllustrationPainter extends CustomPainter {
  ActionIllustrationPainter(this.art, {this.fist = false});
  static const imageKey = 'combat-actions';
  final GameArt art;
  final bool fist;
  static bool draw(GameArt art, Canvas canvas, Size size, {bool fist = false}) {
    if (D1IconArt.draw(canvas, art, fist ? 6 : 5, Offset.zero & size)) {
      return true;
    }
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
  _PortraitPainter(this.art, this.heroClass, this.feedback)
    : super(repaint: feedback);
  final PlayerHealthFeedback? feedback;
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
    final tint = feedback?.warningTintOpacity ?? 0;
    if (tint > 0) {
      c.drawOval(
        Offset.zero & s,
        Paint()..color = Color.fromRGBO(255, 42, 36, tint),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter oldDelegate) =>
      oldDelegate.heroClass != heroClass ||
      oldDelegate.art != art ||
      oldDelegate.feedback != feedback;
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
        ..color = thumb ? const Color(0xdd493928) : const Color(0x7756402b),
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
        ..color = const Color(0x776b5a43),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - .8),
      -math.pi + .25,
      2.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = const Color(0x99c4a67a),
    );
    if (!thumb) {
      final mark = Paint()..color = const Color(0xbcb9a079);
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
          ..color = const Color(0x66c1a376),
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

/// Shared by quest markers and their map selector legend; completion keeps hue.
Color mapQuestColor(int index) => const [
  Color(0xffffcf70),
  Color(0xff63e6dd),
  Color(0xffc7a0ff),
  Color(0xffa7df70),
  Color(0xff72b7ff),
  Color(0xffffa5ca),
  Color(0xffe9a46a),
  Color(0xff93ccbd),
][index % 8];

class MapPainter extends CustomPainter {
  MapPainter(this.session, {this.round = true, this.markerScale = 1});
  final Adventure session;
  final bool round;
  final double markerScale;
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
        : session.dungeon?.layout.bounds ?? (Offset.zero & worldSize);
    c.scale(s.width / view.width, s.height / view.height);
    c.translate(-view.left, -view.top);
    c.clipRect(Offset.zero & worldSize);
    if (session.dungeon != null) {
      c.drawRect(view, Paint()..color = const Color(0xff182027));
      c.drawPath(
        session.dungeon!.layout.floor,
        Paint()..color = const Color(0xff7a837d),
      );
      c.drawCircle(session.dungeon!.layout.goal, 55, Paint()..color = gold);
    } else {
      session.terrain.mapPlan.paint(
        c,
        view,
        unitsPerPixel: view.width / s.width * (round ? 1 : markerScale),
      );
    }
    final sanctuary = session.world.sanctuary;
    c.drawPath(
      sanctuary.boundaryPath,
      Paint()
        ..color = const Color(0xffc2b18a).withValues(alpha: round ? .8 : .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (round ? 18 : 30 * markerScale),
    );
    c.restore();
    Offset project(Offset at) => Offset(
      (at.dx - view.left) / view.width * s.width,
      (at.dy - view.top) / view.height * s.height,
    );
    c.clipRect(rect.deflate(round ? 3 : markerScale));
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
      final scaleEnd = scaleStart + Offset(s.width * 1000 / view.width, 0);
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
    if (!round && markerScale <= 2.0) {
      for (final landmark in session.world.landmarks) {
        final labelAt =
            project(landmark.footprint.bottomCenter) +
            Offset(0, 12 * markerScale);
        if (session.world.sites.any(
          (site) => (project(site.at) - labelAt).distance < 85 * markerScale,
        )) {
          continue;
        }
        session.art.text(
          c,
          landmark.name,
          labelAt,
          size: 10 * markerScale,
          color: const Color(0xffc7bea5),
        );
      }
    }
    final heroPoint = project(session.hero.body.center);
    final unit = round ? 1.0 : markerScale;
    final markers = <MapMarker>[];
    final visuals =
        <
          String,
          ({
            String kind,
            Color color,
            String label,
            IconData? icon,
            bool tracked,
            bool outside,
            Offset anchor,
          })
        >{};
    void add(
      String id,
      Offset anchor,
      String kind,
      Color color,
      double radius, {
      String label = '',
      IconData? icon,
      bool tracked = false,
      bool outside = false,
    }) {
      markers.add(MapMarker(id, anchor, radius * unit));
      visuals[id] = (
        kind: kind,
        color: color,
        label: label,
        icon: icon,
        tracked: tracked,
        outside: outside,
        anchor: anchor,
      );
    }

    bool inside(Offset point) =>
        !round || (point - rect.center).distance < s.shortestSide / 2 - 4;
    final services = session.dungeon != null
        ? <(Offset, String, IconData, Color)>[]
        : [
            (session.mountMerchantAt, '탈것', Icons.pets_rounded, gold),
            (session.world.merchantAt, '상점', Icons.storefront_rounded, gold),
            (
              session.world.healAt,
              '회복',
              Icons.water_drop_rounded,
              const Color(0xff8ce6bd),
            ),
            if (session.world.stage == WorldStage.forest)
              (session.world.blacksmithAt, '대장간', Icons.hardware_rounded, gold),
            if (session.world.stage == WorldStage.sands)
              for (final giver in timeQuestGivers)
                (
                  session.world.questGiverAt(giver.path),
                  giver.name,
                  giver.path == TimePath.past
                      ? Icons.auto_stories_rounded
                      : Icons.cell_tower_rounded,
                  session.timePath != null && session.timePath != giver.path
                      ? const Color(0xff8faaa3)
                      : gold,
                ),
          ];
    if (session.dungeon == null) {
      final at = project(session.world.caveEntrance);
      if (inside(at)) {
        add(
          'cave',
          at,
          'service',
          CaveDefinition.forStage(session.world.stage).color,
          round ? 7 : 11,
          label: CaveDefinition.forStage(session.world.stage).name,
          icon: Icons.terrain,
        );
      }
    }
    for (final (at, label, icon, color) in services) {
      final anchor = project(at);
      if (!inside(anchor)) continue;
      add(
        'service:$label',
        anchor,
        'service',
        color,
        round ? 6 : 11,
        label: label,
        icon: icon,
      );
    }
    for (final (siteIndex, site) in session.visibleSites.indexed) {
      final anchor = project(site.at),
          tracked = site.id == session.trackedSite?.id;
      final done = session.cleansedSites.contains(site.id),
          outside = !inside(anchor);
      if (round && outside && done) continue;
      add(
        'site:${site.id}',
        anchor,
        'site',
        mapQuestColor(siteIndex),
        round ? (tracked ? 8 : 6) : (tracked ? 13 : 10),
        label: '${site.name}${done ? ' ✓' : ''}',
        tracked: tracked,
        outside: outside,
      );
    }
    if (round) {
      for (var i = 0; i < session.stageChestLocations.length; i++) {
        if (session.openedChests.contains(i)) continue;
        final anchor = project(session.stageChestLocations[i]);
        if (inside(anchor)) add('chest:$i', anchor, 'chest', gold, 2.5);
      }
      var index = 0;
      for (final mob in session.mobs) {
        if (!mob.combatReady || mob.isDead || mob.isRemoving || mob.boss) {
          continue;
        }
        final anchor = project(mob.body.center);
        if (inside(anchor)) {
          add(
            'enemy:${index++}',
            anchor,
            'enemy',
            mob.isElite ? mob.tierColor : const Color(0xffe94430),
            3,
          );
        }
      }
    }
    for (final area in session.exhaustedAreas) {
      final anchor = project(area.stone);
      if (inside(anchor)) {
        add(
          'memory:${area.stone}',
          anchor,
          'memory',
          const Color(0xffa9d6d0),
          round ? 4 : 6,
        );
      }
    }
    for (final boss in session.mobs.where(
      (m) => m.boss && m.combatReady && !m.isDead && !m.isRemoving,
    )) {
      add(
        'boss',
        project(boss.body.center),
        'boss',
        const Color(0xffef6455),
        round ? 7 : 11,
        label: session.world.stage.bossName,
      );
    }
    final groups = MapMarkerLayout(
      rect,
      round: round,
      unit: unit,
    ).layout(markers, hero: heroPoint);
    for (final group in groups) {
      final selected = group.items.any((m) => visuals[m.id]!.tracked);
      final visual = visuals[group.items.first.id]!;
      final point = group.center;
      if (group.items.length > 1) {
        final color = selected ? gold : visual.color;
        c.drawCircle(point, group.radius, Paint()..color = ink);
        c.drawCircle(
          point,
          group.radius - .5 * unit,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = unit
            ..color = color,
        );
        if (selected) {
          c.drawCircle(
            point,
            group.radius + unit,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = unit
              ..color = gold,
          );
        }
        session.art.text(
          c,
          group.items.length > 99 ? '99+' : '${group.items.length}',
          point,
          size: (round ? 9 : 13) * unit,
          color: cream,
          centered: true,
        );
        continue;
      }
      final r = group.radius;
      switch (visual.kind) {
        case 'service':
          c.drawCircle(point, r - unit, Paint()..color = ink);
          c.drawCircle(
            point,
            r - unit,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = unit
              ..color = visual.color,
          );
          final icon = visual.icon!;
          final glyph = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                fontFamily: icon.fontFamily,
                fontSize: (round ? 8 : 15) * unit,
                color: visual.color,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          glyph.paint(c, point - Offset(glyph.width / 2, glyph.height / 2));
          glyph.dispose();
        case 'site':
          c.drawCircle(point, r, Paint()..color = ink);
          if (selected) {
            c.drawCircle(
              point,
              r - unit,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = unit
                ..color = gold,
            );
          }
          if (round && visual.outside && selected) {
            c.save();
            c.translate(point.dx, point.dy);
            final direction = visual.anchor - rect.center;
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
          } else {
            c.drawCircle(point, r * .64, Paint()..color = visual.color);
            c.drawCircle(
              point,
              r * .30,
              Paint()..color = const Color(0xff164d55),
            );
          }
        case 'boss':
          c.drawCircle(point, r, Paint()..color = ink);
          c.drawPath(
            Path()
              ..moveTo(point.dx, point.dy - r + unit)
              ..lineTo(point.dx + r - unit, point.dy)
              ..lineTo(point.dx, point.dy + r - unit)
              ..lineTo(point.dx - r + unit, point.dy)
              ..close(),
            Paint()..color = visual.color,
          );
        case 'memory':
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: point, width: r * 1.3, height: r * 1.8),
              Radius.circular(unit),
            ),
            Paint()..color = visual.color,
          );
        default:
          c.drawCircle(point, r, Paint()..color = ink);
          c.drawCircle(point, r - .7 * unit, Paint()..color = visual.color);
      }
      if (!round &&
          markerScale <= 2.5 &&
          visual.label.isNotEmpty &&
          point.dx > 70 * unit &&
          point.dx < rect.right - 70 * unit &&
          point.dy > 32 * unit) {
        session.art.text(
          c,
          visual.label,
          point - Offset(0, r + 12 * unit),
          size: 12 * unit,
          color: visual.color,
        );
      }
    }
    final hero = Offset(
      (session.hero.body.center.dx - view.left) / view.width * s.width,
      (session.hero.body.center.dy - view.top) / view.height * s.height,
    );
    if (round) {
      c.save();
      c.translate(hero.dx, hero.dy);
      c.rotate(session.hero.bearing);
      final pointer = Path()
        ..moveTo(5, 0)
        ..lineTo(-3.5, -3.5)
        ..lineTo(-1.8, 0)
        ..lineTo(-3.5, 3.5)
        ..close();
      c.drawPath(pointer, Paint()..color = const Color(0xfff3e8ce));
      c.drawPath(
        pointer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = const Color(0xff43362a),
      );
      c.restore();
    } else {
      c.drawCircle(hero, 13 * unit, Paint()..color = const Color(0xcc09252d));
      c.drawCircle(
        hero,
        10 * unit,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * unit
          ..color = const Color(0xff63f6ed),
      );
      c.drawCircle(hero, 6 * unit, Paint()..color = const Color(0xff63f6ed));
      c.drawCircle(
        hero,
        6 * unit,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * unit
          ..color = Colors.white,
      );
      c.save();
      c.translate(hero.dx, hero.dy);
      c.rotate(session.hero.bearing);
      c.drawPath(
        Path()
          ..moveTo(17 * unit, 0)
          ..lineTo(9 * unit, -4 * unit)
          ..lineTo(9 * unit, 4 * unit)
          ..close(),
        Paint()..color = Colors.white,
      );
      c.restore();
      final labelAt = hero - Offset(0, 28 * unit);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: labelAt, width: 52 * unit, height: 20 * unit),
          Radius.circular(6 * unit),
        ),
        Paint()..color = const Color(0xee09252d),
      );
      session.art.text(
        c,
        '내 위치',
        labelAt,
        size: 11 * unit,
        color: Colors.white,
        centered: true,
      );
    }
    c.restore();
    if (round) {
      c.drawOval(
        rect.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xff3b3025),
      );
      c.drawOval(
        rect.deflate(3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xffa18b68),
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
    final cinematic = switch (index) {
      34 => 6,
      35 => 2,
      100 || 108 => 11,
      120 || 126 || 129 => 2,
      127 => 0,
      128 => 3,
      _ => null,
    };
    if (cinematic != null &&
        CinematicIconArt.draw(canvas, art, cinematic, Offset.zero & size)) {
      return;
    }
    final d1 = D1IconArt.effectIndex(index);
    if (d1 != null && D1IconArt.draw(canvas, art, d1, Offset.zero & size)) {
      return;
    }
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
    final cinematic = switch (index) {
      MobileGlyph.attack => 0,
      MobileGlyph.dodge => 7,
      MobileGlyph.bag => 4,
      MobileGlyph.skills => 9,
      MobileGlyph.map => 10,
      MobileGlyph.settings => 8,
      MobileGlyph.sprint => 6,
      MobileGlyph.fire => 1,
      MobileGlyph.whirl => 3,
      MobileGlyph.heavy => 2,
      MobileGlyph.warcry => 11,
      _ => null,
    };
    if (cinematic != null &&
        CinematicIconArt.draw(canvas, art, cinematic, Offset.zero & size)) {
      return;
    }
    final d1 = switch (index) {
      MobileGlyph.attack => 7,
      MobileGlyph.dodge => 4,
      MobileGlyph.bag => 0,
      MobileGlyph.skills => 1,
      MobileGlyph.map => 2,
      MobileGlyph.settings => 3,
      MobileGlyph.sprint => 5,
      MobileGlyph.fist => 6,
      MobileGlyph.motor => 15,
      MobileGlyph.shadow => 11,
      MobileGlyph.heavy => 9,
      _ => null,
    };
    if (d1 != null && D1IconArt.draw(canvas, art, d1, Offset.zero & size)) {
      return;
    }
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
        (D1IconArt.hasEffect(widget.art, effect) ||
            effect == 36 ||
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
        size: Size.square(
          D1IconArt.hasEffect(widget.art, effect)
              ? widget.size
              : widget.size * .86,
        ),
        painter: EffectIconPainter(widget.art, effect, framed: false),
      );
    }
    if (widget.glyphIndex == MobileGlyph.dodge) {
      return CustomPaint(
        size: Size.square(
          widget.art.images.containsKey(D1IconArt.interfaceKey)
              ? widget.size
              : widget.size * .86,
        ),
        painter: DodgeActionPainter(widget.art),
      );
    }
    if (widget.glyphIndex == null &&
        widget.effect == null &&
        widget.icon != null) {
      return Icon(widget.icon, size: widget.size * .5, color: _accent);
    }
    return CustomPaint(
      size: Size.square(
        widget.art.images.containsKey(CinematicIconArt.imageKey)
            ? widget.size
            : widget.size * .5,
      ),
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
  Widget build(BuildContext context) {
    final control = Semantics(
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
                                          border: Border.all(
                                            color: Colors.white,
                                          ),
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
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 5),
                            ],
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
    return widget.showLabel ? control : ClipOval(child: control);
  }
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
    if (CinematicIconArt.draw(canvas, art, 7, Offset.zero & size)) return;
    if (D1IconArt.draw(canvas, art, 4, Offset.zero & size)) return;
    final image = art.images['dodge-icon'];
    if (image == null) return;
    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & size));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      ).deflate(image.width * .07),
      Offset.zero & size,
      _paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DodgeActionPainter old) => old.art != art;
}

/// Framed illustrations packed from their measured source bounds.
class ReferenceBattleButtonPainter extends CustomPainter {
  const ReferenceBattleButtonPainter(this.art, this.index);
  final GameArt art;
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    if (!art.effects.draw(
      canvas,
      'reference-battle-buttons',
      index,
      Offset.zero & size,
      columns: 4,
      rows: 1,
      inset: 0,
    )) {
      CinematicIconArt.draw(canvas, art, 0, Offset.zero & size);
    }
  }

  @override
  bool shouldRepaint(covariant ReferenceBattleButtonPainter old) =>
      old.art != art || old.index != index;
}

class IllustratedMenuPainter extends CustomPainter {
  const IllustratedMenuPainter(this.art, this.sprite);
  final GameArt art;
  final String sprite;
  @override
  void paint(Canvas canvas, Size size) {
    final d1 = switch (sprite) {
      'touchInventory' => 0,
      'touchCodex' || 'touchQuests' => 1,
      'touchJournal' || 'touchCompendium' => 2,
      'touchSettings' => 3,
      _ => null,
    };
    final reference = switch (d1) {
      0 => 2,
      2 => 3,
      3 => 1,
      _ => null,
    };
    if (reference != null &&
        art.effects.draw(
          canvas,
          'reference-battle-buttons',
          reference,
          Offset.zero & size,
          columns: 4,
          rows: 1,
          inset: 0,
        )) {
      return;
    }
    final cinematic = switch (d1) {
      0 => 4,
      1 => 9,
      2 => 10,
      3 => 8,
      _ => null,
    };
    if (cinematic != null &&
        CinematicIconArt.draw(canvas, art, cinematic, Offset.zero & size)) {
      return;
    }
    if (d1 != null &&
        art.effects.draw(
          canvas,
          'reference-menus',
          d1,
          Offset.zero & size,
          columns: 4,
          rows: 1,
          inset: 2,
        )) {
      return;
    }
    if (d1 != null && D1IconArt.draw(canvas, art, d1, Offset.zero & size)) {
      return;
    }
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
    this.compact = false,
    this.side = false,
    super.key,
  });
  final int badge;
  final bool compact, side;
  final GameArt art;
  final String sprite, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 7),
    child: Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 22 : 29),
        child: SizedBox(
          width: compact ? 44 : 58,
          height: compact ? 44 : 58,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (side)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xe5221c16),
                      border: Border.all(color: const Color(0xff71614a)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(side ? 3 : 0),
                  child: CustomPaint(
                    painter: IllustratedMenuPainter(art, sprite),
                  ),
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: -4,
                  top: -5,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: compact ? 18 : 23,
                      minHeight: compact ? 18 : 23,
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
